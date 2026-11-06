# zenwave-sdd manual

The [README](README.md) is the step by step. This is the method behind it, and the reference for each piece.

## 1. Principles

- **The models are the spec.** ZFL says when and why (flows, policies, outcomes, compensations, timers); ZDL says
  what (aggregates, lifecycles, commands, events, listeners, calls); OpenAPI and AsyncAPI are the contracts. A medium
  service fits in a couple of hundred lines that a person can read and approve, which is what prose specs cannot give
  you at the speed an LLM writes them.
- **People decide, agents look things up.** In the HITL loop the agents find the questions and you answer them. Facts
  (what the code does, what a file says) are the agent's job; decisions (business rules, names, boundaries) are yours.
- **The approved baseline is read-only for the AFK loop.** Models, contracts and test data are tagged at the gate.
  An agent that finds them wrong writes a proposal and stops that task; it never edits them or codes around them.
- **Models own structure.** A missing field, event, command or state is fixed in the model and regenerated, never
  hand-added to generated code.
- **Vertical slices.** Work is sliced along the paths of a flow, the happy path first (the tracer bullet), so every
  slice is testable end to end. Agents left alone slice horizontally (all entities, then all services); the board
  review is where you catch it.
- **Test first, from approved data.** The implementer starts from a fixture you approved and the outcome the ZFL
  names, writes the failing test, then the code. It cannot shape the test data to fit its code.
- **Small contexts, documents as memory.** Every task runs in a fresh context sized to fit. Whatever must survive a
  session lives in files: the models, the glossary, the ADRs, the board, the proposals.
- **Review by a different model.** Never review code with the model that wrote it, and review per slice, not per task.

## 2. The HITL loop

| Step | Skill | Output | Who decides |
|---|---|---|---|
| Discovery and first models (new project) | `zenwave-grill-domain` | `GLOSSARY.md`, `docs/adr/`, `docs/domain.md`, then one `*.zfl` per flow and one `*.zdl` per bounded context | you, answering rounds of questions; you review the draft |
| A new flow (existing project) | `zenwave-extend-models` | the impact list, a new `*.zfl`, additive changes to the existing `*.zdl` | you, on the impact list before it writes |
| Challenge | `zenwave-grill-models` | model changes, ADRs, glossary entries | you |
| Projections | ZenWave IDE plugin | diagrams, state machines, contracts | you, by looking |
| Generate | ZenWave SDK (`zenwave-scripts.zw`) | structure, APIs, test skeletons | deterministic |
| Test data | `zenwave-test-data`, `zenwave-test-scenarios` | `data.sql`, JSON aggregates, scenario matrix | you approve the matrices |
| Board | `zenwave-tasks-from-code-and-models` (code exists) / `zenwave-tasks-from-models` (none yet) | `docs/tasks.md` | you approve the slices |
| Gate | `zenwave-gate-check` | the checklist, then your tag | you |

It is not linear. Generating code shows a missing field; the test data shows a precondition no state can express;
the board shows a branch with no end. Each sends you back to the models, and the cheapest moment to find it is now.

### Grilling

Both grilling skills follow Matt Pocock's [`grilling`](https://github.com/mattpocock/skills) skill, copied verbatim
(MIT) in `templates/grilling/`, plus a ZenWave layer, [templates/grilling.md](templates/grilling.md), that replaces
his `domain-modeling` with the glossary and ADR formats and the ZenWave languages. Nothing of his has to be
installed. The open decisions form a tree;
each round asks the whole frontier (the decisions whose prerequisites are settled), numbered, each with a
recommended answer, worded so that "yes" accepts it. The agent looks up facts itself, and writes the glossary and
the ADRs as decisions settle, not at the end. The ZenWave version walks a design tree specific to flows: actors and
scope, `end` outcomes, policies and branches, bounded contexts, `call` or event, compensations, timers, lifecycles,
correlation and lineage, rules, concurrency, personal data.

### The gate

