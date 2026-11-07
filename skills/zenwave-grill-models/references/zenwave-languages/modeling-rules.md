# From a flow to ZDL models: the modeling rules

How the elements of a ZFL flow become ZDL: one model per bounded context, commands, events, synchronous calls,
responses, lifecycles, transport annotations and identifiers. They hold for a new project and for a new flow on top of
an existing one. The deployment shape (microservices or modulith) is in the project overlay and changes the transport
annotations: use one shape only, never mix them.

Examples use the Arcadia Editions names and the organization prefix `com.arcadiaeditions`: replace it with the
project's own reverse-domain prefix (`<org>`). The grammar (`grammar/Zdl.g4`) is the source of truth for syntax, the
lint is its judge ([lint.md](lint.md)), and [asyncapi-naming-conventions.md](asyncapi-naming-conventions.md) is the
source of truth for ids, channels and topics. The examples in `examples/<shape>/` are for structure and idiom, never
to override the grammar or the naming rules.

## Output path resolution

Use the first matching rule:

1. If the system has `@zdl("path/to/domain-model.zdl")`, use that exact path relative to the current working directory where the command is being run.
2. Else if `zenwave-architecture.yml` maps the service repository and ZDL spec path, use that.
3. Else default to `{kebab-case-system-name}/domain-model.zdl` relative to the current path where the command is being run.

Treat the current working directory as the root for `@zdl(...)` resolution. For example,
if the agent is invoked from the repository root, `@zdl("customer-api/model.zdl")`
must write to `./customer-api/model.zdl` under that root.

Do not overwrite an existing file blindly. If a target already exists, read it first and preserve valid existing structure unless the user explicitly asked for replacement.

## API reference URL resolution

When generating entries for an `apis` block, resolve the AsyncAPI contract URL
in this order:

1. Apicurio Registry URL, when a registry base URL, group, artifact, and version
   can be inferred from `zenwave-architecture.yml`, environment-specific docs,
   or user input.
2. HTTP(S) URL, when the service publishes its AsyncAPI contract at a stable
   endpoint or documentation URL.
3. Local file path, only as a last resort when no registry or HTTP URL is known.

Use the newer one-line syntax for each API entry:

```zdl
apis {
    asyncapi client OrdersCheckoutApi "https://registry.example.com/apis/registry/v3/groups/orders.checkout/artifacts/orders-checkout-asyncapi/versions/1.0.0/content"
    asyncapi client PaymentsProcessingApi "https://payments.example.com/asyncapi.yml"
    asyncapi client CatalogInventoryApi "catalog-inventory-api/asyncapi.yml"
}
```

For Apicurio Registry v3, use the artifact content route:

```text
{registryBaseUrl}/apis/registry/v3/groups/{groupId}/artifacts/{artifactId}/versions/{versionExpression}/content
```

Prefer stable architecture identifiers over display names:

- `groupId`: use the producer service id from `zenwave-architecture.yml` when available, for example `orders.checkout.orders-checkout`.
- `artifactId`: use a deterministic AsyncAPI artifact id, preferably `{producer-service-kebab}-asyncapi`.
- `versionExpression`: use the producer service version when available, otherwise `latest`.

Do not invent an Apicurio or HTTP host. If the host cannot be discovered from
the repository context or user input, fall back to the local AsyncAPI artifact
path from `zenwave-architecture.yml`, for example `orders-checkout-api/asyncapi.yml`.

### ZDL client entries for direct calls

A direct call (see Direct calls below) references the called system's ZDL, not
its AsyncAPI. Add one `zdl client` entry per called system:

```zdl
apis {
    zdl client CatalogInventoryZdl "https://raw.githubusercontent.com/arcadia-editions/catalog-inventory-api/main/domain-model.zdl"
}
```

- Name ZDL clients `{CalledSystemName}Zdl`, for example `CatalogInventoryZdl`.
- Resolve the location with the same order as AsyncAPI contracts, pointing at the
  called system's ZDL file (its `@zdl(...)` path) instead of its `asyncapi.yml`.
- A relative path is resolved against the declaring ZDL file, not the working directory.
- A system that both calls and listens to another system gets both entries:
  `asyncapi client XApi` for events and `zdl client XZdl` for calls.

## Mapping rules

