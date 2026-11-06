# What ZenWave SDK generates, and what it leaves to you

ZenWave SDK generates the structure of a Spring Boot service from its ZDL deterministically: entities, repositories,
services and their implementations, DTOs, mappers, domain events, listeners, controllers, in-memory test configs and
test skeletons. It leaves the behavior. This is how to recognise what is left, artifact by artifact. Java and Kotlin
generate the same shapes.

## Who owns each file

| Kind | Examples | Edited by |
|---|---|---|
| **Regenerated** on every run | DTOs, inputs, domain events, `*Transitions`, OpenAPI interfaces and models, AsyncAPI producers and consumer interfaces (`target/generated-sources`) | nobody: if one is wrong, the fix is in the ZDL or a generator template |
| **Generated once**, then the developer's | `*ServiceImpl`, `*ServiceMapper`, `EventsMapper`, `*EventsListener` and `*EventsListenerMapper`, `*ConsumerService` adapters, controllers, tests, `ServicesInMemoryConfig`, in-memory repositories, `src/test/resources/data*`, `DockerComposeInitializer` | the AFK loop |

A run with `--force` overwrites generated-once files too. After every regeneration, `git diff` shows what moved.

## Deployment shape

Read it from the project overlay. It changes where the wiring lives.

| | Microservices (Kafka + AsyncAPI) | Modulith |
|---|---|---|
| Scope of one repository | one bounded context: its slice of each flow | every bounded context: whole flows |
| ZDL consumer | `@asyncapi(api: XApi, channel: ...)` | `@listener(zdl: XZdl, event: ...)`, `@listener(event: ...)` |
| Inbound event code | `*ConsumerService` adapters over the AsyncAPI consumer interfaces, plus Spring Cloud Stream bindings | `*EventsListener` with `@ApplicationModuleListener` |
| Not-implemented marker | `// TODO CUSTOM_REQUIRED` and `throw UnsupportedOperationException` | listener mappers with unmapped fields |
| Cross-context call (`@calls`, ZFL `call`) | an HTTP client behind a port | the other module's service interface |
| Flow test | this service's part: consume the triggering message, assert the produced one, with a Testcontainers or embedded broker | Spring Modulith `Scenario` or `@SpringBootTest`, one JVM |

## The unimplemented service method

```kotlin
val x = mapper.update(Entity(), input)   // a new, empty entity; never loaded
// TODO: implement this method
eventPublisher.onA(eventsMapper.asA(x))  // every withEvents alternative emitted
eventPublisher.onB(eventsMapper.asB(x))  // unconditionally
return x                                 // never saved
```

A command implements its ZDL and ZFL lines when it has, as they apply:

- **Load**: commands with `@transition(from: ...)` load the aggregate by id or natural key; the repository has the
  finder (`findByOrderId`), and so does the in-memory repository.
- **Guard**: `<Aggregate>Transitions.ensureCan<Command>()`.
- **Mutate**: the status of `@transition(to:)`, timestamps, counters, business ids.
- **Persist**: `repository.save(...)`.
- **Branch**: with `withEvents [A | B]` or ZFL `@outcome`, exactly one event, chosen by a real result. A called
  command with several ZFL `response`s returns a `<Command>Result` with an `outcome` and one field per response.
- **Call**: `@calls` / ZFL `call` implemented, and its result drives the branch. Generated code leaves a
  `// TODO: call ...` comment.
- **Side effects** on another aggregate the ZFL narrative implies (reserving stock moves the inventory counters).
- **Idempotency**: listeners are redelivered (Spring Modulith event publication registry, Kafka); a second delivery
  changes nothing and emits nothing.
- **External integration** (payment provider, carrier, e-mail): a port and a deterministic stub adapter.

`TODO: may need to reload the entity` on a pure create is harmless unless the entity has relationships.

## Flow wiring

Every ZFL `when <Event> do <command>` needs an inbound adapter that receives the event and calls the command:

- Same-context edges (`PaymentFailed -> retryPayment`) are easy to miss. In a modulith they need a local
  `@listener(event: ...)` in the ZDL; if it is missing, that is a model gap, not code to hand-write.
- `@time(...)`, `@timer`, `@actor(Scheduler)`: ZenWave generates no scheduler. A job on a persisted deadline
  (`expiresAt`) with an injected `Clock`, unless the overlay says otherwise.
- In microservices, the channel's binding in `application*.yml`, and the consumed AsyncAPI version matching the
  provider's.

## Mappers (MapStruct)

- Compile clean and collect `Unmapped target propert(y|ies)` warnings: an objective list of mapper gaps.
- For each listener, compare the triggering event's fields with the target input's required fields: same name is
  fine; a rename or type change needs a `@Mapping`; a value the target can load itself is service work; a value
  that exists nowhere upstream is a **model gap**.
- In Kotlin, a generated mapper that passes `null` into a non-null parameter throws at runtime: look for `= null`
  locals in `target/generated-sources/kapt/**/*Impl.java`.
- Event mappers whose event needs data from the input or a call result, not the entity.

## Web layer

- Each `@rest` service has a controller (`OpenAPIControllersPlugin` in `zenwave-scripts.zw`).
- Status codes from the OpenAPI, `@Valid`, and error mapping: not found → 404, invalid transition → 409, validation
  → 400.
- An asynchronous flow started by a POST needs a way for the actor to see the outcome. If the ZDL has no query, it is
  a question for the person.

## Tests and test data

- Generated service tests with `// TODO: implement this test`.
- Generated assertions that will be wrong once the behavior exists (a timestamp asserted on a state not reached).
- Two data sets: JSON aggregates (`src/test/resources/data/<persistence>/<Entity>/<n>.json`) for the in-memory
  service tests, and `data.sql` for the integration tests with Testcontainers. Each command's precondition state
  must exist in both, with ids that chain across contexts.
- `ServicesInMemoryConfig` must still build when a service gets a new dependency (a call, a port).
- One flow test per ZFL `end` outcome.

## Checks the project gives you

```bash
mvn -DskipTests clean compile 2>&1 | tee target/compile.log
grep -i "unmapped target" target/compile.log
grep -rn "TODO CUSTOM_REQUIRED\|TODO: implement\|TODO: call" src/main
grep -rn "TODO: implement this test" src/test
```

The overlay gives the project's real commands (JDK, wrapper, how the ZDLs reach the generator).