Five conditions, as in the article [Two loops](https://ivangsa.com/articles/sdd-two-loops-model-driven-human-in-the-loop/):
the models are valid (lint, no LLM involved), reviewed by you and by the agents, covered by test data for every
branch, broken into an approved board, and committed and tagged. `zenwave-gate-check` checks what is mechanical and
asks you for the rest. The tag `baseline/<flow>-<n>` goes on the implementation repository and on each repository
that holds models, so "what was approved" is one name everywhere.

## 3. The AFK loop

### Roles

| Role | Who | Does | Never |
|---|---|---|---|
| You | the person | answer proposals, test the running application, change priorities and routing, merge | read every diff as it lands |
| Orchestrator | a Claude Code session with the `orchestrator` agent | plans from the board, hands tasks out, checks what comes back, merges, sends slices to review, writes the board, talks to you | write product code, edit the baseline, merge into your branch, sign |
| Worker | a Claude subagent, Codex or Grok, in a clone, fresh context per task | one task, test first, focused tests, a report | commit, push, edit the baseline |
| Reviewer | a worker that implemented none of the slice, a strong model | one slice, full suite, model axis and standards axis | edit anything but its report |

### The orchestrator is the scheduler

An earlier version of this repository ran the loop in a bash engine (`archive/zw-afk-engine`). It was a lot of code to
do what Claude Code already does: start agents in the background, be told when they finish, and decide what goes next.
The method that worked on ZenWave's own repositories, and the one used here, is an orchestrator session that:

- reads the plan (the board) and decides what can go in parallel;
- hands each task to a worker in its **own clone**, so no two jobs ever share a checkout;
- does not trust a process that ended: it looks for the report on disk and the commits in the clone;
- reads the report and the diff, repeats the tests itself, and only then merges;
- keeps the board and a short log current after every task, because that is what survives a restart or a compaction.

Its costs are known and accepted: it spends tokens reading reports, it cannot restart itself if it runs out of its own
usage limit, and a person has to bring it back; and when its conversation is compacted it relies on the board, the log
and the clones to recover what it knew.

### What runs in parallel

Tasks run at the same time when they touch different bounded contexts (the files in their `model:` fields), they do not
depend on each other, and they are under the limits of `.zenwave/routing.md`. Inside one flow that is often the early
slices: the calls that a command makes into three other contexts, the listeners of notifications and analytics.
Slices that extend the same command (the alternative outcomes of `bookSlot`, say) go one after another: they edit the
same method and would only produce merge conflicts. A task that depends on another starts after the other is merged, so
its clone already includes it. Codex runs one job at a time.

### Clones and merging

```
person's checkout ── .zenwave/work/integration   branch afk/<flow>, the baseline tag plus every merged task
                  ├─ .zenwave/work/T-02          clone, branch task/T-02, push disabled   (worker A)
                  ├─ .zenwave/work/T-03          clone, branch task/T-03, push disabled   (worker B)
                  └─ .zenwave/work/review-S1     throwaway clone at the slice's last commit (reviewer)
```

A worker can never push: its clone's push URL is `DISABLED`, which also makes it safe to run Grok with
`--always-approve`. The orchestrator commits what a worker brings (unsigned, with trailers), fetches the branch into
`integration` and merges it with `--no-ff`. Clones are deleted after the merge. Your own checkout is never touched.

### Routing

[`.zenwave/routing.md`](templates/routing.md) says who takes each kind of work, in order: a first choice and the
fallbacks for when it is out of quota or has failed twice. It also holds the commands that start Codex and Grok, the
limits (tasks at once, one Codex job), and the files no worker may change. The orchestrator reads it whenever it hands
work out, so you can change it in the middle of a flow, by editing the file or by telling the orchestrator.

Reviews go to a worker that implemented none of the slice when there is one. A review runs on a snapshot of the slice,
so the next slice can be implemented while it runs.

### Usage limits

Each CLI says it is out of quota in its own words (`You've hit your 5-hour limit · resets 6:30pm`, `usage limit … try
again at 9:39 AM`). A headless CLI does not wait: it prints the message and exits. The orchestrator notes the worker
and the reset in `.zenwave/handoff/<flow>/quota.md`, routes to the next worker from then on, and starts the
interrupted task again in the same clone with a handoff prompt (the original task, `git status`, the diff so far, the
last message of the previous worker). If every worker of a row is out, it tells you and schedules one wakeup at the
earliest reset.

### Git and signing

AFK commits go to `afk/<flow>` in the `integration` worktree, with `commit.gpgsign=false` there only. They carry the
trailers:

```
feat(place-order-flow): T-07 authorizePayment: emit exactly one outcome

AI-Agent: codex
AI-Model: gpt-6.1-sol
AI-Orchestrator: claude-code
```

You sign once per loop, when you have reviewed the result: `git merge --no-ff -S afk/<flow>`. Your GPG agent cache can
stay short. If your branch protection requires every commit to be signed, give the agents their own signing key (an
SSH or GPG subkey without passphrase, a distinct identity, revocable) instead.

### Exit

Every task `[x]` or `[!]`, every slice reviewed `[x]`, the full suite green, no open proposal; and the check mode of
the tasks skill finds nothing missing between the models and the code. The orchestrator archives the board to
`docs/tasks/<flow>-<baseline>.md` and reports. Blocked tasks or open proposals mean it is not done: they wait for you.

## 4. Tests: two levels

| Level | When | Data | Runs |
|---|---|---|---|
| Focused unit tests | each task | JSON aggregates (`src/test/resources/data/<persistence>/<Entity>/<n>.json`) loaded into in-memory repositories | the task's `tests:` only |
| Full suite | each slice review | `data.sql` loaded into Testcontainers | everything, once |

Build times grow with the project: running integration tests per task would leave the agents waiting most of the time.

## 5. Deployment shapes

Choose before writing ZDL; record it in the overlay.

| | Microservices (Kafka + AsyncAPI) | Modulith |
|---|---|---|
| Repositories | one per bounded context (plus its contracts) | one, a module per bounded context |
| ZDL consumer | `@asyncapi(api: XApi, channel: "...")` | `@listener(zdl: XZdl, event: ...)`, `@listener(event: ...)` |
| Inbound event code | `*ConsumerService` adapters over AsyncAPI consumer interfaces | `*EventsListener` with `@ApplicationModuleListener` |
| Synchronous calls | HTTP client behind a port | the other module's service interface |
| Archetype | `-Dkafka=true` | `-Dmodulith=true` |
| Unit of work | this repository's slice of each flow | the whole flow |
| Flow tests | consume and produce with a broker in Testcontainers; end to end in an environment | Spring Modulith `Scenario`, one JVM |

## 6. Known generator issues

Found with zenwave-sdk 2.7.x Kotlin templates. Check after every generation.

| Symptom | Cause | Workaround |
|---|---|---|
| Testcontainers cannot connect: database `DATABASENAME` doesn't exist | placeholder in `DockerComposeInitializer` | set the name (again after a forced regeneration) |
| "Named arguments are prohibited for non-Kotlin functions" in controller tests | Kotlin named arguments on Java OpenAPI DTOs | fluent setters |
| Repository `updateTest` fails on `Instant` fields | asserts `Instant.now()` equality | assert not null, or a fixed instant |
| OpenAPI `minLength: 1` on an array item | `X[] minlength(1)` maps to the wrong keyword | should be `minItems` |
| Unimplemented methods emit every `withEvents` alternative, never load or save | the generated-once body, by design | the board's tasks |
| Mappers pass `null` into non-null Kotlin parameters | unmapped fields | fix the lineage in the model, then `@Mapping` |

`data.sql`, the fixtures, `DockerComposeInitializer`, the `*Impl` classes, listeners and their mappers are generated
once: a normal regeneration keeps your edits; a forced one (`-f`) replaces them.

## 7. Linting the models

`jbang zw lint` (zenwave-sdk 2.8.0+) checks syntax, unknown types and events, unresolved clients, listener and call
targets, lifecycle states, and with `--strict` data lineage and mixed bindings. Exit 0 clean, 1 findings, 2 the tool
failed. The skills call it through `.zenwave/bin/lint-zdl.sh` (installed by `install.sh`), which writes
`target/zdl-lint/<name>.json`; how to read the report is in `templates/zenwave-languages/lint.md`.

### The modeling rules

How a flow becomes ZDL (one model per bounded context, commands, events, `@calls`, multi-response results, lifecycles,
and `@asyncapi` or `@listener` by deployment shape) lives in `templates/zenwave-languages/modeling-rules.md`, with the
id and topic conventions next to it. It came from the first skill of this repository, `zfl-to-zdl`, a scaffold generator
that `zenwave-grill-domain` and `zenwave-extend-models` replaced: they write models from decisions, not from a ZFL
alone.

## 8. Developing zenwave-sdd

- Shared formats live in `templates/` and are copied into each skill's `references/` (skills are installed one by
  one): `scripts/sync-references.sh` after editing them, `--check` in CI.
- `scripts/update-references.sh` refreshes the third-party and ZenWave material by copying the latest versions:
  Matt Pocock's `grilling` (from GitHub), the ZFL and ZDL docs pages (`ZenWave360.github.io`), the grammars
  (`dsl-kotlin`) and the Arcadia Editions examples (one flow; orders and payments in both shapes). Then it syncs them
  into the skills. Review `git diff` before committing.
- `bin/lint-zdl.sh` and `bin/check-board.sh` are installed into projects as `.zenwave/bin/`. The board checker
  validates the format and the graph of a board; try it on any `docs/tasks.md`.
- The bash engine of earlier versions is at the tag `archive/zw-afk-engine`.

## Credits

Grilling is Matt Pocock's skill (MIT), with a ZenWave layer; vertical slices, tracer bullets, the smart zone and the day/night
shift framing come from his workshop and from Dex Horthy (HumanLayer); the Ralph loop is Geoffrey Huntley's, and the practice of an orchestrator handing tasks to workers in clones comes
from how ZenWave's own repositories were built.