### 1. One ZDL per system

Each `system` block becomes one `domain-model.zdl`.

The file should contain:

- `config`
- one aggregate root entity
- one lifecycle enum
- input types as needed
- one primary service for that bounded context
- event definitions for the events the service emits

### 2. Aggregate and entity naming

Derive the aggregate root from the bounded context, not mechanically from the service class name.

Examples:

- `OrdersCheckout` -> `Order`
- `CatalogProducts` -> `Product`
- `PaymentsProcessing` -> `Payment`
- `FulfillmentShipping` -> `Shipment`
- `NotificationsConsumer` -> `Notification`

Give the aggregate the fields that were decided with the person (in the grilling, the glossary, the ADRs, the brief)
and the ones the flow itself needs:

- identity
- lifecycle state
- timestamps implied by events
- business values the flow clearly implies

Nothing else: an invented field, rule or state is a decision nobody made. A field the flow needs and nobody has
decided is a question for the person, not a guess.

### 3. Event-driven commands

Map every policy of this form:

```zfl
when SomeEvent do someCommand {
    service SomeSystem.SomeService for (SomeAggregate)
    emits EventA
    emits EventB
}
```

to a ZDL service command on that system.

Classification:

- If the trigger is an `@actor` start event, model the command as actor-facing and annotate it with REST semantics.
- If the trigger is another service's event, it depends on the deployment shape (see section 7):
  - **microservices** (events cross a broker, described by AsyncAPI):
    - add an `api` to `apis` block using the API reference URL resolution rules, for example `apis { asyncapi client OtherServiceApi "https://registry.example.com/apis/registry/v3/groups/orders.checkout/artifacts/orders-checkout-asyncapi/versions/1.0.0/content" }`.
    - name client APIs as `{ProducerSystemName}Api`, for example `OrdersCheckoutApi`.
    - annotate the service command with `@asyncapi(api: OtherServiceApi, channel: "<event-name>-event-v1")`, using the provider's exact channel id.
    - if the event is consumed from the same service's own AsyncAPI, omit `api` and use `@asyncapi(channel: "<event-name>-event-v1")`.
  - **modulith** (events are in-process between modules):
    - add a `zdl client {ProducerSystemName}Zdl "<relative path to the producer ZDL>"` entry to `apis`.
    - annotate the command with `@listener(zdl: ProducerSystemZdl, event: EventName)`. Add one `@listener` per triggering event.
    - if the event is emitted by the same ZDL, use `@listener(event: EventName)` without `zdl:`.
    - do not add `@asyncapi` bindings for in-process events.
- Check the **data lineage** of every event-triggered command: each required field
  of its input must exist, with the same name, in the triggering event (or be
  resolvable by a lookup inside the consuming context, e.g. by `orderId`). If it
  doesn't, add the field to the event or change the input now. Otherwise the
  generated listener or consumer mapping will pass `null` at runtime.
- If it is a standalone `do someCommand { }` block, it is the target of a direct call: model it as a plain command on the called service, `emits` becomes `withEvents` and `response` becomes the return type. See direct calls below.

The emitted outcomes become:

- `withEvents EventA` for one outcome
- `withEvents [EventA | EventB]` for multiple outcomes

### 4. Direct calls

Map every synchronous step of this form:

```zfl
when StartOrderCheckout do startOrderCheckout {
    service OrdersCheckout.OrdersCheckoutService for (Order)
    call reserveStock
    on StockReservedResult emits OrderCreated
    on StockUnavailableResult emits StockUnavailable
}

do reserveStock {
    service CatalogInventory.InventoryService for (StockReservation)
    response StockReservedResult
    response StockUnavailableResult
}
```

as two separate concerns:

1. The orchestrating command stays on the calling service and declares the call
   with `@calls`.
2. The called operation becomes a plain command on the called service.

Direct calls are declared with `@calls` on the caller, not with `@post` on the
callee and not with `@asyncapi`.

Implications:

- `startOrderCheckout` belongs to `OrdersCheckoutService` and carries
  `@calls(zdl: CatalogInventoryZdl, command: InventoryService.reserveStock)`.
- `reserveStock` belongs to `InventoryService`. It needs no transport annotation
  because it is a direct call target. Keep an existing `@post` only if the command
  is also exposed to actors over REST.
