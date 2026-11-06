---
name: zenwave-tasks-from-code-and-models
description: Build the task board (docs/tasks.md) of one business flow from the project's existing code and its models - the ZFL flow, the ZDL models, the API contracts and the test data, wherever they live - as vertical slices along the flow's paths, the tracer bullet first, each task pointing at its model lines, test data and focused tests, only for the behavior the code still lacks. Also checks a finished flow for anything still missing. Use in the HITL loop when code exists (generated with ZenWave SDK or not), when asked to plan or slice a flow, or at the end of the AFK loop to confirm nothing is left. With no code at all use zenwave-tasks-from-models.
---

# Tasks from code and models

The project already has code: generated with ZenWave SDK (entities, services, events, listeners, mappers, controllers,
test skeletons), written by hand, or both. The tasks are the behavior the code lacks for this flow, and nothing else.
Never plan classes, interfaces or contracts that already exist.

Two modes:

- **plan** (default): write `docs/tasks.md` for one flow.
- **check**: at the end of the AFK loop, list what the flow still misses. An empty list means done.

## Rules

- The models are the spec: ZFL says when and why, ZDL says what. Every task points at the model lines it implements.
- Never edit `*.zfl`, `*.zdl`, API contracts or test data, and never invent a business rule. When the models cannot
  express what the flow needs, write a proposal ([proposal-format.md](references/proposal-format.md)) and block the
  tasks that depend on it.
- Read-only for code: this skill writes `docs/tasks.md` and `docs/proposals/`, nothing else.

## 1. Inputs

The person names the flow **and tells you where everything is**; what they do not say comes from the project overlay
(`docs/zenwave-sdd-overlay.md`, referenced from `AGENTS.md`). Needed, all of them:

| Input | What |
|---|---|
| the flow | its name, and the ZFL file that holds it |
| the ZDL models | the ZDL of every bounded context the flow names (`@zdl(...)` in its `systems` block shows them) |
| the API contracts | the OpenAPI and AsyncAPI files of those contexts |
| the code | the source folders that implement them: one per module or per repository |
| the test data | `data.sql` and the JSON aggregates (`src/test/resources/data*`), and the scenario matrix if there is one |
| ADRs and glossary | `docs/adr/`, `GLOSSARY.md` |

An invocation can carry them, in any form the person likes:

```text
/zenwave-tasks-from-code-and-models place-order-flow
    zfl: ../arcadia-editions-architecture/business-flows/place-order-flow.zfl
    zdl: ../arcadia-editions-modulith-api/*-domain-model.zdl
    apis: ../arcadia-editions-modulith-api/*-openapi.yml
    code: src/main/kotlin
    test data: src/test/resources
```

What is not given and not in the overlay, look for in the conventional places; what you still cannot find, ask. Do
not guess a location, and do not plan from a subset of the inputs: say which ones are missing and stop.

If the overlay gives both a working copy and a packaged copy of the ZDLs, run its staleness check. Generated code
reflects the packaged copy: a difference means "regenerate first", not tasks.

## 2. The models hold

Lint every ZDL the flow uses:

```bash
bash .zenwave/bin/lint-zdl.sh --strict <zdl files>
```

Lint errors, and `zdl.data-lineage` warnings, are model gaps. Exit code 2 is a tooling problem: report it and stop.

Check the identities between ZFL and ZDL: each `@zdl(...)` path resolves, each command and event named in the flow
exists in its ZDL, each `@compensates(x)` names a command. A mismatch is a model gap.

## 3. The paths of the flow

List the paths of the flow: from a `start` to an `end` outcome, following `when <Event> do <command>`, `call`,
`response`, `on <Result> emits`, `@outcome`, `@failure`, `@compensates` and `@time`. Write each path as in the
board: `Start > command > Event > command[outcome] > ... > end outcome`.

- The path to the success outcome is **S1, the tracer bullet**.
- Every other `end` outcome is a slice. When several branches reach the same outcome (declined, retries exhausted,
  fulfillment failed, timer expired all end in `orderCancelled`), each branch is its own slice, in the order a
  person would demo them.
- A loop (a retry that feeds back into a command) is its own slice, after the path it retries.
- Show the list of paths to the person before going on, and let them reorder or merge.

## 4. What is missing on each path

For each command on each path, resolve it to its ZDL lines (service method, input, `withEvents`, `@transition`,
`@listener` / `@asyncapi`, `@calls`) and to its code (the service method, the listener, the mappers, the controller,
the tests). Then check the code against what the model says: load, guard, mutate, persist, branch, call, side effects,
idempotency, external integrations, listener wiring, mapper gaps, web layer, tests and test data.

For code generated with ZenWave SDK, [generated-code.md](references/generated-code.md) tells you which files are
generated and which are the developer's, and how an unimplemented method looks (the `TODO` bodies, the "emit every
alternative" shape). For code written by hand, look for each model element in the code directly: a command with no
method, a method that ignores a `@transition`, an event never emitted, a listener never wired.

Run the project checks from the overlay (clean compile, unmapped targets, `TODO` markers) and use their output as
evidence.

Whatever needs a field, event, command, state, listener or correlation the models don't have is a model gap: write
a proposal, don't plan code around it.

## 5. Tasks

Turn what is missing into tasks, following [board-format.md](references/board-format.md):

- **S0 Baseline**, only if needed: it compiles, the test data loads, mapper warnings that break runtime.
- Within a slice, one task per command (or per listener plus its command), in path order, sized to fit a fresh
  context: one bounded context, a handful of files. Split anything bigger.
- A command already done by an earlier slice is not repeated; the later task depends on it.
- `model:` the ZFL and ZDL lines, `test data:` the fixtures its tests start from: the chain ids of the scenario
  matrix in the `data.sql` header (`C-03`), or the JSON aggregates for the focused unit tests, `tests:` the focused tests that prove it.
  If a precondition, branch or outcome has no fixture, say so to the person: the test data is part of the gate.
- Difficulty: `mechanical` when the code next to it already shows the pattern; `bounded` when the model lines and
  the fixtures say everything; `advanced` when it combines contexts, ADRs, a scheduler or an external integration.
- `HITL` for what needs a person: a provider choice, a credential, a visual check.
- `blocked by:` every task it needs, so the board is a DAG. A task blocked by a proposal is `[!]` with
  `blocked: P-<nn>`.
- The last task of each slice is its flow test for that `end` outcome.

Write `docs/tasks.md`: header with `flow:`, empty `baseline:`, `branch: afk/<flow-file-name>`. If a board exists for
this flow, show the person what changes instead of overwriting their edits.

## 6. Hand over

Tell the person: the slices with their paths, the number of tasks per difficulty and type, the proposals opened, the
missing fixtures, and the first slice that can start. The board is for them to review: a horizontal slice ("all the
mappers", "all of payments") is the mistake to look for.

## Check mode

At the end of the AFK loop, for the flow on the board: steps 2 to 4 again against the code as it is now. Report
every gap still found, each with its model lines and the task that should have covered it. Write nothing. Nothing
found means the flow is done.
