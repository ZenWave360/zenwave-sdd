---
name: zfl-to-zdl
version: 1.6.0
description: >
  Generate one ZDL domain model per system from a ZFL business flow. Map
  actor starts, event-driven policies, and direct synchronous calls into ZDL
  services, commands, events, lifecycle state, transitions, and transport
  annotations.
triggers:
  - "zfl-to-zdl"
  - "generate ZDL from ZFL"
  - "domain model from flow"
  - "ZenWave ZDL"
  - ".zfl"
applies_to:
  - claude
  - codex
  - any agent with file read/write access
---

# Skill: ZFL to ZDL

Generate one `domain-model.zdl` per system declared in a ZFL flow.

This skill is for scaffold generation, not final domain design. The output should
be structurally valid, grounded in the flow, and conservative about assumptions.

## Inputs

Read these inputs before generating anything:

1. The target ZFL flow file.
2. Any `@zdl("...")` mappings declared inside the `systems` block.
3. `zenwave-architecture.yml` if present, to resolve repository paths and base packages.
4. `references/zdl-asyncapi-naming-conventions.md` in this skill's folder (or the
   project's own naming conventions, if the project overlay points to them), for the
   mandatory ZDL service ids, AsyncAPI plugin ids, channel ids, and topic names.
5. The canonical ZDL grammar URL:
   `https://raw.githubusercontent.com/ZenWave360/dsl-kotlin/refs/heads/main/src/commonMain/antlr/io.zenwave360.language.antlr/Zdl.g4`
6. Existing `domain-model.zdl` files in target repos, if they already exist.
7. The project overlay, if present, for the **deployment shape** (`microservices` or
   `modulith`), the organization prefix used in ids and packages (e.g.
   `com.arcadiaeditions`), and any project naming conventions. If there's no overlay
   and the shape can't be inferred from existing ZDLs (`@asyncapi` means
   microservices, `@listener` means modulith), ask the user.

## Reference resolution order

Use references in this order:

1. The canonical ZDL grammar URL:
   `https://raw.githubusercontent.com/ZenWave360/dsl-kotlin/refs/heads/main/src/commonMain/antlr/io.zenwave360.language.antlr/Zdl.g4`
2. `references/zdl-asyncapi-naming-conventions.md` for AsyncAPI-related identity, channel,
   and topic naming.
3. Existing local `domain-model.zdl` files in target or sibling repos.
4. The embedded ZDL example at the end of this skill.
5. Any user-provided example.

Do not search for or depend on a local `Zdl.g4`. Use the canonical grammar URL as the grammar source.
The grammar is the source of truth for syntax.
The supporting naming file is the source of truth for ZDL AsyncAPI identifiers,
channel ids, and topic names. Examples are references for structure and idiom,
not for overriding the grammar or naming rules. Prefer existing local
`domain-model.zdl` files over the embedded example for style.

## Invocation

Natural language is enough:

> Generate ZDL models from this ZFL, one per system, using the `@zdl(...)` targets,
> with lifecycle, transitions, commands, events, and transport annotations.

## Execution order

1. Read the ZFL and enumerate all systems.
2. Resolve the output path for each system.
3. Extract every command, event, response, and direct call relevant to each system.
4. Infer the aggregate root, lifecycle states, and transitions for each bounded context.
5. Generate one `domain-model.zdl` per system.
6. Validate the result against the checklist before writing, then lint every file
   with the ZenWave `Lint` plugin (one file per run, real path, because `zdl client`
   references resolve relative to the ZDL file):
   `bash skills/zfl-to-zdl/scripts/lint-zdl.sh --strict <file.zdl|dir>...`
   (equivalent to `jbang zw -p Lint zdlFile=<file> format=json strict=true 2>/dev/null`
   per file). Reports go to `target/zdl-lint/<name>.json`. Read the result like this:
   - **Exit code:** `0` clean; `1` findings (errors, or warnings with `strict=true`);
     `2` the tool failed (bad path, linter crash). `2` means "lint broke", not "the
     model is wrong": read `<name>.stderr.log` (the script keeps it whenever the
     exit code is not 0) and fix the invocation.
   - **stdout:** exactly one JSON document, even when clean (`diagnostics: []`). Each
     diagnostic has `file`, `line`, `column` (1-based), `severity`, `ruleId`,
     `message` and `modelPath`. `modelPath` (e.g. `entities.Customer.fields.name.type`,
     `services.X.methods.y.withEvents.0`) says which element to fix. Fix the first
     error first: `zdl.reference-unresolved` on a `zdl client` is usually a cascade of
     parse problems in the *referenced* file, so lint and fix that one first.
   - **stderr:** debug logs and the parser's own `ZDL ERROR` lines. Ignore it when the
     exit code is 0 or 1; read it when the exit code is 2.
   - **`strict=true`** also fails on the warnings `zdl.data-lineage` and
     `zdl.mixed-event-binding`, which are worth resolving in a generated model.
   - **Custom linters:** `linters=` *replaces* the default set
     (`ZdlProblems,ZdlReferences,ZdlCalls,ZdlListener`), so a custom list must name
     the built-ins it wants to keep. Add the jar with `ZW_DEPS` (`-d`).
   Rule ids: `zdl.syntax`, `zdl.parser`, `zdl.transition-state`, `zdl.lifecycle-initial`,
   `zdl.lifecycle`, `zdl.unknown-type|event|input|output|aggregate`, `zdl.semantic`,
   `zdl.reference-unresolved`, `zdl.calls-command`, `zdl.listener-event`,
   `zdl.mixed-event-binding`, `zdl.data-lineage`.
   `Lint` is unreleased: it needs a local `jbang zw` build that includes it.