- The `response` values become the return type of the called command. See Responses below.
- The caller's `on <Response> emits <Event>` clauses become the caller's `withEvents`.

Use this pattern:

```zdl
// calling system: orders-checkout-api/domain-model.zdl
apis {
    zdl client CatalogInventoryZdl "https://raw.githubusercontent.com/arcadia-editions/catalog-inventory-api/main/domain-model.zdl"
}

@rest("/orders")
service OrdersCheckoutService for (Order) {
    @post
    @transition(to: CREATED)
    @calls(zdl: CatalogInventoryZdl, command: InventoryService.reserveStock)
    startOrderCheckout(StartOrderCheckoutInput) Order withEvents [OrderCreated | StockUnavailable]
}

// called system: catalog-inventory-api/domain-model.zdl
service InventoryService for (StockReservation) {
    @transition(to: RESERVED)
    reserveStock(ReserveStockInput) ReserveStockResult
}
```

`@calls` rules:

- `zdl:` names a `zdl client` entry in the caller's `apis` block. Add that entry
  if it is missing (see ZDL client entries above).
- `command:` is always qualified as `Service.command`, using the service name
  from the ZFL `service System.Service` line of the called `do` block. A ZDL can
  declare several services, so a bare command name may be ambiguous.
- Omit `zdl:` when the called command lives in the same ZDL, for example
  `@calls(command: InventoryBackofficeService.adjustStock)`.
- Add one `@calls` per ZFL `call` line, in the same order as the flow.
- `@calls` can sit alongside `@post`, `@asyncapi`, and `@transition`. For example,
  an event-triggered command that also makes a direct call gets both
  `@asyncapi(...)` and `@calls(...)`.
- Do not encode the `on <Response> emits <Event>` mapping in `@calls`. The
  caller's `withEvents` and the callee's return type already carry it.

### 5. Responses and events

Treat `response` names in a direct call definition as the called command's
synchronous results, not as published events.

- Model each `response` as an `output` type in the called system's ZDL, keeping
  the flow's name.
- **One response:** that `output` is the command's return type.
- **Several responses:** a ZDL method has a single return type and no union, so
  wrap them in a `<Command>Result` output (PascalCase command name + `Result`):
  - an `<Command>Outcome` enum with one value per response, in flow order. Derive
    each value from the response name without the `Result` suffix, as
    UPPER_SNAKE_CASE, and shorten it to the state it names (e.g.
    `StockReservedResult` -> `RESERVED`, `StockUnavailableResult` -> `UNAVAILABLE`);
  - an `outcome <Command>Outcome required` field;
  - one optional (nullable) field per response, typed with that response's `output`,
    named after the outcome in lowerCamelCase (`reserved`, `unavailable`);
  - a javadoc stating that exactly one of those fields is set, according to `outcome`.

  The command returns the wrapper. The caller branches on `outcome` (Kotlin:
  `when (result.outcome)`), and its `on <Response> emits <Event>` clauses map one
  outcome to one event in its `withEvents [A | B]`.
- Do not add `@asyncapi` to responses and do not list them in `withEvents`.
- If the called `do` block also declares `emits`, those become the called
  command's `withEvents` and are published events as usual.

```zdl
service InventoryService for (StockReservation) {
    @transition(to: RESERVED)
    reserveStock(ReserveStockInput) ReserveStockResult
}

enum ReserveStockOutcome {
    RESERVED
    UNAVAILABLE
}

/**
 * Wrapper for the two ZFL responses of reserveStock (ZDL has no union return type).
 * Exactly one of `reserved` / `unavailable` is set, according to `outcome`.
 */
output ReserveStockResult {
    outcome ReserveStockOutcome required
    reserved StockReservedResult
    unavailable StockUnavailableResult
}

output StockReservedResult {
    reservationId String
    orderId String
}

output StockUnavailableResult {
    orderId String
    availableQuantity Integer
}
```

### 6. Lifecycle and transitions

Read the flow as a state machine.

For each service:

- identify the first command that creates or takes ownership of the aggregate
- infer the initial lifecycle state
- infer subsequent states from the happy path and compensations
- annotate state-changing methods with `@transition`

Guidance:

