---
name: zenwave-implement-task
description: Implement one task of the board (docs/tasks.md) in a ZenWave project - read the task, its model lines, ADRs and test data, write the failing focused test first from the approved fixture and the ZFL outcome, then the code in the generated-once files, run only the focused tests, and report. Stops with a model gap proposal when the approved models cannot express the task. Use in the AFK loop, by an implementer agent given a task id, or when the person asks to implement a task by hand.
---

# Implement a task

One task, in the working tree you were given, with a fresh context. The orchestrator commits: leave your
changes in the working tree.

## Never

- Edit `*.zfl`, `*.zdl`, API contracts (`openapi*.yml`, `asyncapi*.yml`) or the approved test data
  (`src/test/resources/data*`). They are the baseline the person approved. Tests may build inputs inline; the
  fixtures they load are read-only.
- Edit regenerated files (DTOs, events, `*Transitions`, anything under `target/`): the fix belongs in the model.
- Work around a model gap in code, invent a business rule, or weaken or delete a test to pass.
- Commit, push, or touch anything outside the working tree.

## 1. Read

1. The task line and its fields in `docs/tasks.md`, and its slice's `path:`.
2. `AGENTS.md` and the project overlay (`docs/zenwave-sdd-overlay.md`): commands, JDK, shape, conventions.
3. Every `model:` line, with enough of the file around it to understand it; the `adr:` records; `GLOSSARY.md` for
   the names.
4. The `test data:` fixtures.
5. The code the task changes, and the code next to it that already does something similar.
6. [generated-code.md](references/generated-code.md) for what ZenWave generated and who owns each file, and
   [patterns.md](references/patterns.md) for how the pieces are filled.

## 2. Test first

Write the focused test for the behavior of the task before the code: start from the fixture of `test data:`, run the
command of the task, assert the outcome the ZFL names (state, timestamps, exactly one event). Then the other cases
the task covers (other outcomes, invalid transition, not found, redelivery).

Run it and see it fail for the right reason: the behavior is missing, not the test broken. If it passes before any
code change, the task was already done or the test asserts nothing: say so in the report.

## 3. Code

Fill the generated-once files following [patterns.md](references/patterns.md) and the code around them. Do what the
model lines say and nothing beyond: no extra endpoints, fields or refactors.

While working, run only the focused tests (`tests:` of the task) and the compile. Never the whole unit suite, never
the integration tests: the slice review runs those.

## 4. Model gap

If the task cannot be done with the approved models, contracts and test data (a field with no source, a command that
takes the wrong id, a listener the ZDL doesn't declare, a fixture that cannot represent the precondition), stop and
follow `zenwave-model-gap`: write the proposal, and report the task as blocked. Leave in the tree only the changes
that stand on their own; revert your own unfinished ones.

## 5. Finish

The focused tests pass, the compile shows no new `Unmapped target propert` warning in the mappers you touched. Then
report, in your final message, and to the report path if you were given one:

```
STATUS: complete | blocked P-<nn> | failed
TASK: T-<nn>
FILES: changed and new
RED: the test that failed first, and why
GREEN: the focused test command and its result
MODEL: per model line, done or not
CHOICES: where the model was silent and you chose (each one a candidate question for the person)
NOT CHECKED: what you could not run
```

`failed` means something outside the task stopped you (the build, the environment): say what, with the output.
