# Plan: zenwave-sdd as the tool for ZenWave projects

Working document for the redesign. Delete it when the README describes what exists.

## Goal

This repository is what a ZenWave project installs. A person follows the README and sets up a new project, created
from the ZenWave archetype or empty, ready to run the two loops on one business flow: HITL (model, review, test
data, board, gate) then AFK (implement, review, integrate) until the flow is done. No Spec Kit.

Guinea pig: `arcadia-editions/arcadia-editions-modulith-service-kotlin` (generated, no Spec Kit). The Java one is
left alone.

## Decisions

| # | Decision |
|---|---|
| D1 | **Unit of work: one business flow** (one ZFL). One HITL → gate → AFK loop per flow; ZFL and ZDL are complete blueprints. |
| D2 | **Board** `docs/tasks.md`, written only by the orchestrator. Archived at the end of the loop as `docs/tasks/<flow>-<baseline>.md`; `docs/tasks.md` starts empty for the next flow. |
| D3 | **Tasks are vertical slices.** A slice is one branch of the ZFL: a policy and one `@outcome`, through command, event, listener, mapper and their tests. The first slice is the **tracer bullet**: the flow's happy path end to end. Then alternative and failure branches, then polish. Infrastructure (it compiles, the test data loads) comes before everything. |
| D4 | **The board is a DAG**: every task says what it is blocked by. Each task has a difficulty (`mechanical`, `bounded`, `advanced`) and a type (`AFK`, or `HITL` for what needs a person); the loop picks up AFK tasks only. Each task fits a fresh context in the smart zone. States `[ ]` pending, `[/]` in progress, `[\]` in review, `[x]` done, `[!]` blocked. |
| D5 | **Two test levels.** A task is done with its focused unit tests (the tests of what it touched, never the whole unit suite): in-memory repositories loaded from the JSON aggregates (`data/jpa/<Entity>/<n>.json`). A slice is reviewed with the full suite: integration tests with Testcontainers loaded from `data.sql`. Build times make per-task integration runs too slow. |
| D6 | **Test first from the approved fixtures.** The implementer writes the failing test from the scenario fixture and the ZFL outcome, then the code. Test data is approved at the gate and AFK agents never edit it. |
| D7 | **Review per slice, two axes reported apart**: the *model* axis (meets the ZFL/ZDL lines, nothing out of scope) and the *standards* axis (the repository's conventions, pushed into the reviewer's prompt). A reviewer never reviews its own model's code. |
| D8 | **Model gaps**: the implementer stops and writes a proposal `docs/proposals/P-xx.md` (problem, evidence, options). The orchestrator blocks the task, carries on with what doesn't depend on it, and tells the person. Resolving it is HITL: the person decides, the model changes, code is regenerated, the board changes, a new baseline is tagged. |
| D9 | **AFK never edits** models (ZFL, ZDL), API contracts or test data. |
| D10 | **The orchestrator is a coworker.** The person talks to it, in the session during QA, from the phone the rest of the time: findings, priorities, progress. It suggests the order; the person decides. It is the only writer of the board. |
| D11 | **Hybrid loop** (see D22 for how it runs).** The mechanics are a deterministic bash script, `zw-afk` (`tick`, `once`, `loop`, `status`): read the board, compute the ready tasks, choose a worker by the routing config and quota state, start the CLI in the task's worktree with a fresh context, record the result, wait for a quota reset or hand off. The judgement is the orchestrator agent's: it runs ticks, reads reports, decides on review findings, writes proposals, commits and reports. Without the orchestrator, `zw-afk once` / `zw-afk loop` is a Ralph loop. |
| D12 | **Workers**: Claude, Codex and Grok CLIs, with shares and models per difficulty in `.zenwave/afk.conf` (`key = value`: no YAML parser needed in bash), editable at any time. Quota exhaustion and reset times are detected for every CLI; a worker without quota is skipped until its reset; long threads hand off. |
| D13 | **Git**: AFK commits go to `afk/<flow>` with `commit.gpgsign=false` in that worktree only, and trailers `AI-Agent`, `AI-Model`, `AI-Orchestrator`. The person merges with a signed `git merge --no-ff -S`. |
| D14 | **Bash only** (Git Bash on Windows). No PowerShell. |
| D15 | **Gate is human.** `zenwave-gate-check` is a read-only checklist with evidence; the person decides and tags `baseline/<flow>-N`. |
| D16 | **AFK exit** is the orchestrator's report: every task done or blocked, slice reviews clean, full suite green, no open proposals, the generated-project check finds nothing missing. No skill. |
| D17 | **Gap report ids are disposable.** What stays is the ZenWave-specific knowledge of generated code, which is deterministic: generated-once files, `TODO` markers, listeners, mappers, controllers, test skeletons. |
| D18 | **The PRD or brief** that the models came from is deleted once the models are approved: the models are the spec, decisions go to ADRs, terms to the ZDL doc comments. (Article change, not a skill.) |
| D20 | **Grilling** (adapted from Matt Pocock's `grilling` and `domain-modeling`) drives the HITL loop: rounds over the frontier of a design tree, a recommended answer per question, facts looked up by the agent, decisions asked to the person. Two skills share it: `zenwave-grill-domain` (brief, PRD, Event Storming → `GLOSSARY.md` with ZDL/ZFL identifiers, ADRs, the list of flows) and `zenwave-grill-models` (challenges ZFL/ZDL: contradictions, missing correlations, events nobody listens to). Pista Aberta is where it was first applied. |
| D21 | **Who edits models.** In the HITL loop an agent may edit ZFL/ZDL, only when the person asks for that change in the session. In the AFK loop, never (D9). |
| D19 | The current `orchestration/` (built ad hoc to develop ZenWave) is tagged `archive/zenwave-dev-orchestration` and removed. Its quota recovery logic and its lessons are reused. |

## What gets built

```
README.md                     the only thing to read to set up a project, step by step
MANUAL.md                     the method: two loops per flow, why, reference
.claude-plugin/               the repository is the plugin zenwave-sdd (skills + agents)
skills/
  HITL  zenwave-grill-domain         new: D20, discovery before the models
        zfl-to-zdl                   deprecated and removed (D24); its rules live in templates/zenwave-languages
        zenwave-grill-models         new: D20, agents challenge ZFL/ZDL; the person decides, D21
        zenwave-test-data            keep, revise: the JSON + SQL data sets of D5
        zenwave-test-scenarios       keep, revise
        zenwave-tasks-from-models    new: board for an empty project or another stack
        zenwave-tasks-from-code-and-models (was -from-generated, D26) new: board when code exists; absorbs zenwave-gap-report;
                                     in check mode it is the exit check of D16
        zenwave-gate-check           new: D15
  AFK   zenwave-implement-task       new, replaces zenwave-fill-gaps: one task, test first (D6)
        zenwave-review-slice         new: D7, runs the full suite
        zenwave-model-gap            new: D8
agents/                       orchestrator, implementer, reviewer
bin/zw-afk                    D11, D12, D13 (+ lib/ with one adapter per CLI)
templates/                    AGENTS.md, CLAUDE.md, overlay, tasks.md, proposal.md, afk.yml
```

Install: Claude Code plugin; `npx skills add ZenWave360/zenwave-sdd` for Codex and Grok.

## Order

1. Archive and remove `orchestration/` (D19). Write this plan.
2. Board format: `templates/tasks.md` and its specification. Everything else reads or writes it.
3. `zenwave-tasks-from-generated`, tried on the Kotlin project's place-order flow: a real board early.
4. AFK: `zenwave-implement-task`, `zenwave-review-slice`, `zenwave-model-gap`, the three agents.
5. `zw-afk` and `afk.yml`: adapters, quota detection and reset times for Claude, Codex and Grok (look up each CLI's
   messages and resume flags), worktrees, commits with trailers.
6. HITL: `zenwave-grill-domain`, `zenwave-grill-models`, `zenwave-tasks-from-models`, `zenwave-gate-check`, revise the test data skills.
7. README and MANUAL rewritten; plugin manifest; remove `zenwave-fill-gaps` and `zenwave-gap-report`.
8. Run the loop end to end on the Kotlin project's place-order flow; fix what it finds.
9. Articles (in `ivangsa.com`, left uncommitted for review): vertical slices and tracer bullets, the board format,
   test first from fixtures, review per slice, the orchestrator as coworker, deleting the PRD; and a new article on
   the hybrid loop.

## Status (2026-11-05)

- Done: steps 1 to 7, and 9 (article changes left uncommitted in `ivangsa.com` for review, and a draft of the hybrid
  loop article, `2026-11-06-sdd-two-loops-hybrid-afk-loop.md`).
- Step 8, the end-to-end run on a real project (the Kotlin Arcadia modulith, Pista Aberta), is the owner's.
- Not built yet: parallel tasks in their own worktrees (`max_parallel > 1`); `zw-afk` runs one task at a time.
- Verified only with fake CLIs (`tests/zw-afk-smoke.sh`): the real CLIs' permission flags in `afk.conf`
  (`--permission-mode auto`, `--approve-for-me`), Grok's limit messages and session resume, and the skills themselves.

## Update (2026-11-06): one engine, a single writer

- D22. `zw-afk serve` is one long-lived process per flow and the only writer of `docs/tasks.md` while it runs. The
  orchestrator and the person send orders through an inbox (`zw-afk send`), the engine applies them in order,
  validates the board after each, and answers through an outbox. This replaces the board lock. Workers run as
  background jobs, so the engine keeps taking orders while they work and while it sleeps through a quota reset.
- D23. The two modes are one engine with a policy: `auto` (Ralph: it commits and adds fix tasks itself) and
  `supervised` (it waits for `approve` / `reject` / decisions from an orchestrator). The policy is switchable while it
  runs. The orchestrator no longer starts workers; it follows `status` and `events` and sends orders.
- Other changes: the ledger counts only implementation runs (it counted commits, reviews and limits too); shares and
  any setting can be overridden at runtime (`.zenwave/afk/overrides.conf`); `clear-quota` for a wrong reset time;
  a review falls back to an implementer, with a warning, when no other worker is configured to review (`strict`
  disables it); `pipefail` removed from `zw-afk`, where `grep -q` made pipelines fail intermittently.
- Verified with fake CLIs only: `tests/zw-afk-smoke.sh` and `tests/zw-afk-serve-smoke.sh`. The orchestrator agent has
  never been run, and neither engine mode has met a real CLI.

## Update (2026-11-06): models written by the grilling, a brownfield skill

- D24. `zfl-to-zdl` is removed. Its rules went to `templates/zenwave-languages/` (`modeling-rules.md`,
  `asyncapi-naming-conventions.md`, `lint.md`), and the ZDL lint to `bin/lint-zdl.sh`, installed as
  `.zenwave/bin/lint-zdl.sh`. `install.sh` removes the retired skills from projects that had them.
- D25. `zenwave-grill-domain` ends by drafting every model (one ZFL per flow, one ZDL per bounded context, linted),
  after the person confirms the understanding. New `zenwave-extend-models` is the brownfield counterpart: a new flow on
  existing code and models, impact list first (additive / behavior / breaking), then additive changes to the existing
  ZDL.
- D26. `zenwave-tasks-from-generated` is now `zenwave-tasks-from-code-and-models` (code of any origin). Both task
  skills take the flow and where every input is: ZFL, ZDL, API contracts, code, test data (or the overlay's paths),
  and stop when one is missing.

## Update (2026-11-06): the engine is gone, the orchestrator schedules

- D27. Supersedes D11, D12, D22 and D23. The bash engine (`zw-afk`: serve, inbox of orders, policies, quota files) is
  removed; it stays at the tag `archive/zw-afk-engine`. The orchestrator, a Claude Code session, is the scheduler, as in
  the setup that built ZenWave's own repositories: it hands ready tasks to workers (Claude subagents, Codex, Grok) in
  parallel clones, checks every report on disk and every diff, merges task by task into `afk/<flow>`, and sends each
  finished slice to a reviewer in a throwaway clone. It is the only writer of the board.
- D28. Routing is a file, `.zenwave/routing.md`: per kind of work a first choice and fallbacks, the commands for Codex
  and Grok, the limits, and the protected files. Editable by hand or through the orchestrator.
- Kept: the board format and `bin/check-board.sh`, `bin/lint-zdl.sh`, the skills, `install.sh`.
- Accepted costs: more tokens, the orchestrator cannot restart itself after its own usage limit, and a compaction
  costs it memory (the board, `.zenwave/handoff/<flow>/log.md` and the clones are what it reads back).
- Unattended loops are out of scope. Sandcastle (MIT, TypeScript) exists for that.
- The orchestrator's git sequence (worktree, clone with push disabled, commit, fetch, merge) was run in a scratch
  repository. The orchestrator itself, with real workers, has not been run.
