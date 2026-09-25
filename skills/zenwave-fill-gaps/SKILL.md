---
name: zenwave-fill-gaps
description: Implement the missing behavior in a ZenWave-generated Spring Boot backend (Kotlin or Java) - service method bodies, cross-context calls, event listener wiring, MapStruct mappings, error mapping, test fixtures and tests - working from a zenwave-gap-report and the ZFL/ZDL models. Use when asked to implement, fix or complete findings from the gap report, or a Spec Kit task that points at one.
---

# ZenWave Fill Gaps

Turns findings from [zenwave-gap-report](../zenwave-gap-report/SKILL.md) into working code.
Work one finding (or one Spec Kit task) at a time.

## Before touching code

1. **Read the finding and its model reference.** Re-open the ZFL step and the ZDL
   method. The model is the spec; the report is only an index into it.
2. **Model gap (M-*) or unanswered open question (Q-*) still open? Stop.** Don't
   work around it in code. Propose the ZDL/ZFL change, and after it's accepted:
   edit the ZDL → regenerate with `zenwave-scripts.zw` (the project overlay says
   how) → re-run the gap report. Hand-adding a field that ZDL doesn't own will be
   lost or will drift.
3. **Know what is safe to edit.** ZenWave marks files as *generated once*
   (developer-owned, e.g. `*ServiceImpl`, `*ServiceMapper`, `*EventsListenerMapper`,
   listeners, tests) or *regenerated* (e.g. DTOs, domain events, `*Transitions`). Only edit generated-once files. If a regenerated file is
   wrong, the fix belongs in ZDL or in a generator template.

## Implementation patterns

### Command on an existing aggregate (`@transition(from: ...)`)

```kotlin
override fun confirmOrder(input: ConfirmOrderInput): Order {
    log.debug("Request confirmOrder: {}", input)
    val order = orderRepository.findByOrderId(input.orderId)
        ?: throw NoSuchElementException("Order not found: ${input.orderId}")
    if (order.status == OrderStatus.CONFIRMED) return order          // idempotent redelivery
    OrderTransitions.ensureCanConfirmOrder(order)                    // generated guard
    inventoryService.confirmStockReservation(/* @calls */)
    order.status = OrderStatus.CONFIRMED
    order.confirmedAt = Instant.now(clock)
    val saved = orderRepository.save(order)
    eventPublisher.onOrderConfirmed(eventsMapper.asOrderConfirmed(saved))
    return saved
}
```

Every event-driven command needs all of these: **load by business key → idempotency
short-circuit → guard → cross-context call → mutate status/timestamps/counters →
save → emit exactly one event**.

### Command that creates an aggregate (`@transition(to: X)`)

Generate the business id (`orderId`, `paymentId`…), set the initial status and
timestamps, save, then emit. Keep the generated `mapper.update(Entity(), input)`
line for the input fields.

### Alternative outcomes (`withEvents [A | B]`, ZFL `@outcome`)

Replace the generated "emit all" lines with one branch per outcome, decided by a
real result (a port call, an availability check, an attempt counter). Each outcome
sets its own status, timestamp and reason. Never emit two alternatives.

When a called command has several ZFL responses, it returns a `<Command>Result`
wrapper (`outcome` enum plus one nullable field per response). The callee sets
`outcome` and exactly one field. The caller branches on it:

```kotlin
val result = inventoryService.reserveStock(reserveStockInput)
when (result.outcome) {
    ReserveStockOutcome.RESERVED -> { /* use result.reserved!!, emit OrderCreated */ }
    ReserveStockOutcome.UNAVAILABLE -> { /* use result.unavailable!!, emit StockUnavailable */ }
}
```

### Synchronous cross-context call (ZDL `@calls`, ZFL `call`)

- **Modulith:** inject the other module's *service interface* (not its repository
  or impl). Make sure the target module exposes it (Spring Modulith named interface
  or top-level package). Run the architecture test.
- **Microservice:** go through a client port (generated OpenAPI/AsyncAPI client or
  a hand-written adapter) behind an interface in the calling service.
- Map the call result into the branch decision. Don't discard it.

### External integrations (payment provider, carrier, e-mail…)

Define a port interface in the service layer, add a deterministic stub adapter
(`@Profile("!prod")` or the default bean), and inject it into the service and the
in-memory test config. Real adapters are a separate task.

### Listener wiring

