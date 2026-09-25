---
name: zenwave-gap-report
description: Audit a ZenWave-generated backend (Kotlin or Java, Spring Boot) against its ZFL flows and ZDL models and write a gap report of missing behavior - service method bodies, event listener wiring and mappings, MapStruct mappers, REST controllers, test fixtures and tests. Read-only. Use after (re)generating code with zenwave-scripts.zw, before planning implementation work, or when asked "what is missing / left to implement".
---

# ZenWave Gap Report

ZenWave generates the *structure* of a service from ZDL (entities, services, DTOs,
events, listeners, mappers, controllers, test skeletons) and deliberately leaves the
*behavior* to the developer. This skill finds that missing behavior and writes it
down as a report that a developer, an agent, or Spec Kit `tasks.md` can act on.

**This skill is read-only.** Do not edit `src/`. Fixing is done by
[zenwave-fill-gaps](../zenwave-fill-gaps/SKILL.md), which uses the report as input.

## Principles

- **Models are the spec.** ZFL says *when* and *why* (flow, outcomes,
  compensations, timers). ZDL says *what* (aggregates, lifecycle, commands, inputs,
  events, `@listener`, `@calls`). The code must implement what they say. Every gap
  you report must name the ZFL/ZDL line that defines the expected behavior.
- **ZDL owns structure.** If a gap can't be closed without a new field, input,
  event or command, it's a **model gap**. Report it against the ZDL, not the code.
  The fix is to edit ZDL and regenerate, never to hand-add structure.
- **Never invent business rules.** If ZFL/ZDL doesn't say (validation limits,
  retry counts, which of two events wins), write it as an **open question**. Don't
  write a guess.
- **Compiling is not evidence.** Generated code compiles and starts, and it can
  still emit every event unconditionally, never persist, or pass `null` into
  non-null Kotlin parameters. Check behavior, not the build.

## Inputs to locate first

Find these before you start. A project overlay skill (e.g.
`<architecture-repo>/skills/<project>-zenwave-overlay.md`) usually lists them.

1. ZFL flow files (`*.zfl`) - the business flows.
2. ZDL files (`*.zdl`) - one per bounded context.
3. `zenwave-scripts.zw` - which plugins ran against which ZDL/OpenAPI files.
4. The generated service source (`src/main`, `src/test`, `src/test/resources`).
5. Deployment shape. It changes where the wiring lives and what the audit covers:

   | | **Microservices** (Kafka + AsyncAPI) | **Modulith** |
   |---|---|---|
   | Repo scope | one bounded context; audit only this repo's slice of each flow | all bounded contexts; audit whole flows |
   | ZDL consumer annotation | `@asyncapi(api: XApi, channel: ...)` | `@listener(zdl: XZdl, event: ...)` / `@listener(event: ...)` |
   | Inbound event code | developer-owned `*ConsumerService` adapters implementing the AsyncAPI-generated consumer interfaces, plus Spring Cloud Stream bindings | `*EventsListener` classes with `@ApplicationModuleListener` |
   | "Not implemented" marker | `// TODO CUSTOM_REQUIRED` + `throw UnsupportedOperationException` in the adapter | listener mapper contract with unmapped fields |
   | Event payload (data lineage source) | the provider's AsyncAPI message schema (Avro/JSON), at the version this service resolves | the producer module's event class |
   | Cross-context call (`@calls`) | an OpenAPI/HTTP client behind a port | injecting the other module's service interface |
   | Flow-level tests | per-service consumer/producer tests with an embedded or Testcontainers broker; end-to-end in a shared environment | Spring Modulith `Scenario` / `@SpringBootTest` in one JVM |

## Procedure

Work in this order. Each step feeds the next.

### 1. Lint the models

Before you trust the models as the spec, lint every ZDL (run from the project root;
use the ZDL files found in the inputs step):

```bash
bash <zenwave-sdd>/skills/zfl-to-zdl/scripts/lint-zdl.sh --strict <zdl-dir-or-files>...
```

Read each `target/zdl-lint/<name>.json` (`diagnostics[]` with `ruleId`, `modelPath`,
`file`, `line`, `message`). Turn findings into **model-gap (M-\*) findings**, citing
`ruleId` + `modelPath` and the ZDL line:

- every lint **error** (for example `zdl.unknown-type`, `zdl.unknown-event`,
  `zdl.transition-state`, `zdl.reference-unresolved`, `zdl.listener-event`,
  `zdl.calls-command`, `zdl.semantic`);
- `zdl.data-lineage` and `zdl.mixed-event-binding`, which are warnings and only
  appear with `--strict`. Step 4 goes deeper on lineage.

