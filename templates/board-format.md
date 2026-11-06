# The task board: `docs/tasks.md`

One board per business flow, in the implementation repository. It is the plan of the AFK loop and its state.
The `zenwave-tasks-*` skills write it in the HITL loop, the person approves it at the gate, and from then on only
the orchestrator changes it. The person asks the orchestrator for changes (new tasks from QA, another priority); they
don't edit the board while it runs. When the flow is done it is archived as `docs/tasks/<flow>-<baseline>.md` and
`docs/tasks.md` is removed.

People, agents and `bin/check-board.sh` all read it, so the format is strict: one task per line, fields indented below
it.

## Shape

```markdown
# PlaceOrderFlow: tasks

flow: ../arcadia-editions-architecture/business-flows/place-order-flow.zfl
baseline: baseline/place-order-flow-1
branch: afk/place-order-flow

## S0 Baseline
review: [ ]

- [ ] T-01 mechanical AFK The project compiles and the test data loads
      tests: ./mvnw -q test -Dtest='*RepositoryIntegrationTest'

## S1 completed (tracer bullet)
path: StartOrderCheckout > startOrderCheckout > reserveStock > OrderCreated > authorizePayment[authorized]
      > confirmOrder > confirmStockReservation > scheduleFulfillment[FulfillmentScheduled]
      > capturePayment[PaymentCaptured] > sendOrderConfirmation > end completed
review: [ ]

- [ ] T-02 bounded AFK startOrderCheckout: reserve the stock, create the order, emit OrderCreated
      model: place-order-flow.zfl:84-89, orders-checkout-domain-model.zdl:112-118
      test data: data/jpa/Order/1.json, data/jpa/StockReservation/1.json
      tests: OrdersCheckoutServiceTest
      blocked by: T-01
```

## Header

| Line | Meaning |
|---|---|
| `# <Flow>: tasks` | the ZFL flow name |
| `flow:` | path of the ZFL file, relative to the repository root |
| `baseline:` | the git tag the person put on the approved models, test data and board (empty until the gate) |
| `branch:` | the branch the orchestrator integrates into, `afk/<flow>` |

## Slices

`## S<n> <name>` opens a vertical slice: one path through the flow, from a `start` to an `end` outcome, through
every layer it crosses (command, events, listeners, mappers, persistence, API, tests).

- **S0 Baseline**: what must hold before any behavior: the project compiles, the test data loads, the generated
  tests that should pass do. Only when there is something to do.
- **S1** is the **tracer bullet**: the happy path, to the `end` outcome that means success. It goes through every
  bounded context of the flow with the least behavior that works, so the whole path is tested early.
- The next slices are the other `end` outcomes and the alternative and failure branches (`@outcome`, `@failure`,
  `@compensates`, `@time`), in the order a person would demo them.
- A policy shared by several paths belongs to the first slice that needs it; later slices depend on it.
- Last, if needed, a polish slice: error mapping, API details, queries outside the flow.

Lines under the heading:

| Line | Meaning |
|---|---|
| `path:` | the path in ZFL names: commands, `Event`, `command[outcome]`, `end <outcome>`. Continuation lines are indented |
| `review:` | the slice review: `[ ]` not run, `[/]` running, `[x]` passed, `[!]` failed (see the report). A slice is done when all its tasks are `[x]` and its review is `[x]` |

## Tasks

```
- [<state>] T-<nn> <difficulty> <type> <title>
```

| Part | Values |
|---|---|
| state | `[ ]` pending, `[/]` in progress, `[\]` in review, `[x]` done, `[!]` blocked |
| id | `T-01`, `T-02`… unique in the board, never reused |
| difficulty | `mechanical`: follows a pattern already in the code, no decision. `bounded`: fully described by the model lines and the test data. `advanced`: puts together several models, contexts, ADRs or an external API |
| type | `AFK`: an agent can do it. `HITL`: needs a person (a decision, a credential, a visual check). The loop never picks a HITL task |
| title | one line: the command or behavior, and what it must do |

Fields, indented six spaces, in this order, each optional unless stated:

| Field | Meaning |
|---|---|
| `model:` | **required for behavior.** `file:line` or `file:from-to` of the ZFL and ZDL lines the task implements, comma separated |
| `test data:` | the fixtures the task's tests start from (paths under `src/test/resources/`) |
| `tests:` | the focused tests that prove the task: test classes or a command. The implementer runs only these |
| `adr:` | ADRs that apply |
| `blocked by:` | task ids that must be `[x]` first. The board is a DAG: no cycles, and no task depends on a later slice |
| `blocked:` | why a `[!]` task is blocked: `P-<nn>` (a model gap proposal in `docs/proposals/`) or one line for a person |
| `fixes:` | on a task added after a slice review: the review report it fixes, e.g. `.zenwave/handoff/<flow>/reports/S1-1.md` |
| `done:` | written by the orchestrator: the agent and model that did it, e.g. `codex gpt-6.1-sol`. The commit is `git log --grep "T-<nn> "` |

## Review fixes

When a slice review says FIX, the orchestrator adds one task per accepted finding (or one per file group) at the end
of the slice, with `fixes:` pointing at the report, preferably for the same agent that implemented the original
task, and sets `review: [ ]` again. When they are done, the next review of the slice verifies the earlier report.
A third review of the same slice means the design is wrong: it becomes a HITL task for the person.

## Sizing

- A task fits a fresh context in the smart zone: the agent reads the task, the model lines, the test data and the
  code around the change, writes the test first, then the code, and runs its focused tests. If that needs more than
  one bounded context or more than a handful of files, split it.
- A slice is reviewed as one: the full suite, integration tests with containers included, runs once per slice.

## Ready tasks

A task is ready when it is `[ ]`, its type is `AFK`, every id in `blocked by:` is `[x]`, and every task of the
previous slices it depends on is done. Ready tasks of different bounded contexts can run in parallel, each in its
own worktree.