7. Report written files and any assumptions that were not explicit in the flow.

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

Add only the minimum domain fields needed to support:

- identity
- lifecycle state
- timestamps implied by events
- business values clearly implied by the flow

Do not invent a rich domain model unless the user explicitly asked for enrichment.

### 3. Event-driven commands

Map every policy of this form:

```zfl
when SomeEvent do someCommand {
    service SomeSystem.SomeService
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
    service OrdersCheckout.OrdersCheckoutService
    call reserveStock
    on StockReservedResult emits OrderCreated
    on StockUnavailableResult emits StockUnavailable
}

do reserveStock {
    service CatalogInventory.InventoryService
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

Read and apply `zdl-asyncapi-naming-conventions.md` before generating a ZDL file.
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
- The model id and any AsyncAPI plugin ids follow `zdl-asyncapi-naming-conventions.md`.
- Locally owned channels and topics follow `zdl-asyncapi-naming-conventions.md`.
- Consumed channel ids exactly match the provider's channel ids.
- Output paths honor `@zdl(...)` when present.
- Existing files were preserved or updated intentionally, not overwritten by accident.

## Writing style for generated ZDL

- Stay close to the grammar and example.
- Prefer simple, valid scaffolds over speculative completeness.
- Keep one aggregate root per file unless the user explicitly asked for a richer model.
- Use ASCII only.
- Keep comments sparse and only where structure would otherwise be unclear.

## Report back

When done, report:

- files created or updated
- direct calls discovered, as `caller -> @calls(zdl: X, command: Service.command)`
- assumptions made about aggregate names, states, or fields

## Embedded ZDL example

Use the following example as the default syntax and style reference when no better
local example exists. Prefer its structure and idioms, but keep generated output
minimal and specific to the target flow.

```zdl
config {
    id "urn:com.arcadiaeditions:orders:fulfillment"
    title "Order Fulfillment Example"
    basePackage "com.arcadiaeditions.orders.fulfillment"
}

@aggregate
@lifecycle(field: status, initial: DRAFT)
entity Order {
    @naturalId
    orderNumber String required unique maxlength(36)
    status OrderStatus required
    totalAmount BigDecimal required
}

enum OrderStatus {
    PLACED(1),
    PAID(2),
    SHIPPED(3),
    CANCELLED(4)
}

input PlaceOrderInput {
    items OrderItem[] minlength(1)
    currency String required maxlength(3)
}

input PayOrderInput {
    paymentReference String required
}

input ShipOrderInput {
    trackingNumber String required
}

@rest("/orders")
service OrderService for (Order) {

    @post
    @transition(to: PLACED)
    placeOrder(PlaceOrderInput) Order withEvents OrderPlaced

    @post("/{orderNumber}/pay")
    @transition(from: PLACED, to: PAID)
    payOrder(@natural id, PayOrderInput) Order withEvents OrderPaid

    @post("/{orderNumber}/ship")
    @transition(from: PAID, to: SHIPPED)
    shipOrder(@natural id, ShipOrderInput) Order withEvents OrderShipped

    @post("/{orderNumber}/cancel")
    @transition(from: [DRAFT, PLACED], to: CANCELLED)
    cancelOrder(@natural id) Order withEvents OrderCancelled

    @get("/{orderNumber}")
    getOrder(@natural id) Order?
}

@asyncapi({ channel: "order-placed-event-v1", topic: "orders-fulfillment.order-placed.event.avro.v1" })
event OrderPlaced {
    id Long
    version Integer
}

@asyncapi({ channel: "order-paid-event-v1", topic: "orders-fulfillment.order-paid.event.avro.v1" })
event OrderPaid {
    id Long
    version Integer
}

@asyncapi({ channel: "order-shipped-event-v1", topic: "orders-fulfillment.order-shipped.event.avro.v1" })
event OrderShipped {
    id Long
    version Integer
    trackingNumber String
}

@asyncapi({ channel: "order-cancelled-event-v1", topic: "orders-fulfillment.order-cancelled.event.avro.v1" })
event OrderCancelled {
    id Long
    version Integer
}
```