A `zdl.reference-unresolved` on a `zdl client` is often a cascade of parse problems
in the referenced file. Group it under the root-cause finding rather than
reporting it twice.

**Exit code 2 is a tooling problem, not a model gap** (bad path, linter crash, no
`Lint` plugin in `jbang zw`). Report it under tooling, with the first lines of
`<name>.stderr.log`, and don't derive model findings from that file.

### 2. Build the traceability map

Build a table from each ZFL flow. Each row is one ZFL step:

`trigger (command/event/timer) -> service.command -> expected outcomes/events -> @compensates`

Then resolve each row to ZDL (service method, input, return, `withEvents`,
`@transition`, `@listener`/`@asyncapi`/`@timer`, `@calls`) and to code (the
`*ServiceImpl` method, the listener class/method, the mapper method).

Flag **identity mismatches** between ZFL and ZDL (typos, a system's `@zdl(...)` path
pointing at the wrong file, `@compensates(x)` where `x` doesn't exist). They are
cheap to fix, and otherwise they cause false findings downstream.

### 3. Check flow wiring: every ZFL edge has a trigger in code

For every `when <Event> do <command>` in ZFL, check:

- Is there an inbound adapter that receives `<Event>` and calls `<command>`?
  - **Microservices:** a `*ConsumerService` adapter method for the channel, calling
    the command (not throwing `UnsupportedOperationException` /
    `TODO CUSTOM_REQUIRED`), plus a Spring Cloud Stream binding for the channel's
    topic in `application*.yml`. The consumed AsyncAPI version must match the one
    the provider publishes. For edges whose command lives in *another* service,
    only check that this service publishes the triggering event.
  - **Modulith:** an `@ApplicationModuleListener` method that calls the command.
- **Same-context edges** (the event and the command live in one bounded context, e.g.
  `PaymentFailed -> retryPayment`) are easy to miss. In a modulith they need a local
  `@listener(event: ...)` in the ZDL; `@asyncapi(channel: ...)` there is a broker
  binding, not an in-process listener. In microservices, the service must consume its
  own channel, or call the command directly. Report missing ones as missing wiring.
- `@timer` / `@time(...)` / `@actor(Scheduler)` steps need a scheduler: a job,
  deadline table or delayed message. ZenWave doesn't generate these.
- `do x { call y }` / ZDL `@calls(...)` needs a synchronous call from one service
  into another (a port or client in a microservice, a module API in a modulith).
  Generated code only leaves a `// TODO: call ...` comment.

### 4. Check data lineage for every listener / consumer mapping

In microservices, the "event" is the provider's AsyncAPI message schema, and the
mapping lives in the consumer adapter's `EventsMapper`.

For every listener, compare the **triggering event's fields** with the **target
input's required fields**:

| Target input field | Source | Verdict |
|---|---|---|
| same name in event | direct | OK |
| different name / type (e.g. `productId` vs `sku`, free-text `reason` vs enum) | needs `@Mapping` or a constant | **mapper gap** |
| derivable by lookup in the target BC (e.g. `paymentId` by `orderId`) | service must load the aggregate | **service gap** (and input may be over-specified) |
| exists nowhere upstream | none | **model gap** + open question |

Check the generated MapStruct impl (`target/generated-sources/kapt/**/*Impl.java` or
`target/generated-sources/annotations/**`) for `= null` locals passed to
constructors. **In Kotlin, a null passed into a non-null DTO parameter throws a
`NullPointerException` at runtime.** Count these as runtime-crash findings, not
cosmetic ones.

Also run a clean compile and collect MapStruct `Unmapped target propert(y|ies)`
warnings (`mvn -DskipTests clean compile`, then grep the log). They're an
objective list of mapper gaps.

### 5. Inspect each generated service method

ZenWave's recognizable "not implemented" shape:

```kotlin
val x = mapper.update(Entity(), input)   // new, empty entity; never loaded
// TODO: implement this method
eventPublisher.onA(eventsMapper.asA(x))  // every withEvents alternative emitted
eventPublisher.onB(eventsMapper.asB(x))  // unconditionally
return x                                 // never saved
```

For each method, check each item below and report every miss:

- **Load**: for commands with `@transition(from: ...)`, is the aggregate loaded by
  id or natural key? Is there a repository finder for the natural key
  (`findByOrderId`, `findBySku`)?
- **Guard**: is `<Aggregate>Transitions.ensureCan<Command>()` called?
- **Mutate**: status set to the `@transition(to:)` target; timestamps
  (`confirmedAt`, `releasedAt`…) set; counters updated (`attemptCount`,
  quantities); business ids generated (`orderId`, `paymentId`…).
- **Persist**: `repository.save(...)` is called.
- **Branch**: when `withEvents [A | B]` or ZFL `@outcome(...)` lists alternatives,
  exactly one is emitted, based on a real decision.
- **Cross-BC call**: `@calls` implemented, and its result drives the branch.
- **Side-aggregate effects**: e.g. reserving stock must also move counters on the
  inventory position aggregate. Look for the aggregate the ZFL narrative implies.
- **Idempotency**: listeners can be redelivered (Spring Modulith event
  publication registry, Kafka). A second delivery must not double-apply.
- **External integration**: payment provider, carrier, email sender… Needs a port
  interface plus a stub adapter. Report this as a gap, and ask which provider as an
  open question.

`TODO: may need to reload the entity` on a pure create is usually benign. Mention it
only if the entity has relationships.

### 6. Inspect event mappers (`EventsMapper`)

For every `as<Event>(entity)`: can every event field be filled from the source?
Typical gaps: the event needs data from the *input* or a *call result*, not the
entity (e.g. `StockUnavailable.requestedQuantity`), a type mismatch (`Long id`
to `String productId`), or a field with no source at all.

### 7. Inspect the web layer

- Every ZDL service with `@rest` has a controller. If none exists, check whether
  `zenwave-scripts.zw` runs `OpenAPIControllersPlugin` for that ZDL, and whether an
  OpenAPI file exists for it.
- Controller bodies: correct status codes, input validation (`@Valid`, ZDL
  `minlength`/`required`), error mapping (not found → 404, invalid transition →
  409, validation → 400) in the exception translator.
- Query endpoints: can the actor observe the outcome? (e.g. an async flow started
  by POST with no GET for status). If ZDL has none, ask it as an open question.
- DTO mapper gaps, the same as step 6.

### 8. Inspect tests and fixtures

- Service tests with `// TODO: implement this test`: list each one with the
  scenarios it needs: happy path, each alternative outcome, invalid transition,
  not-found, idempotent redelivery.
- Generated assertions that will be **wrong** once the behavior exists (e.g.
  asserting `cancelledAt` is not empty on a newly created order, or expecting 201
  for an input that violates `minlength(1)`).
- Fixtures: is there at least one record per lifecycle state each command needs as
  a precondition? Are cross-module references consistent (same `orderId`/`sku`
  chain, and states that agree across aggregates)?
- In-memory test configs (`ServicesInMemoryConfig`): will they still build once a
  service gets a new dependency (a cross-BC call, a port)?
- Flow-level test: at least one test per ZFL `end` outcome. In a modulith, use a
  Spring Modulith `Scenario` or a `@SpringBootTest` with published events. In
  microservices, this service's part of it: consume the triggering message, assert
  the produced message, with an embedded or Testcontainers broker.

### 9. Write the report

Use [report-template.md](report-template.md). Group findings as
**flow → bounded context → artifact**, so that:

- in a **modulith**, one ZFL flow = one Spec Kit feature, with one phase per
  bounded context in flow order;
- in **microservices**, each service repo takes only its bounded context's
  section as its feature, and links back to the flow.

Put findings that no flow touches (backoffice CRUD, unused endpoints) under
**Baseline** for each bounded context.

Give every finding a stable id (`G-<BC>-<nn>`, `M-<nn>` for model gaps,
`Q-<nn>` for open questions), a severity, the model reference, the code reference
(`path:line`), and the expected behavior in one or two sentences.

Severity:
- **blocker**: runtime crash, or a flow can't progress (NPE, missing trigger, model
  gap).
- **major**: wrong behavior (emits all alternatives, never persists, no guard).
- **minor**: incomplete but harmless (missing timestamp, weak test assertion).

## Output location

Write to `docs/zenwave-gap-report.md` in the implementation repo, unless the
project overlay says otherwise. This whole-service report is the baseline; re-run it
after every regeneration and keep it under version control so its diff shows what changed.

When the repo uses Spec Kit (a `.specify/` folder exists), the report also feeds each
feature (`specs/NNN-<flow>/`):

| Report section | Spec Kit artifact |
|---|---|
| Traceability table + findings for that flow | `research.md` (copy the flow's slice; plan cites it) |
| Model gaps (M-*) and open questions (Q-*) | `/speckit-clarify` questions; answers go back into ZFL/ZDL, not into the spec |
| Code findings (G-*, X-*) for that flow | seed tasks for `/speckit-tasks`, keeping the ids (`T012 [G-OC-03] ...`) |
| Baseline section | a separate `000-<bc>-baseline` feature |

Keep the finding ids stable across re-runs (same gap = same id), so tasks and
converge findings can refer to them.
