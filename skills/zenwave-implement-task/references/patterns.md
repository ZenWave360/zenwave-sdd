# Implementation patterns for ZenWave-generated code

Kotlin examples; Java generates the same shapes. Only generated-once files are edited
([generated-code.md](generated-code.md)).

## Command on an existing aggregate (`@transition(from: ...)`)

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

The order is always: load by business key → idempotency short-circuit → guard → cross-context call → mutate
status, timestamps, counters → save → emit exactly one event.

## Command that creates an aggregate (`@transition(to: X)`)

Generate the business id (`orderId`, `paymentId`), set the initial status and timestamps, save, emit. Keep the
generated `mapper.update(Entity(), input)` line for the input fields.

## Alternative outcomes (`withEvents [A | B]`, ZFL `@outcome`)

Replace the generated "emit all" lines with one branch per outcome, decided by a real result (a call, an
availability check, an attempt counter). Each outcome sets its own status, timestamp and reason. Never emit two.

A called command with several ZFL `response`s returns a `<Command>Result` (an `outcome` plus one nullable field per
response). The callee sets `outcome` and exactly one field; the caller branches on it:

```kotlin
val result = inventoryService.reserveStock(reserveStockInput)
when (result.outcome) {
    ReserveStockOutcome.RESERVED -> { /* result.reserved!!, emit OrderCreated */ }
    ReserveStockOutcome.UNAVAILABLE -> { /* result.unavailable!!, emit StockUnavailable */ }
}
```

## Synchronous cross-context call (ZDL `@calls`, ZFL `call`)

- Modulith: inject the other module's service interface, never its repository or implementation. The target module
  must expose it (named interface or top-level package); the modulith verification test proves it.
- Microservices: a client port behind an interface in the calling service (generated OpenAPI client or an adapter).
- The call's result drives the branch. Don't discard it.

## External integrations (payment provider, carrier, e-mail)

A port interface in the service layer, a deterministic stub adapter (`@Profile("!prod")` or the default bean), wired
into the service and into `ServicesInMemoryConfig`. Real adapters are separate tasks.

## Listener wiring

- Microservices: implement the generated-once `*ConsumerService` method: map with `EventsMapper`, call the command.
  The channel needs its binding (topic, group, DLQ/retry) in `application*.yml`. Outgoing events go through the
  AsyncAPI-generated producer, never to Kafka by hand.
- Modulith: a missing listener for a ZFL edge (common for same-module events) is a model gap: a local
  `@listener(event: ...)` in the ZDL. Write a proposal; don't hand-add an `@ApplicationModuleListener`.
- Timers (`@time`, `@timer`, `@actor(Scheduler)`): `@Scheduled` polling on a persisted deadline (`expiresAt`), with an
  injected `Clock`, unless the overlay says otherwise.

## MapStruct (Kotlin + kapt)

Mappers are plain MapStruct interfaces used through a static `INSTANCE`:

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
```

- `constant = "ENUM_VALUE"` when the source event type fixes the value; never `Enum.valueOf` free text.
- `source = "a.b"`, `expression = "java(...)"` or a helper for renames and type changes.
- `@Mapping(target = "copy", ignore = true)` silences the Kotlin data-class `copy` warning.
- An event that needs data not on the entity gets an overload taking the extra source
  (`asStockUnavailable(result: StockUnavailableResult)`), called from the service.
- Done when a clean compile shows no `Unmapped target propert` warning for the mappers you touched, or each one has
  an explicit `ignore = true` with a reason.

## Repositories

A natural-key finder (`fun findByOrderId(orderId: String): Order?`) goes in the repository interface and in the
in-memory repository (`src/test/.../repository/jpa/inmemory/*RepositoryInMemory.kt`).

## Web layer

Exception translator: not found → 404, `InvalidStateTransitionException` → 409, business rejection → 409 or 422,
validation → 400. Controllers keep the generated body; status codes match the OpenAPI.

## Focused unit tests

In the generated `*ServiceTest` (in-memory repositories loaded from the JSON aggregates), for the command of the task:

1. the outcome of the task's branch: state, timestamps, saved entity, exactly one expected event in the
   `InMemoryEventPublisher`;
2. each other outcome the task covers;
3. invalid transition → `InvalidStateTransitionException`;
4. not found;
5. redelivery of the same input → no state change, no second event.

Generated assertions that contradict the model (a timestamp asserted for a state not reached) are fixed in the test.
A new dependency of a service (a call, a port) goes into `ServicesInMemoryConfig`.