- **Microservices:** implement the generated-once `*ConsumerService` adapter method.
  Replace the `TODO CUSTOM_REQUIRED` / `UnsupportedOperationException` body with
  the mapping (`EventsMapper`) and the call to the service command. Check that the
  channel has a Spring Cloud Stream binding (topic and consumer group) in
  `application*.yml`, and handle poison messages (DLQ/retry settings). Outgoing
  events go through the AsyncAPI-generated producer, so never publish to Kafka by hand.
- **Modulith:** if the listener for a ZFL edge is missing (common for
  **same-module** events), the fix is a local `@listener(event: ...)` in the ZDL
  plus regeneration. Only as a stop-gap, add an `@ApplicationModuleListener`
  method to the generated-once listener class.
- Timers (`@time`, `@timer`, `@actor(Scheduler)`): implement with `@Scheduled`
  polling on a persisted deadline (e.g. `expiresAt`) unless the project overlay
  says otherwise. Use an injected `Clock`.

### MapStruct (Kotlin + kapt)

Mappers are plain MapStruct interfaces used through a static `INSTANCE` (no Spring DI,
no contract/implementation split): the listener `*EventsListenerMapper`, the
service-level `EventsMapper` and `*ServiceMapper`. Add annotations directly on them.

```kotlin
@Mapper(uses = [BaseMapper::class])
interface PaymentsProcessingEventsListenerMapper {
    companion object {
        val INSTANCE: PaymentsProcessingEventsListenerMapper =
            Mappers.getMapper(PaymentsProcessingEventsListenerMapper::class.java)
    }

    @Mapping(target = "reason", constant = "PAYMENT_DECLINED")
    fun asReleaseStockInput(event: PaymentDeclined): ReleaseStockInput
}

// in the listener / service
private val mapper: PaymentsProcessingEventsListenerMapper = PaymentsProcessingEventsListenerMapper.INSTANCE
```

- `constant = "ENUM_VALUE"` when the target reason is fixed by the source event
  type. Never let MapStruct `Enum.valueOf` free text.
- `source = "a.b"`, `expression = "java(...)"` or a `default`/Kotlin helper for
  renames and type changes (`Long id → String productId`).
- `@Mapping(target = "copy", ignore = true)` silences the Kotlin data-class
  `copy` warning.
- For event mappers that need data that isn't on the entity, add an overload that
  takes the extra source (`asStockUnavailable(result: StockUnavailableResult)`),
  and call that one from the service.
- **Done means:** a clean compile shows zero `Unmapped target propert` warnings
  for the mappers you touched, or each remaining one has an explicit
  `ignore = true` with a reason.

### Repositories

Add natural-key finders (`fun findByOrderId(orderId: String): Order?`) to the
repository interface **and** to the in-memory test repository
(`src/test/.../repository/jpa/inmemory/*RepositoryInMemory.kt`).

### Web layer

- Map domain exceptions in the exception translator: not found → 404,
  `InvalidStateTransitionException` → 409, business rejection → 409/422,
  validation → 400 (already generated).
- Controllers: keep the generated body. Add `@Valid` handling and status codes
  that match the OpenAPI.

## Tests

For every command, in the generated `*ServiceTest` (in-memory, fast):

1. happy path: state, timestamps, saved entity, **exactly one** expected event in
   `InMemoryEventPublisher`;
2. each alternative outcome;
3. invalid transition → `InvalidStateTransitionException`;
4. not found;
5. redelivery of the same input → no state change and no second event.

Fixtures: add JSON fixtures under `src/test/resources/data/<persistence>/<Entity>/`
so each precondition state exists, with ids that chain consistently across contexts.
Keep `data.sql` in sync for integration tests. Update `ServicesInMemoryConfig` with
the stubs for new dependencies.

Per flow: one test per ZFL `end` outcome. In a modulith, use a Spring Modulith
`Scenario` in one JVM. In microservices, test this service's part (consume the
triggering message, assert the produced message) with an embedded or
Testcontainers Kafka, and leave the cross-service run to an end-to-end
environment.

Fix generated assertions that contradict the model (e.g. asserting that a
timestamp is not empty when that state hasn't been reached).

## Finish each finding

- Build with the project's JDK, run the tests, and run the architecture verification test (Spring Modulith `verify()` in a modulith, the ArchUnit/JMolecules test otherwise).
- Mark the finding done in the report or in `tasks.md` (`[X]`), with a short note on
  what changed.
- If the work surfaced a new rule or a model issue, add it as a new Q-/M- entry
  instead of deciding it silently.