- Use `@transition(to: STATE)` for the creation step.
- Use `@transition(from: STATE_A, to: STATE_B)` for normal progression.
- Use `@transition(from: [STATE_A, STATE_B], to: STATE_C)` when multiple source states are valid.
- If one command can end in multiple distinct states, use multiple `@transition` annotations.

Do not force every event into a state transition. Query methods and pure notification handlers may have no transition.

### 7. Transport annotations

Use transport annotations by interaction type:

- actor-facing command -> `@rest` on the service and `@post` on the method
- command that makes a direct call -> `@calls(zdl: CalledSystemZdl, command: Service.command)` on the calling method
- direct call target -> no transport annotation on the called method
- event-triggered command: depends on the deployment shape:

| Shape | Event from another system | Event from the same ZDL | `apis` entry | Generated consumer |
|---|---|---|---|---|
| microservices | `@asyncapi(api: OtherServiceApi, channel: "<message-name>-<message-type>-<version>")` | `@asyncapi(channel: "...")` | `asyncapi client XApi "<url>"` | AsyncAPI consumer adapter (`*ConsumerService`) over Spring Cloud Stream |
| modulith | `@listener(zdl: OtherSystemZdl, event: EventName)` | `@listener(event: EventName)` | `zdl client XZdl "<path>"` | in-process `@ApplicationModuleListener` class |

Never mix the two styles for the same event in one model. In a modulith, events
may still be externalized to a broker (outbox + Spring Cloud Stream). That's
publisher configuration, not a reason to use `@asyncapi` on consumers.

Omit `@rest` on a service with no actor-facing commands.

### 8. Naming conventions

Read and apply `asyncapi-naming-conventions.md` before generating a ZDL file.
In summary:

- model id: `urn:<org>:<domain>:<subdomain>`
- provider plugin id: `urn:<org>:<domain>:<subdomain>:asyncapi`
- client plugin id: `urn:<org>:<domain>:<subdomain>:asyncapi:client`
- base package: `<org>.<domain>.<subdomain>`

`<org>` is the organization's reverse-domain prefix from the project overlay (the
examples in this skill use `com.arcadiaeditions`).
- channel id: `<message-name>-<message-type>-<version>`
- topic: `<domain>-<subdomain>.<message-name>.<message-type>.<content-type>.<version>`
- AsyncAPI client name: `{ProducerSystemName}Api`, for example `OrdersCheckoutApi`
- ZDL client name: `{CalledSystemName}Zdl`, for example `CatalogInventoryZdl`

Use existing repository context to resolve the domain, subdomain, content type,
and version, but do not let an older example override these formats.

## Quality checklist

Before writing each file, verify:

- Every command owned by the service appears as a service method.
- Every emitted event owned by the service appears as an event block.
- Every ZFL `call` line has a matching `@calls` on the calling command, with a qualified `Service.command`.
- A called command with several `response` values returns a `<Command>Result` wrapper with an `<Command>Outcome` enum and one optional field per response; with one response, it returns that `output` directly.
- Every `@calls(zdl: X, ...)` has a matching `zdl client X` entry in `apis`.
- Every `@calls` target exists as a command on the named service in the called system's ZDL.
- Direct call targets have no `@post` unless they are also actor-facing.
- Event-triggered commands use the style of the deployment shape (`@asyncapi` for microservices, `@listener` for a modulith), never both, and are not mislabeled as direct calls.
- Every event-triggered command's required input fields exist in the triggering event (data lineage), or are resolvable by a lookup in the consuming context.
- State-changing methods have `@transition` annotations.
- Lifecycle enum values cover every state referenced by `@lifecycle` and `@transition`.
- `withEvents` matches the outcomes declared in the flow.
- The model id and any AsyncAPI plugin ids follow `asyncapi-naming-conventions.md`.
- Locally owned channels and topics follow `asyncapi-naming-conventions.md`.
- Consumed channel ids exactly match the provider's channel ids.
- Output paths honor `@zdl(...)` when present.
- Existing files were preserved or updated intentionally, not overwritten by accident.

## Writing style

- Stay close to the grammar and example.
- Prefer simple, valid models over speculative completeness.
- Keep one aggregate root per file unless the user explicitly asked for a richer model.
- Use ASCII only.
- Keep comments sparse and only where structure would otherwise be unclear.
