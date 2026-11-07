---
name: zenwave-model-gap
description: Stop and write a model gap proposal (docs/proposals/P-xx.md) when a task or a review finds that the approved ZFL/ZDL models, API contracts or test data cannot express what the flow needs - with the model lines, the evidence and at least one option - instead of editing a model or working around it in code. Use in the AFK loop, by implementers and reviewers, and in the HITL loop when building the board.
---

# Model gap

The models are the spec the person approved. When they are wrong or incomplete, an agent does not fix them and does
not code around them: it explains the gap well enough for the person to decide in a few minutes, and the loop goes
on with the work that doesn't depend on it.

## Is it a model gap?

Yes, when the behavior needs something the approved baseline does not have or contradicts:

- a field, event, command, state, transition, listener or call that the ZDL does not declare;
- a correlation that doesn't hold (the command takes the id of one reservation, the event carries the order's);
- a required input field with no source upstream;
- two model lines, or a model line and an ADR, that contradict each other;
- an outcome or precondition the approved fixtures cannot represent.

No, when the code can do it with what the models declare: a mapping, a lookup in the same context, a guard. That is
the task. And no when the model is silent on a detail no one would notice (a log message, an internal name): choose,
and list it under CHOICES in the report.

When unsure, it is a gap: a short proposal costs the person a minute; a wrong guess costs a rework.

## Write the proposal

Follow [proposal-format.md](references/proposal-format.md). Take the next free id in `docs/proposals/` (the highest
`P-<nn>` plus one; when several agents run at once, the orchestrator may renumber).

- **Problem**: the lines that cannot express the behavior, quoted briefly, each one a link to its line:
  `[file:line](<path relative to the proposal>#L<line>)`.
- **Evidence**: the test, fixture or input that shows it. A failing test name is the best evidence.
- **Options**: at least one, each with what it changes in the models, the generated code and the test data. Recommend
  one, and say why.
- `blocks:` the task you were on, and the ones you know depend on it.

Don't edit the model, even when the fix looks like one line. Don't regenerate.

## Then

- Leave in the tree only the changes that stand on their own; revert your own unfinished ones.
- Report `STATUS: blocked P-<nn>` with the proposal path.
- The orchestrator marks the tasks `[!]` with `blocked: P-<nn>`, tells the person, and carries on with the tasks that
  don't depend on it. The person resolves it in the HITL loop (`zenwave-grill-models`), and a new baseline releases
  the tasks.
