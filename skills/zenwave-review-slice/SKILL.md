---
name: zenwave-review-slice
description: Review one vertical slice of the board (docs/tasks.md) of a ZenWave project from a fresh context - run the full suite, integration tests with containers included, once; check the diff against the ZFL/ZDL lines of its tasks (model axis) and against the repository's conventions (standards axis), reported apart; confirm the approved models, contracts and test data are untouched. Read-only except its report. Use in the AFK loop when every task of a slice is done, and to verify a fix round.
---

# Review a slice

You did not write this code and were not told why it was written this way: judge the diff and the behavior against
the models. Use a different model from the implementers of the slice.

You change nothing: no edits, commits, branch switches or stashes. You write only your report, at the path you were
given.

## 1. Read

- The slice in `docs/tasks.md`: its `path:`, its tasks and their `model:`, `test data:` and `adr:` fields.
- The range to review: from the commit before the slice's first task to `HEAD` (you are given it, or take it from the
  `done:` fields). `git diff <base>..HEAD`, then the code around it.
- The model lines, the ADRs, `GLOSSARY.md`.
- The standards, which you are given in your prompt (pushed): `AGENTS.md`, the overlay's project rules, and the
  conventions of the code next to the change.

## 2. The baseline is untouched

```bash
git diff --stat <base>..HEAD -- '*.zfl' '*.zdl' '*openapi*.yml' '*asyncapi*.yml' 'src/test/resources/data*'
```

Anything listed is a FIX FIRST finding on its own: the AFK loop never edits the approved baseline.

## 3. Run the full suite, once

The overlay's full test command: unit tests and integration tests with Testcontainers loaded from `data.sql`. Record
the command and the result. A failure is a finding, with the test name and the first lines of the cause. A test that
fails, then passes when rerun once, is reported as flaky, never hidden.

## 4. Two axes, reported apart

**Model axis**: does the slice do what its model lines say, end to end along its `path:`?

- every command of the path: load, guard, mutate, persist, exactly one event per outcome, calls whose results drive
  the branch, idempotent redelivery;
- the events reach their listeners and the listeners call the right command with the right mapping;
- the flow test for the slice's `end` outcome exists and proves it;
- nothing out of scope: no field, endpoint, event or behavior the models don't declare;
- tests that prove nothing: assertions recomputed the way the code computes them, mocks of the thing under test.

**Standards axis**: does it read like the code around it, and follow the conventions you were given? Only what a
convention, the surrounding code or a clear smell (duplication, a misleading name, a feature in the wrong module)
supports. No personal preferences.

Do not merge or rerank the two axes: a slice can pass one and fail the other.

A finding is confirmed by reading or running the code; otherwise mark it `UNCONFIRMED` and say what would settle it.
A finding that the models themselves are wrong is not a code finding: follow `zenwave-model-gap`.

## 5. Report

```
VERDICT: PASS | FIX
SLICE: S<n>   RANGE: <base>..<head>
SUITE: <command> → <passed / failed, counts, flaky>
BASELINE: untouched | <files changed>

MODEL AXIS
- FIX FIRST | SHOULD FIX | NOTE  T-<nn> file:line  what goes wrong, with what input, which model line
...
STANDARDS AXIS
- FIX FIRST | SHOULD FIX | NOTE  file:line  what, and which convention
...
PROPOSALS: P-<nn> written, if any
NOT CHECKED: what needs a person or could not be run
```

PASS only with no FIX FIRST, a green suite and an untouched baseline.

## Verifying a fix round

Given your previous report: mark each earlier finding *resolved*, *partial* or *not resolved*, with file:line; then
only new findings. Run the suite again.
