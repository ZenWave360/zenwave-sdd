---
name: zenwave-test-scenarios
description: Generate the scenario test data of a ZenWave-generated Spring Boot + JPA backend - src/test/resources/data.sql and data/jpa/<Entity>/<n>.json with a fixture for every state a command starts from, every alternative and failure branch of the ZFL flows, every flow outcome and every status a client reads - as consistent cross-context chains, with a coverage matrix and the assumptions written down. Builds on zenwave-test-data (same DDL export, file formats and validation). Use in the HITL loop of a flow, after the models are challenged and before the task board, or when the fixtures hold only one example per entity.
---

# ZenWave Test Scenarios

[zenwave-test-data](../zenwave-test-data/SKILL.md) writes the basic data set: one
consistent example per entity. This skill writes the **scenario** data set: one
fixture for each case a test needs. That covers the states commands start from,
the branches the flow can take, the ways it can fail, and the outcomes clients
observe.

It costs more than the basic skill: it reads every flow and model, writes several
times more rows, and has to keep them consistent. Use it in the HITL loop of a flow,
once the models are challenged (`zenwave-grill-models`) and before the task board:
the board's tasks point at its chains, and the AFK loop writes its tests from them.

It changes **test resources only**. It never adds states, fields or columns, and
never edits `*.zfl` or `*.zdl`. If a case can't be expressed with the current model,
it's a model gap: write a proposal (`docs/proposals/P-<nn>.md`, see
`zenwave-model-gap`), skip the row, and report it so a human can decide.

**The person approves the result.** The scenario and coverage matrices are what they
review: test data is part of the gate between the loops. Once the baseline is tagged,
the AFK loop never edits these files; changing them is HITL work, with this skill.

## Authorization

