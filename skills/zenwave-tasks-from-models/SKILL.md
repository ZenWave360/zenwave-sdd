---
name: zenwave-tasks-from-models
description: Build the task board (docs/tasks.md) of one business flow straight from its ZFL and ZDL models, for a project with no generated code - an empty repository or a stack ZenWave SDK does not generate - as vertical slices along the flow's paths, the tracer bullet first, each task pointing at its model lines, test data and focused tests. Also checks a finished flow for anything still missing. Use in the HITL loop when the project was not generated with ZenWave SDK; for a generated one use zenwave-tasks-from-code-and-models.
---

# Tasks from the models

Nothing is generated: the tasks build the structure and the behavior together. The models are still the whole spec;
the stack, the layout and the conventions come from `AGENTS.md`, the overlay and the ADRs.

Two modes:

- **plan** (default): write `docs/tasks.md` for one flow.
- **check**: at the end of the AFK loop, list what the flow still misses. An empty list means done.

## Rules

- Every task points at the model lines it implements. The models are not edited here; a gap is a proposal
  ([proposal-format.md](references/proposal-format.md)) and the tasks that need it are blocked.
- Vertical slices, never layers. "All the entities", "the persistence layer", "the API" are not tasks. Each task
  crosses the layers it needs for one command, and a slice crosses the whole path.
- Read-only for code: this skill writes `docs/tasks.md` and `docs/proposals/`, nothing else.

## 1. Inputs

The person names the flow **and tells you where everything is**; what they do not say comes from the project overlay
(`docs/zenwave-sdd-overlay.md`, referenced from `AGENTS.md`). Needed:

| Input | What |
|---|---|
| the flow | its name, and the ZFL file that holds it |
| the ZDL models | the ZDL of every bounded context the flow names (`@zdl(...)` in its `systems` block shows them) |
| the API contracts | the OpenAPI and AsyncAPI files of those contexts, if they exist |
| the project | where the code will live (the repository or folders), the stack, the build and test commands: `AGENTS.md` and the overlay |
| the test data | `data.sql`, the JSON aggregates and the scenario matrix, if they exist yet |
| ADRs and glossary | `docs/adr/`, `GLOSSARY.md` |

An invocation can carry them, in any form the person likes:

```text
/zenwave-tasks-from-models place-order-flow
    zfl: architecture/business-flows/place-order-flow.zfl
    zdl: architecture/models/*-domain-model.zdl
    apis: architecture/apis/*.yml
    test data: src/test/resources
```

What is not given and not in the overlay, look for in the conventional places; what you still cannot find, ask. Do
not guess a location, and do not plan from a subset of the inputs: say which ones are missing and stop.

If the stack is not decided, the first questions are for the person: language, framework, persistence, how contexts
talk (in-process, broker), how tests run. Record the answers that qualify as ADRs.

Lint the ZDL first (`bash .zenwave/bin/lint-zdl.sh --strict <zdl files>`) and check the ZFL/ZDL identities, as in
`zenwave-grill-models`. Model problems are proposals, not tasks. If the folder you were given holds some code after
all, use `zenwave-tasks-from-code-and-models`.

## 2. The paths

As in [board-format.md](references/board-format.md): every path from a `start` to an `end` outcome. S1, the tracer
bullet, is the success path. Each other `end` outcome or branch is its own slice, in demo order. Show the paths to
the person before going on.

## 3. Tasks

- **S0 Baseline**, when the project is empty: the skeleton that builds and runs one test, the persistence and the
  in-process or broker setup the ADRs chose, and the test data loading in both test levels (focused unit tests and the
  integration suite). Keep it to what S1 needs; the rest arrives with the slices that use it.
- **S1**: the thinnest version of every element on the path that makes the success outcome happen end to end: the
  aggregate with only the fields and states the path uses, its persistence, the command, the event, the listener in the
  next context, the API that starts it, and the flow test. One task per command (with its listener), in path order.
- **Later slices** add what their path needs: new states and transitions, the branch in a command, the compensation,
  the timer, the extra fields. A task extends what an earlier slice built and depends on it.
- Each task fits a fresh context: one bounded context, a handful of files. `model:` the ZFL and ZDL lines, including
  the entity and field lines it introduces; `test data:` the fixtures or scenario chains its tests start from;
  `tests:` the focused tests that prove it.
- Difficulty: `mechanical` when a previous task shows the pattern (the second listener after the first); `bounded`
  when the model lines and fixtures say everything; `advanced` for the first of each kind, cross-context calls,
  schedulers, external integrations.
- `HITL` for decisions and checks only a person can make. `blocked by:` every task it needs: the board is a DAG.
- The last task of each slice is its flow test.

Write `docs/tasks.md` (header: `flow:`, empty `baseline:`, `branch: afk/<flow-file-name>`). If a board exists for the
flow, show the changes instead of overwriting.

## 4. Hand over

Tell the person the slices and their paths, the tasks per difficulty and type, the proposals opened, the decisions
taken about the stack, and what test data is missing. What to look for when they review it: a slice that is a layer,
a task too big for one context, a tracer bullet that skips a context.

## Check mode

At the end of the AFK loop: for each path of the flow, every command, event, listener, transition, compensation and
timer on it exists in the code and has a test, and each `end` outcome has its flow test. Report each gap with its
model lines and the task that should have covered it. Write nothing.
