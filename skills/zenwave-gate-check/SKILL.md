---
name: zenwave-gate-check
description: Run the checklist of the gate between the HITL and the AFK loops of one business flow - models lint clean, no open proposals, generated code up to date, test data that loads and covers every task, an overlay that records where the test data is, how long the full suite takes and which tests fail at the baseline, a board that parses as a DAG and points at real model lines, the AFK configuration and worker CLIs in place, a clean tree - and report each item with its evidence, so the person can decide and tag the baseline. Read-only. Use when the person thinks a flow is ready to hand to the agents.
---

# Gate check

The gate is the person's decision: they have read the projections of the models, answered the agents' questions,
and approved the test data and the board. This skill checks what can be checked without judgement, so nothing is
forgotten, and gives them the commands to tag the baseline. It changes nothing: when the overlay lacks a fact (items 10,
11 and 12), it prints the line to add and leaves the file as it is.

## Checklist

Run every item, even after a failure, and report all of them. Each one is ✅ with its evidence, ❌ with what is
wrong and how to fix it, or 👤 for what only the person can confirm.

### Models

1. **Lint is clean** for every ZDL of the flow: `bash .zenwave/bin/lint-zdl.sh --strict <files>`.
   No errors; list the warnings.
2. **ZFL and ZDL agree**: every `@zdl(...)` path resolves, every command and event of the flow exists in its ZDL,
   every `@compensates(x)` names a command.
3. **No open proposals** in `docs/proposals/` (`status: open`), or each open one is listed as blocking named tasks.
4. 👤 **Challenged**: the person ran `zenwave-grill-models` on the current models and the frontier was empty.
5. 👤 **Projections reviewed**: diagrams, sequence diagrams per branch, state machines, API contracts.

### Generated code (when the project uses ZenWave SDK)

6. **Up to date**: the overlay's staleness check (packaged ZDLs against the working copy) prints nothing, and the
   last regeneration is committed (`git status` clean after it).
7. **It builds**: the overlay's compile command passes.

### Test data

8. **Loads**: the test data validation from the overlay (repository tests against `data.sql`, service tests loading
   the JSON aggregates) runs with no failure while **loading** the data (`ScriptStatementFailedException`,
   `Error reading json test data`). Other failing tests are item 12. Note how long this run took: item 11 uses it.
9. **Covers the board**: every AFK task with behavior has `test data:`, and every chain id or fixture it names exists
   (chain ids in the `data.sql` header, fixture files under `src/test/resources/data/`).
10. **The overlay points at the test data**: its "Where things are" table has a row for it that names
    `src/test/resources/data.sql` and what the header holds (the scenario matrix and the chain ids, and the fixed test
    "now" with how tests read it, a `Clock`). ❌ when the row is missing or still the
    `<after test data: ...>` placeholder: print the row to add, built from the `data.sql` header.
11. **The overlay names the duration of the full suite and what it needs** (containers, Docker), next to the full-suite
    command. Measure it from the run of item 8; when the overlay's full-suite command is a different one, say that the
    number is of the part that ran. ❌ when it is missing or still the `<after generation: ...>` placeholder: print
    the line to add, with the measured number, for example
    `# about 10 minutes; needs Docker (Testcontainers starts the docker-compose)`.
12. **Known failing tests at the baseline**: every test that fails in the run of item 8 is listed in the overlay
    as known, with its cause, or is named in the `tests:` of a board task that fixes it. ❌ for each one in neither
    place: print the line to add to the overlay, or the task to write. ✅ with "none" when nothing fails.
13. 👤 **Approved**: the person reviewed the scenario and coverage matrices.

### Board

14. **Parses as a DAG**: `bash .zenwave/bin/check-board.sh docs/tasks.md` passes (format, unique ids, blockers exist, no cycles, no task blocked by a
    later slice).
15. **Points at real lines**: every `model:` reference names a file that exists and lines within it.
16. **Has a tracer bullet**: S1 ends at the flow's success outcome and crosses every context of its path.
17. 👤 **Approved**: the person reviewed the slices; no slice is a layer.

### AFK setup

18. `.zenwave/routing.md` exists and is committed; each worker it names has its CLI installed (`command -v codex`,
    `command -v grok`); every difficulty used on the board has a first choice and a fallback; the `review` row has a
    worker other than the ones that will implement.
19. `AGENTS.md` points at the overlay, and the skills are installed where each worker reads them
    (`.claude/skills` or the plugin, `.agents/skills`, `.grok/skills`).
20. **Clean tree**: everything above is committed, in this repository and in the models' repositories.

## Report and tag

Print the checklist. If every ✅ item passed, give the commands for the person to run once they confirm the 👤 items:

```bash
# in the implementation repository: record the baseline in the board, commit, tag
sed -i 's/^baseline:.*/baseline: baseline\/<flow>-<n>/' docs/tasks.md
git commit -S -am "chore: baseline <flow>-<n>" && git tag -s baseline/<flow>-<n> -m "<flow>: approved models, test data and board"
# in each models repository, the same tag on the commit the code was generated from
git -C <models repo> tag -s baseline/<flow>-<n> -m "<flow>: approved models"
```

`<n>` is one more than the highest existing `baseline/<flow>-*` tag. Then the AFK loop starts with
`claude --agent orchestrator`.

If any ❌ remains, say which ones block the gate, and stop there.
