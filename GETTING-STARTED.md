# Getting started

How to take a project generated with the ZenWave archetype (or any ZenWave SDK project) from "structure generated" to "flows implemented and tested", step by step. Everything runs from the root of **your project**, not this repo. The same guide ships in the README of every project created from the ZenWave Java and Kotlin archetypes.

The generator creates the structure: entities, services, events, mappers and test skeletons. It leaves the behavior as `TODO`s. The [zenwave-sdd](https://github.com/ZenWave360/zenwave-sdd) skills find and fill those gaps, and [GitHub Spec Kit](https://github.com/github/spec-kit) gives the work a standard shape (`spec.md` → `plan.md` → `tasks.md`). Background and reasoning are in the [zenwave-sdd manual](MANUAL.md); this guide is enough to work.

One rule above all: **models own structure.** If a behavior needs a field, event, command or state that the ZDL doesn't have, fix the ZDL and regenerate. Never hand-add it to code.

**How to run a skill.** Open your AI agent in the root of this repo. In Claude Code and Grok, type `/skill-name`; in Codex, `$skill-name`. With any agent you can also write "run the zenwave-gap-report skill". Lines starting with `/` below are typed into the agent; everything in a `bash` block runs in Git Bash, from the root of this repo.

**The steps, in order:**

0. [One-time setup](#step-0--one-time-setup): skills, models, overlay, constitution
1. [Check the generated baseline](#step-1--check-the-generated-baseline)
2. [Generate basic test data](#step-2--generate-basic-test-data) (JPA)
3. [Run the gap report](#step-3--run-the-gap-report)
4. [Fix the model gaps](#step-4--fix-the-model-gaps-repeat-until-none-are-left) (repeat 1–4 until none are left)
5. [Generate scenario test data](#step-5--generate-scenario-test-data) (JPA)
6. [Spec and implement a flow](#step-6--spec-and-implement-a-flow)
7. [Verify and close](#step-7--verify-and-close)

## Step 0 — One-time setup

Do this once, after the first code generation has been committed.

### 0.1 Install the skills and Spec Kit

To upgrade later, run it again with a new `ZWSDD` tag and review the `git diff`.

```bash
ZWSDD=v0.1.0-rc1                                     # zenwave-sdd release tag
tmp=$(mktemp -d)
git clone -q --depth 1 --branch "$ZWSDD" https://github.com/ZenWave360/zenwave-sdd "$tmp"

# the same skills into each agent's folder (copies; symlinks are unreliable on Windows)
for dir in .claude/skills .agents/skills .grok/skills; do
  mkdir -p "$dir" && cp -r "$tmp"/skills/* "$dir"/
done

mkdir -p docs
[ -f docs/zenwave-sdd-overlay.md ] || cp "$tmp"/templates/project-overlay.md docs/zenwave-sdd-overlay.md   # never overwrite a filled-in overlay
cp "$tmp"/speckit/constitution-zenwave.md docs/
echo "$ZWSDD" > docs/zenwave-sdd.version
rm -rf "$tmp"

# Spec Kit, for every agent you use (claude is the default)
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify init --here --integration claude --script sh
specify integration install codex
specify integration install grok
specify integration use claude

# point every agent at the overlay
cat > AGENTS.md <<'EOF'
# Agent instructions
- Before running any zenwave-* skill, read docs/zenwave-sdd-overlay.md.
- Models own structure: never hand-edit generated structure. Never edit ZFL/ZDL: if a feature can't be implemented with the current models and generated structure, stop and hand it to a human with the finding, model lines and options (docs/constitution-zenwave.md).
- Spec Kit features live in specs/NNN-<feature>/; the constitution is .specify/memory/constitution.md.
EOF
printf '@AGENTS.md\n' > CLAUDE.md
```

### 0.2 Locate the models

The skills compare the code with two kinds of model:

- **ZFL business flows** (`*.zfl`): what happens, in which order, across bounded contexts. Usually in an architecture repo.
- **ZDL domain models** (`*.zdl`, one per bounded context): aggregates, commands, events, lifecycles. These are what `zenwave-scripts.zw` generates from.

Find out where yours are. Look at the `zdlFile` lines in `zenwave-scripts.zw`:

| `zenwave-scripts.zw` reads | Layout | What you need |
|---|---|---|
| `zdlFile "zenwave-model.zdl"` (the archetype default) | **in this repo** | nothing |
| `zdlFile "../<repo>/<file>.zdl"` | **sibling repo** | clone that repo next to this one (same parent folder) |
| `@import("<groupId>:<artifactId>:<version>")` and `zdlFile "classpath:/<folder>/<file>.zdl"` | **packaged jar** | the jar installed in `~/.m2` (from a release, or built locally from its repo); ideally its source repo cloned next to this one too, so you can read and edit the ZDLs |

The ZFL flows aren't read by the generator, so nothing above points to them: ask your architect, or look for an architecture repo with a `business-flows/` folder, and clone it next to this one.

Starting from a ZFL flow and no ZDL yet? Generate the ZDLs first, then point `zenwave-scripts.zw` at them and regenerate:

```text
/zfl-to-zdl <path/to/flow.zfl>
```

Check: every path you'll write in the overlay must list files.

```bash
ls <zfl-folder>/*.zfl
ls <zdl-folder>/*.zdl
ls ~/.m2/repository/<groupId as path>/<artifactId>/<version>/*.jar     # packaged jar layout only
```

### 0.3 Fill in the overlay

`docs/zenwave-sdd-overlay.md` (created from [templates/project-overlay.md](templates/project-overlay.md)) is how every skill finds the models and learns about this project. **The skills stop if it's incomplete.** Replace every `<placeholder>`, section by section:

| Section | What to write |
|---|---|
| *Where things are* | the ZFL and ZDL paths from 0.2, relative to this repo's root (`../<repo>/...` is fine); the OpenAPI/AsyncAPI files; for the packaged jar layout, the jar coordinates and the folder inside it |
| Packaged jar layout only | the command that extracts the ZDLs from the jar, a `diff` loop that checks them against the working copy, and the command that rebuilds the jar (see the template) |
| `@zdl(...)` paths | if the ZFL's `@zdl("...")` paths don't match where the ZDLs are in this deployment, a table from each `@zdl` path to its file |
| *Shape* | `microservices` (Kafka + AsyncAPI, ZDL consumers use `@asyncapi`) or `modulith` (in-process events, `@listener`); organization prefix; base and module packages; `jpa` or `mongodb` |
| *Build, generate, test* | the JDK, how to regenerate, the compile, lint and DDL export commands |
| *Project rules* | naming conventions, and decisions already taken. "None yet" is fine |

Check that no template placeholder is left. This must print nothing:

```bash
grep -nE '<(path|org|commands|jdk|Project|link|list|\.\.\.)>' docs/zenwave-sdd-overlay.md
```

### 0.4 Create the Spec Kit constitution

In the agent:

```text
/speckit-constitution Capture this project's existing practices (don't invent standards).
Include the article in docs/constitution-zenwave.md verbatim.
```

You get `.specify/memory/constitution.md`. Read it, then commit everything from Step 0:

```bash
git add .claude .agents .grok .specify docs AGENTS.md CLAUDE.md
git commit -m "chore: set up zenwave-sdd and Spec Kit"
```

## Step 1 — Check the generated baseline

Do this after every code generation. It shows whether the code matches the models, and lists the gaps the generator already knows about.

```bash
mvn -DskipTests clean compile 2>&1 | tee target/compile.log
grep -i "unmapped target" target/compile.log                  # mapper gaps
grep -rn "TODO CUSTOM_REQUIRED\|TODO: implement" src/main     # methods left for you
bash .claude/skills/zenwave-test-data/scripts/export-ddl.sh   # JPA only -> target/ddl/schema.sql
```

**Done when** the build succeeds and, with JPA, every entity in the ZDLs has a table in `target/ddl/schema.sql`. A module whose ZDL changed but whose code and tables didn't wasn't regenerated: regenerate with `zenwave-scripts.zw`.

## Step 2 — Generate basic test data

JPA only (skip with MongoDB).

```text
/zenwave-test-data
```

You get one valid example per entity in `src/test/resources/data.sql` (repository tests) and `src/test/resources/data/jpa/<Entity>/*.json` (in-memory service tests), consistent with each other.

**Done when** the skill reports both files loaded. Commit them.

## Step 3 — Run the gap report

Packaged jar layout only: first check that the jar matches the ZDLs you're reading, with the `diff` loop in the overlay. The code was generated from the jar, so a difference means you must regenerate first (Step 4, items 3–4).

Then, in the agent:

```text
/zenwave-gap-report
```

The report is read-only: it doesn't touch `src/`. You get `docs/zenwave-gap-report.md` with:

- **Model readiness** at the top: ⛔ NOT READY means the current models can't implement the flows, and no agentic implementation starts until you fix them (Step 4).
- **M-\*** model gaps: missing fields, events, commands or states. You fix them in the ZDL (Step 4).
- **Q-\*** open questions: business decisions only you can take.
- **G-\*** code gaps per bounded context, and **X-\*** cross-cutting ones. Fixed in Step 6.
- a traceability table per flow, and a suggested Spec Kit mapping.

Commit the report. Its diff across runs is your progress log.

## Step 4 — Fix the model gaps (repeat until none are left)

You do this step yourself. Agents never edit the ZFL/ZDL: when the report's **Model readiness** verdict is ⛔ NOT READY, or an agent finds mid-task that the models can't support a feature, the agent stops and hands the decision to you with the context.

For each M-\* and Q-\* in the report, decide the answer (they're business decisions), then:

1. **Edit the ZDL** (or the ZFL) where it lives (see the overlay). Never inside a jar.
2. **Lint the models.** Fix every error before going on:

   ```bash
   bash .claude/skills/zfl-to-zdl/scripts/lint-zdl.sh --strict <zdl-folder-or-files>
   ```

3. **Packaged jar layout only: rebuild and install the jar** with the command in the overlay. The generator only sees what's in it.
4. **Regenerate** with the plugins in `zenwave-scripts.zw` (IDE play buttons, or the `jbang zw -p <Plugin> ...` command each one shows on hover). Don't use `--force` unless you mean to overwrite files you've already edited.
5. **Review** with `git diff --stat`: every bounded context whose ZDL changed must have changes.
6. **Repeat Steps 1, 2 and 3.**

**Done when** the gap report has no M-\* left and every Q-\* that affects the model is answered.

## Step 5 — Generate scenario test data

JPA only, and only when you're about to write service or flow tests. It replaces the basic set from Step 2.

```text
/zenwave-test-scenarios
```

You get the same files as Step 2, but with a fixture chain for every case the tests need: each state a command starts from, each alternative and failure branch of the flow, each outcome. It reads the gap report's fixture findings and open questions, and lists the assumptions it made in `data.sql`.

From now on, refresh the data with `/zenwave-test-scenarios`, **never** `/zenwave-test-data`, or the scenario rows are lost.

## Step 6 — Spec and implement a flow

One Spec Kit feature per ZFL flow in a modulith (`NNN-<flow>`), or this repo's slice of each flow in microservices, plus `000-<bounded-context>-baseline` for gaps outside any flow. For each feature, type these into the agent in order, and read what each one writes before the next.

1. Specify:

   ```text
   /speckit-specify <FlowName> from <path/to/flow.zfl>.
   Behavior only: reference ZFL steps and ZDL elements by their exact names.
   The findings for this flow are in docs/zenwave-gap-report.md.
   ```

2. Clarify, and answer its questions. If an answer needs a new field, event or command, go back to Step 4. Don't write structure into the spec.

   ```text
   /speckit-clarify
   ```

3. Plan:

   ```text
   /speckit-plan Structure is fixed by the ZDL and the generated code (constitution).
   Do NOT write data-model.md or contracts/: add a "ZDL cross-reference" table
   (element | file:line | used by) instead. Copy this flow's slice of
   docs/zenwave-gap-report.md into research.md.
   ```

4. Break into tasks:

   ```text
   /speckit-tasks Seed tasks from the gap-report findings for this flow, keeping their ids
   (e.g. "T012 [G-OC-03] confirmOrder: load by orderId, guard, CONFIRMED, save, emit").
   One phase per bounded context in flow order, then flow-level tests.
   ```

5. Check, implement, and look for anything left:

   ```text
   /speckit-analyze
   /speckit-implement Use the zenwave-fill-gaps skill for each task.
   /speckit-converge
   ```

You get `specs/NNN-<flow>/` (`spec.md`, `plan.md`, `tasks.md`), and the code and tests. `/speckit-converge` only adds tasks for what's still missing, so it's safe to run after every session.

To fix a single finding without Spec Kit: `/zenwave-fill-gaps <finding-id>`.

## Step 7 — Verify and close

```bash
mvn test
```

Then run `/zenwave-gap-report` again. **Done when** `mvn test` is green and the report has no blockers or majors left for the flow. Commit, then do the manual and acceptance tests.

## Later: when the models change

Step 4 (edit, lint, rebuild the jar if any, regenerate, review) → Step 1 → Step 2 (or `/zenwave-test-scenarios` if you already have scenario data) → Step 3 → `/speckit-converge` on each affected feature, or a new feature for new behavior.

## If something goes wrong

| Symptom | Cause and fix |
|---|---|
| A skill says it can't find the ZFL or ZDL files | A repo isn't cloned where the overlay says, or the overlay paths are wrong. Redo [0.2](#02-locate-the-models) and [0.3](#03-fill-in-the-overlay). |
| A skill stops because the overlay is incomplete | The placeholder check in [0.3](#03-fill-in-the-overlay) prints something. Fill those lines in. |
| The gap report lists gaps you already fixed in the ZDL | You didn't regenerate, or (packaged jar layout) the jar is stale. Redo Step 4, items 3–4. |
| Generation fails on `@import("...")` | The jar isn't in `~/.m2`. Install it (overlay, *Build, generate, test*). |
| Your edits to a service or test disappeared after regenerating | A plugin ran with `--force`. Restore them with `git checkout -p`. |
| Scenario fixtures were replaced by one row per entity | `/zenwave-test-data` was run after `/zenwave-test-scenarios`. Restore with git, or run `/zenwave-test-scenarios` again. |