An explicit invocation of `$zenwave-test-scenarios` authorizes the same workflow as
[zenwave-test-data](../zenwave-test-data/SKILL.md#authorization): exporting the DDL
against the **test** database, rewriting `src/test/resources/data.sql` and
`src/test/resources/data/jpa/**`, and running the repository and service test
suites, and adding or updating the one overlay row that points at the test data (step 6). Ask before anything
outside that.

## Inputs

The three inputs of zenwave-test-data, with the same authority (DDL for tables,
columns, sequences and constraints; entity classes for JSON property names; ZDL +
ZFL for states and chains), plus:

| Input | Used for |
|---|---|
| **Open proposals** (`docs/proposals/`) | states or cases the model can't express yet: no row, and the fixtures must not answer them silently |
| **Current `data.sql` and fixtures** | chains, ids and business keys to keep |
| **Test sources** (`src/test/**`) | business ids existing tests already reference |
| **API contracts** (OpenAPI, AsyncAPI) | the read side: which statuses a client can query |

## 1. Get the DDL

Run [`../zenwave-test-data/scripts/export-ddl.sh`](../zenwave-test-data/scripts/export-ddl.sh)
and apply the same checks as
[zenwave-test-data §1](../zenwave-test-data/SKILL.md#1-get-the-ddl).

## 2. Build the coverage matrix (before any row)

List every **need**: a data condition some test requires. Write it as a table:

`need | aggregate | state or data condition | source (ZDL/ZFL line) | used by`

Collect needs from every source below. Each one is required, not a suggestion.

1. **Lifecycle preconditions.** Every state in every `@transition(from: ...)` of
   every command, in every ZDL, including commands no flow uses (backoffice, catalog).
   If a `from:` state is the target of no `@transition` (the lifecycle can't reach
   it), still add the need, and mark it with the model gap.
2. **Branch preconditions.** Every alternative in the ZFL (`on <Result> emits`,
   `@outcome(...)`, several `emits` after one `when`) and in ZDL (`withEvents [A | B]`).
   For each branch, add the data that makes it happen: a stock position with less
   available than requested, a payment whose `attemptCount` is at the retry limit, a
   record past its deadline. If an external system decides the branch (a provider
   declines a card), no row can force it: mark it **stub-driven** and add no row.
3. **Flow outcomes.** One finished chain per ZFL `end` outcome, and one per distinct
   cause that leads into a shared compensation. For example, an order cancelled
   because the payment was declined, retries ran out, the authorization was voided,
   or the reservation expired: four chains. Flow tests and API reads need a finished
   example of each.
4. **Multiplicity.** When the model states a one-to-many relationship by business key
   ("one reservation per order line", an array with `minlength(1)`), add at least one
   parent with several children.
5. **Time.** For every timer step (`@time`, `@timer`, `expiresAt`-style deadlines),
   add one record past the deadline and one before it, relative to a fixed test
   "now" written in the header. Tests must use a fixed `Clock`.
6. **Redelivery.** For every listener command that creates or moves a record, add a
   record already in the resulting state, so an idempotency test can redeliver the
   event (e.g. a payment that already exists for an `OrderCreated`).
7. **Read side.** For every query endpoint or status a client renders (API, frontend,
   backoffice screens), add at least one record in each status the client must
   display.
8. **Gap report.** Every item its test-fixture finding lists, if a report exists.

Then run the **coverage check**: every need has a row, or a stated reason for having
none (`stub-driven`, `blocked by M-xx`, `not expressible in the model`). Don't write
any rows until it passes.

## 3. Assign the needs to chains

- Group the needs into **chains** keyed by business ids (`ORD-001`, `SKU-001`,
  `CUST-001`…), following the ZFL. Each chain stops at one point of the flow, and
  every aggregate in it is in a state reachable at that point.
- Prefer one chain per need. Let one chain serve several needs only when their
  states agree.
- **Off-chain rows** (a record in one context with no parent in another, e.g. a
  payment without an order) are allowed only when the command under test never
  reads the other context. Mark them in the matrix.
- **Derived values must agree with their rows.** Counters equal the sum of their
  child rows (e.g. `available + reserved + sold` = the stock received, and
  `reserved` = the sum of `RESERVED` quantities). Totals equal the sum of their
  lines. If the counting rule is an open question, pick one and record it as an
  assumption.
- **Values that need a business rule the models don't give** (reason codes, retry
  limits, the result of a decision): use plausible values and record each one as an
  assumption, linked to its open question when one exists. Never present them as
  rules.
- Use realistic, fake data: `example.com` e-mails, test payment-method ids,
  fictional names and addresses. No real personal data.
- When refreshing, keep the existing chains and ids and append new chains after them.
  Tests reference them.

## 4. Write `data.sql` and the JSON fixtures

Follow [zenwave-test-data §3 and §4](../zenwave-test-data/SKILL.md#3-write-datasql)
exactly: ids computed from the sequence increment, DDL column names, entity property
names in JSON and `jsonb`, enum `check` values, fixed timestamps, and identical
values in SQL and JSON.

The `data.sql` header holds:

1. purpose, "regenerate with zenwave-test-scenarios", the DDL date, and the fixed
   test "now";
2. the **scenario matrix**: `chain | business ids | state per aggregate | used by`;
3. the **coverage matrix** from step 2, compacted to `need → chain/row` (or the
   reason for no row);
4. the **assumptions**: `assumption | value used | open question`.

Give every chain a short id (`C-01`, `C-02`…): the board's `test data:` fields point
at chains, and implementers start their tests from them.

If the project has a frontend or API mocks, the scenario matrix is the shared
catalogue of cases: reuse its chain ids in the mock data, so backend and frontend
tests talk about the same scenarios. This skill doesn't write frontend files.

## 5. Validate

Run [zenwave-test-data §5](../zenwave-test-data/SKILL.md#5-validate): repository
tests pass, service tests load the fixtures, and SQL and JSON agree. Then:

- Walk the coverage matrix: every need points to an existing row id, or has a reason.
- Recompute every derived value (counters, totals) from the rows.
- Check every chain against the lifecycles: no aggregate is in a state unreachable at
  the chain's point of the flow, unless a need asks for that on purpose and the
  matrix says so.

Then record it in the overlay (step 6). Report back with three short lists: needs covered (count per source), needs without a
row and why, and the assumptions made.

## 6. Record it in the overlay

Make `docs/zenwave-sdd-overlay.md` point at what this skill wrote, so the orchestrator and the workers find it without
being told. In its "Where things are" table, add or update **one row**, "Test data and scenario matrix", naming what
the `data.sql` header holds:

```markdown
| Test data and scenario matrix | `src/test/resources/data.sql` (header: scenario and coverage matrices, chains `C-01`..`C-<nn>`, assumptions, the fixed test "now" `<timestamp>` read by tests through a fixed `Clock`) and `src/test/resources/data/jpa/<Entity>/<n>.json` |
```

- The chain ids, and the fixed test "now" with how tests read it (a `Clock`), are the facts to name. Keep them in
  `data.sql` and only point at them: the overlay never repeats the matrix.
- Replace the `<after test data: ...>` placeholder if it is still there, and the row `zenwave-test-data` wrote.
- This skill does not write the `Clock`. If the project has no injected `Clock`, say so in the report: a board task
  must add it, because the tests depend on the fixed "now".
- Touch nothing else in the overlay. If the project has no overlay, say so in the report and skip this step.

## Anti-patterns

- One chain with every aggregate in a terminal state. That's the basic set; it gives
  most commands nothing to start from.
- Adding enum values, columns or relationships the model doesn't have, to make a case
  fit. That's a model gap.
- Silent business rules: a retry limit, a counter rule or a reason code used without
  being listed as an assumption.
- Contradictory chains made by copying a row and changing only its status (e.g. a
  `CONFIRMED` reservation under a `CREATED` order whose payment was never authorized).
