# zenwave-sdd

Model-driven development with AI agents, for projects designed with ZenWave. One business flow at a time, in two
loops:

- **Human in the loop (HITL).** You and the agents discover the domain and write it as models people can read and
  review: ZFL for the business flows, ZDL for each bounded context, OpenAPI and AsyncAPI for the contracts. The agents
  challenge the models; you decide. Then the test data for every branch, and a board of tasks sliced along the flow.
- **Away from keyboard (AFK).** Once you approve and tag that baseline, an orchestrator hands each task to an
  implementer agent and each finished slice to a reviewer agent, commits the work to a branch, and stops to ask you
  only when the models turn out to be wrong. You follow it from your phone.

The models are the spec, so there is very little Markdown to read. The why is in the [MANUAL](MANUAL.md) and in the
articles [Reading Markdown is the bottleneck](https://ivangsa.com/articles/sdd-markdown-is-the-bottleneck/) and
[Two loops](https://ivangsa.com/articles/sdd-two-loops-model-driven-human-in-the-loop/).

```
 discovery ─► grill the domain ─► ZFL ─► ZDL ─► grill the models ─► generate ─► test data ─► board ─► gate (tag)
   brief,        glossary, ADRs     ▲                │                 (ZenWave SDK, optional)              │
   Event Storming                   └── you decide ◄─┘                                                       ▼
                                          ▲                         orchestrator: implement ─► commit ─► review slice
                                          └──── model gap proposals ◄──────────┘             (afk/<flow> branch)
                                                                                                   │
                                                                     done ─► you merge it, signed ◄┘
```

## What you need

- **Git Bash** on Windows, or any bash on Linux and macOS. Every command here is bash.
- **At least one agent CLI.** [Claude Code](https://claude.com/claude-code) runs the orchestrator and can do
  everything else. [Codex](https://github.com/openai/codex) (`npm i -g @openai/codex`) and Grok are optional
  workers that share the implementation and review load.
- **For ZenWave-generated Spring Boot projects:** a JDK, Maven, Docker, and the ZenWave CLI
  (`jbang zw`, see [ZenWave getting started](https://www.zenwave360.io/docs/getting-started/)). The method works
  without them, in any stack, with `zenwave-tasks-from-models` instead of the generator.

**Running a skill.** Open the agent at the root of your project. In Claude Code and Grok type `/<skill>`; in Codex
`$<skill>`; with any agent you can say "run the <skill> skill". Lines starting with `/` below are typed into the
agent; `bash` blocks run at the root of your project.

## 1. Set up the project (once)

**1.1 Create it.** From the ZenWave archetype (Kotlin shown; there is one for Java):

```bash
mvn archetype:generate -DarchetypeGroupId=io.zenwave360.archetypes \
  -DarchetypeArtifactId=zenwave-kotlin-archetype -DarchetypeVersion=<version> \
  -DgroupId=com.example -DartifactId=orders-service -Dpackage=com.example.orders -Dversion=0.0.1-SNAPSHOT \
  -DprojectName="Orders" -DprojectDescription="Orders" \
  -Djpa=true -Dkafka=true -Dmodulith=false -DinteractiveMode=false
```

`-Dmodulith=true` for a modular monolith; `-Dkafka=true -Dmodulith=false` for a microservice. Any existing git
repository works too, generated or not.

**1.2 Install zenwave-sdd** from a release tag. Run it again with a newer tag to upgrade, then review `git diff`:

```bash
ZWSDD=<tag>
git clone -q --depth 1 --branch "$ZWSDD" https://github.com/ZenWave360/zenwave-sdd ../zenwave-sdd-$ZWSDD
bash ../zenwave-sdd-$ZWSDD/install.sh            # --agents claude,codex,grok (default: all three)
```

It installs the skills for each agent (`.claude/skills`, `.agents/skills`, `.grok/skills`), the `orchestrator`,
`implementer` and `reviewer` agents (`.claude/agents`), and two checkers (`.zenwave/bin`: the ZDL lint and the board
check). It creates, only if missing, `docs/zenwave-sdd-overlay.md`, `.zenwave/routing.md`, `AGENTS.md` and `CLAUDE.md`.

**1.3 Fill in the overlay and look at the routing.**

- [`docs/zenwave-sdd-overlay.md`](templates/project-overlay.md): where the models are (in this repository, a sibling
  one, or a packaged jar), the shape (microservices or modulith), and the commands to compile, run the focused tests,
  run the full suite and lint the models. Every skill reads it first and stops if it is incomplete.
- [`.zenwave/routing.md`](templates/routing.md): which worker takes each kind of work (mechanical, bounded, advanced,
  review), who is the fallback, how Codex and Grok are started, how many tasks run at once, and which files no worker
  may change. Set it to the agents and subscriptions you have; change it any time.

```bash
grep -n '<' docs/zenwave-sdd-overlay.md     # no placeholder left
git add -A && git commit -m "chore: set up zenwave-sdd"
```

## 2. The HITL loop, for one business flow

**2.1 Discover the domain and draft the models** (a new project). Bring what you have: a brief or PRD, Event Storming
pictures, meeting transcripts.

```text
/zenwave-grill-domain docs/brief.md
```

It interviews you in rounds, a recommended answer for every question, until the flows, bounded contexts, commands,
events, outcomes and rules are decided. As decisions settle it writes `GLOSSARY.md` (with the ZFL and ZDL
identifiers), ADRs in `docs/adr/`, and `docs/domain.md` with the list of flows. When you confirm the understanding it
drafts every model: one ZFL file per flow and one ZDL per bounded context, in your deployment shape, linted. You
review and change them; nobody writes the first version by hand.

**2.2 Add a flow to an existing project** (code and models already there). Instead of 2.1:

```text
/zenwave-extend-models docs/refund-flow-notes.md
```

It reads the existing flows, ZDL models, contracts, code and test data, and grills you on how the new flow reuses
and extends them. Before it writes anything it shows the impact: each change as additive, behavior or breaking, and
what it touches (other flows, consumers, stored data). After your go it writes the new ZFL flow and adds, to the
existing ZDL models, the new commands, events, listeners, calls, fields, states and transitions, without touching
anything else, and lints them.

**2.3 Challenge the models.**

```text
/zenwave-grill-models place-order-flow
```

The agent lints the models and looks for contradictions, missing correlations, fields with no source, branches that
never end, side effects never compensated. It asks you about each one. You decide; the agent changes a model only
when you ask it to. Meanwhile, review the projections in the ZenWave IDE plugin: flow and sequence diagrams per
branch, state machines, the API contracts. Repeat until there are no questions left.

**2.4 Generate** (ZenWave SDK projects). Run the plugins of `zenwave-scripts.zw` from the IDE, or the `jbang zw`
command each one shows. Compile, look at the generated code, and if something is wrong, go back to the models: early
code is throwaway code. Commit when the structure is right.

**2.5 Test data**, the cases your tests start from (JPA projects):

```text
/zenwave-test-data
/zenwave-test-scenarios
```

The first writes one consistent example per entity; the second, a fixture for every precondition, branch, failure and
outcome of the flows, as chains with ids (`C-01`…) in the header of `data.sql`, mirrored in the JSON aggregates that
the in-memory unit tests load. Review its scenario and coverage matrices: once approved, agents never change them.

**2.6 The board.**

```text
/zenwave-tasks-from-code-and-models place-order-flow      # there is code: generated with ZenWave SDK or not
/zenwave-tasks-from-models place-order-flow               # there is no code yet
```

Tell it where everything is, if the overlay does not say: the ZFL file, the ZDL models, the API contracts, the code,
the test data.

```text
/zenwave-tasks-from-code-and-models place-order-flow
    zfl: ../arcadia-editions-architecture/business-flows/place-order-flow.zfl
    zdl: ../arcadia-editions-modulith-api/*-domain-model.zdl
    apis: ../arcadia-editions-modulith-api/*-openapi.yml
    code: src/main/kotlin
    test data: src/test/resources
```

It writes `docs/tasks.md`: one vertical slice per path of the flow, the happy path first (the tracer bullet), each task
pointing at its model lines, its test data and its focused tests, with its difficulty and what blocks it. Review it:
the mistake to look for is a slice that is a layer ("all the mappers"). Format:
[board-format.md](templates/board-format.md).

**2.7 The gate.**

```text
/zenwave-gate-check place-order-flow
```

It checks what can be checked (lint, proposals, test data, the board's DAG, the AFK setup, a clean tree) and asks you
to confirm what only you can: that the models were challenged, the projections reviewed, the test data and the board
approved. Then it gives you the commands to record and tag the baseline, `baseline/<flow>-<n>`. The tag is the
contract: the AFK loop works from it and never changes models, contracts or test data.

## 3. The AFK loop

An **orchestrator**, a Claude Code session you talk to, implements the flow from the approved board. It reads
`docs/tasks.md`, hands the ready tasks to workers, checks what they bring back, merges it, sends each finished slice to
a reviewer, and tells you how it goes. The workers are Claude subagents, Codex and Grok, and **you choose which one
takes each kind of work** in `.zenwave/routing.md`.

```bash
claude --agent orchestrator
```

**3.1 What it does.**

- It creates the branch `afk/<flow>` from the baseline tag in a worktree under `.zenwave/work/integration`, so your
  checkout is never touched.
- For every task it clones that branch into `.zenwave/work/<task>` (push disabled), writes a self-contained prompt, and
  starts the worker the routing picks for the task's difficulty, in the background. Tasks that touch different
  bounded contexts run at the same time; tasks in the same context, one after another.
- When a worker ends it does not trust the notification: it looks for the report on disk, reads it and the diff,
  checks that the approved models, contracts and test data are untouched, and runs the task's focused tests itself.
  Then it commits (unsigned, with `AI-Agent`, `AI-Model` and `AI-Orchestrator` trailers), merges into `afk/<flow>`,
  ticks the board, and deletes the clone.
- When every task of a slice is done, a reviewer runs the full suite, integration tests included, in a separate clone
  while work on the next slice goes on. It reports the model axis and the standards axis apart. A `FIX` becomes fix
  tasks on the same slice.
- A worker out of usage limit is noted with its reset time and skipped; the interrupted task goes to the next worker
  of the routing with a handoff of what was done.

Implementers write the failing test first from the approved fixtures, then the code, and run only the task's focused
tests.

**3.2 Talking to it.** It is a coworker. Ask it what runs and where, who found what in a review, what is blocked and
what waits for you; send it what you find while you test the running application, and it turns it into tasks; change
priorities, or the routing ("send the advanced tasks to Sonnet, Codex is out until six"). From your phone, with Claude
Code's remote access, it is the same conversation. Its state is the board, `.zenwave/handoff/<flow>/log.md` and the
clones, so a new session picks up from them.

**3.3 When the model is wrong.** A worker that cannot do its task with the approved models writes a proposal in
`docs/proposals/P-<nn>.md` (problem, evidence, options, a recommendation) and the task is blocked; the rest goes on.
The orchestrator tells you in three lines. Resolve it with `/zenwave-grill-models` on the proposal, change the models,
regenerate, update the test data and the board, and tag a new baseline.

**3.4 Done.** When every task is done, every slice reviewed and the suite green, the orchestrator checks the flow
once more against the models, archives the board to `docs/tasks/`, and tells you. Review and merge, signed:

```bash
git merge --no-ff -S afk/<flow>
```

Delete the brief or PRD the models came from, if it is still around: the models are the spec now, and an outdated
requirement only misleads the next agent. Next flow: back to 2.1, or 2.2 if the project now has code.

**Not included: unattended loops.** The orchestrator needs you to start it and, if it runs out of its own usage limit,
to restart it. If you want agents to run unattended, for a night on a server, a loop outside of this repository is the
tool for it. [Sandcastle](https://www.aihero.dev/sandcastle/branch-strategies) by Matt Pocock (MIT, TypeScript) runs
agents in a worktree inside a container and has loop templates; the board and the skills of zenwave-sdd work with it.

## Reference

| Skill | Loop | What it does |
|---|---|---|
| [zenwave-grill-domain](skills/zenwave-grill-domain/SKILL.md) | HITL | new project: interview from brief to glossary and ADRs, then a draft of every ZFL flow and ZDL model |
| [zenwave-extend-models](skills/zenwave-extend-models/SKILL.md) | HITL | existing project: a new flow on top of the code and models, with the impact first, changing the ZDL additively |
| [zenwave-grill-models](skills/zenwave-grill-models/SKILL.md) | HITL | challenge the models; resolve proposals |
| [zenwave-test-data](skills/zenwave-test-data/SKILL.md) | HITL | one consistent example per entity, `data.sql` and JSON |
| [zenwave-test-scenarios](skills/zenwave-test-scenarios/SKILL.md) | HITL | a fixture chain per precondition, branch and outcome |
| [zenwave-tasks-from-code-and-models](skills/zenwave-tasks-from-code-and-models/SKILL.md) | HITL, exit | the board when code exists, from the code and the models; the final check |
| [zenwave-tasks-from-models](skills/zenwave-tasks-from-models/SKILL.md) | HITL, exit | the board when there is no code yet; the final check |
| [zenwave-gate-check](skills/zenwave-gate-check/SKILL.md) | gate | the checklist before tagging the baseline |
| [zenwave-implement-task](skills/zenwave-implement-task/SKILL.md) | AFK | one task, test first, focused tests only |
| [zenwave-review-slice](skills/zenwave-review-slice/SKILL.md) | AFK | one slice, full suite, model and standards axes |
| [zenwave-model-gap](skills/zenwave-model-gap/SKILL.md) | AFK, HITL | write a proposal instead of changing a model |

| In your project | What it is |
|---|---|
| `GLOSSARY.md`, `docs/adr/`, `docs/domain.md` | the language, the decisions, the domain summary |
| `docs/zenwave-sdd-overlay.md` | where the models are, the shape, the commands |
| `docs/tasks.md`, `docs/tasks/` | the board of the flow in progress, and the archived ones |
| `docs/proposals/` | model gaps waiting for, or with, your decision |
| `.zenwave/routing.md` | which worker and model take each kind of work, the limits, the protected files |
| `.zenwave/bin/` | the ZDL lint (`lint-zdl.sh`) and the board check (`check-board.sh`) |
| `.zenwave/work/`, `.zenwave/handoff/` | the orchestrator's clones, prompts, reports and logs (not committed) |

Licence: [MIT](LICENSE). The grilling skills include Matt Pocock's `grilling` skill verbatim, under its own MIT
licence ([templates/grilling/](templates/grilling/)).

Status: the skills and the orchestrator are new in this version and being validated on the Arcadia Editions and Pista
Aberta projects.
