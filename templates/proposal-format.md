# Model gap proposals: `docs/proposals/P-<nn>.md`

A model gap is behavior the flow needs that the approved models (ZFL, ZDL, API contracts) or the approved test data
cannot express: a missing field, event, command, state, listener, call or correlation, or two model lines that
contradict each other. Agents never fix it by editing a model, a contract or the test data, and never work around
it in code. They write a proposal, and a person decides.

Any skill or agent that finds one writes it the same way: during the HITL loop (model review, building the board)
or during the AFK loop (an implementer that cannot finish its task). Ids are unique in the repository and never
reused.

```markdown
# P-01 confirmStockReservation cannot confirm an order with several lines

status: open
found by: T-08, implementer (claude sonnet), 2026-11-06
flow: place-order-flow
blocks: T-08, T-09

## Problem
[catalog-inventory-domain-model.zdl:27](../../models/catalog-inventory-domain-model.zdl#L27) keeps one
StockReservation per order line, but confirmStockReservation(id)
([catalog-inventory-domain-model.zdl:121](../../models/catalog-inventory-domain-model.zdl#L121)) takes the id of one
reservation. confirmOrder ([place-order-flow.zfl:132](../../business-flows/place-order-flow.zfl#L132)) has an
orderId, not reservation ids.

## Evidence
data/jpa/Order/2.json has 3 lines; the test confirmOrder_confirmsEveryReservation cannot be written against
the current command signature.

## Options
- A: confirmStockReservation(orderId) confirms every reservation of the order.
  Changes: the ZDL command input; the generated InventoryService; fixtures unchanged.
- B: one StockReservation per order, with its lines inside.
  Changes: the StockReservation aggregate, data.sql and the StockReservation fixtures.

Recommendation: A, it keeps the reservation per line that releaseStock already relies on.

## Decision
<!-- written by the person: the option, the date, and what changed (commits, new baseline) -->
```

| Field | Meaning |
|---|---|
| `status:` | `open` until a person decides; then `accepted A`, `accepted B`, `rejected` (with why), or `superseded by P-<nn>` |
| `found by:` | the task id (or the skill) that found it, the agent and model, the date |
| `blocks:` | the task ids that cannot go on until it is decided; the orchestrator marks them `[!]` with `blocked: P-<nn>` |
| Problem | the model lines that cannot express the behavior, each one a link to its line (see below) |
| Evidence | the test, fixture or input that shows it |
| Options | at least one, each with what it changes in models, generated code and test data |

**Every model line is a link**, so the person reviewing the proposal lands on it with one click, in the IDE and on
GitHub: the text is `file:line`, the target is the path relative to the proposal file, with `#L<line>`.
`[bookings-domain-model.zdl:377](../../architecture/models/bookings-domain-model.zdl#L377)`. Use the paths of the
overlay; a model in another repository is linked by its path in the working copy (`../../../<repo>/...`). Line
numbers move when a model changes: whoever edits a model or regenerates checks the open proposals' links.

Resolving a proposal is HITL work: the person decides, the models change, the code is regenerated, the test data
and the board are updated, and a new baseline is tagged. Then the blocked tasks are released.
