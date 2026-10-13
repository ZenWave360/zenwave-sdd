# ZenWave SDD — Manual

From "we have ZFL flows and ZDL models" to "the flows work, are tested and are
tracked": create the project, generate its structure with the ZenWave SDK, then
drive the rest with the zenwave-sdd skills and GitHub Spec Kit. The manual covers
microservices (Kafka + AsyncAPI) and moduliths.

> **Status legend:** ✅ available now · 🧪 available, not yet validated on a real run ·
> 🛠 to build. Section 10 lists what's left to build and in what order.

---

## 1. The factory at a glance

```
 Event storming ─► ZFL flow ─► ZDL models ─► archetype ─► ZenWave SDK ─► generated structure
   (humans)       (business)   (zfl-to-zdl)  (new project) (zenwave-scripts.zw)      │
                                   ▲                                                 ▼
                                   │      ┌──────────────── zenwave-sdd ─────────────────┐
                                   │      │ 1 baseline  2 gap report  3 model loop ──────┼─┐
                                   └──────┼──────────────────────────── (fix ZDL, regen) ◄┘ │
                                          │ 4 test data  5 Spec Kit features  6 verify      │
                                          └─────────────────────────────────────────────────┘
```

| Layer | Owns | Changed by |
|---|---|---|
| **ZFL** | when/why: flow steps, outcomes, compensations, timers | humans (event storming) |
| **ZDL** | what: aggregates, lifecycle, commands, inputs/outputs, events, consumers, calls | humans + `zfl-to-zdl` |
| **ZenWave archetype + SDK** | the project skeleton, and the structure generated from the ZDL, including *generated-once* stubs with TODOs | archetype once, regeneration after model changes |
| **zenwave-sdd skills** | finding and filling the behavior the generator leaves blank | agents, following the skills |
| **Spec Kit** | the standard workflow and artifacts: `spec.md`, `plan.md`, `tasks.md`, converge | agents + humans |

**The rule that makes it work:** *models own structure.* If a behavior can't be
implemented without a new field, event, command or state, that is a **model gap**:
fix it in ZFL/ZDL and regenerate. Never hand-add it to code. The constitution
article in [speckit/constitution-zenwave.md](speckit/constitution-zenwave.md) states
this rule for Spec Kit.

### Gap report and Spec Kit: why both

- **The gap report is the ZenWave-specific analysis.** It traces ZFL ↔ ZDL ↔
  generated code and finds model gaps, crashing mappers, missing consumer wiring
  and unimplemented branches. No general-purpose tool can do that.
- **Spec Kit is the recognizable delivery shell.** `spec.md` / `plan.md` /
  `tasks.md`, a standard command sequence and a public catalog: a format other
  people and agents already know. That drives adoption.

Stock Spec Kit on its own re-invents the domain model from prose. The pilot showed
wrong casing, missing fields and an aggregate taken from another bounded context.
So the gap report feeds Spec Kit (research, clarifications, seed tasks), and the
constitution article stops Spec Kit from redesigning structure.

---

## 2. Deployment shapes

Choose the shape before writing ZDLs. The ZDL annotations, the generated code and
how you slice the work all depend on it.

| | **Microservices** (Kafka + AsyncAPI) | **Modulith** |
|---|---|---|
| Repos | one implementation repo per bounded context (plus its API/contract artifact) | one repo, one module per bounded context |
| ZDL consumer annotation | `@asyncapi(api: XApi, channel: "...")`, with `asyncapi client` in `apis` | `@listener(zdl: XZdl, event: ...)` / `@listener(event: ...)`, with `zdl client` in `apis` |
| Generated inbound code | developer-owned `*ConsumerService` adapters over AsyncAPI-generated consumer interfaces (Spring Cloud Stream) | `*EventsListener` classes with `@ApplicationModuleListener` |
| Contracts | ZDL → OpenAPI + AsyncAPI, versioned and released per service | ZDLs packaged together (e.g. `service-all`) |
| Synchronous calls (`@calls`) | HTTP client behind a port | the other module's service interface |
| Archetype features | `-Dkafka=true` | `-Dmodulith=true` (implies Kafka, for externalized events) |
| Spec Kit feature | this repo's slice of a flow (`NNN-<flow>`), linking to the flow | one per flow, one phase per bounded context |
| Flow tests | per-service consume/produce tests with an embedded or Testcontainers broker, then end-to-end in an environment | Spring Modulith `Scenario` in one JVM |

Record the shape in the project overlay (section 4.4). All the skills read it from there.

---

## 3. What you need

| Tool | Why | Install |
|---|---|---|
| JDK matching the generated project | build and tests | SDKMAN: `sdk install java 25.0.2-tem` |
| Maven | archetype, build | SDKMAN: `sdk install maven` |
| Docker | integration tests, DDL export, local Kafka | Docker Desktop / Rancher Desktop |
| JBang + ZenWave CLI (`jbang zw`) | generate, validate ZDL, dump the parsed model | see zenwave360.io |
| `uv` + Spec Kit CLI (`specify`) | Spec Kit workflow | `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git` |
| One or more agents | run the skills and the Spec Kit commands | Claude Code, Copilot, Codex, Gemini, Grok… (anything Spec Kit supports, see 4.3) |

### The skills (this repo)

| Skill | What it does | Writes | Status |
|---|---|---|---|
| [`zfl-to-zdl`](skills/zfl-to-zdl/SKILL.md) | ZFL flow → one ZDL per bounded context. Shape-aware (`@asyncapi` vs `@listener`), data-lineage check, `<Command>Result` wrapper for multi-response calls, org prefix from the overlay | ZDL | ✅ v1.4 used on Arcadia (modulith) · 🧪 v1.5 shape-aware |
| [`zenwave-gap-report`](skills/zenwave-gap-report/SKILL.md) | Audits generated code against ZFL/ZDL: model gaps, flow wiring, data lineage, service bodies, mappers, web layer, tests, open questions | report only (read-only on code) | 🧪 its procedure produced the Arcadia report; not yet run as a skill |
| [`zenwave-fill-gaps`](skills/zenwave-fill-gaps/SKILL.md) | Implements findings with ZenWave-aware patterns (load → guard → mutate → save → emit one event, result-wrapper branching, MapStruct constants, ports and stubs, idempotent consumers). Stops on model gaps | code | 🧪 not yet run as a skill |
| [`zenwave-test-data`](skills/zenwave-test-data/SKILL.md) | Exports the Hibernate DDL with a bundled script (no project config), then writes `data.sql` plus matching JSON fixtures: one consistent example per entity (basic, cheap) | test resources | 🧪 procedure run on Arcadia (Java: 7 rows, one chain) |
| [`zenwave-test-scenarios`](skills/zenwave-test-scenarios/SKILL.md) | Builds a coverage matrix from ZDL lifecycles, ZFL branches and outcomes, timers, redelivery and the read side (plus the gap report if present), then writes the same files with one chain per case, assumptions listed. Reuses zenwave-test-data's DDL export, formats and validation | test resources | 🧪 new; the Kotlin Arcadia fixtures (36 rows, 8 chains) are the reference result |

Project-specific knowledge (paths, shape, org prefix, build commands, decisions) goes
in a **project overlay**, not in the skills. Template:
[templates/project-overlay.md](templates/project-overlay.md).

---

## 4. Setting up a new project

### 4.1 Create the project with the ZenWave archetype ✅

There's one archetype for Kotlin (`zenwave-kotlin-archetype`) and one for Java.
Features: `jpa` or `mongodb` (exactly one), `kafka`, `modulith` (implies `kafka`).

```bash
mvn archetype:generate \
  -DarchetypeGroupId=io.zenwave360.archetypes \
  -DarchetypeArtifactId=zenwave-kotlin-archetype \
  -DarchetypeVersion=<version> \
  -DgroupId=com.example -DartifactId=orders-checkout-service \
  -Dpackage=com.example.orders.checkout -Dversion=0.0.1-SNAPSHOT \
  -DprojectName="Orders Checkout" -DprojectDescription="Orders Checkout" \
  -Djpa=true -Dkafka=true -Dmodulith=false \
  -DinteractiveMode=false
```

- Microservices: `-Dkafka=true -Dmodulith=false`. Modulith: `-Dmodulith=true`.
- Leave out the feature flags and use `-DinteractiveMode=true` to be asked instead.
- The project is git-initialized with an `Initial commit from archetype.` commit.
- To generate into the current folder, use `-DoutputDirectory=..` with
  `-DartifactId=<current folder name>`. The folder must not contain a `pom.xml`,
  `.gitignore` or `README.md`.

> Until the archetypes are on Maven Central, install them locally from
> `zenwave-playground/zenwave-{kotlin,java}-archetype-baseapp`:
> `./create-archetype.sh && (cd target/generated-sources/archetype && mvn clean install)`,
> then use `-DarchetypeVersion=0.0.1-SNAPSHOT`.

### 4.2 Generate the structure and commit the baseline ✅

Point `zenwave-scripts.zw` at your ZDL(s) and generate (ZenWave VS Code extension, or
`jbang zw`). Once it compiles:

```bash
git add -A && git commit -m "feat: generate backend from zenwave-sdk"
git tag zenwave-generated-v1          # what you diff against, and replay from
```

### 4.3 How Spec Kit and agents work together

This is the model to keep in mind:

- **Spec Kit doesn't ship an agent and doesn't require any particular one.**
  `specify init` installs Spec Kit's commands *for the agent(s) you choose*, in each
  agent's own format and folder (e.g. `.claude/skills/speckit-*`, `.github/…` for
  Copilot, `.agents/skills` for others). More than 50 agents are supported.
- **You run the agent, and the agent runs the commands.** You open your agent in the
  repo and invoke `/speckit-specify`, `/speckit-plan`… one at a time. The commands
  are prompt files. The agent reads and writes the artifacts, and runs Spec Kit's
  helper scripts. The `specify` CLI itself never calls an agent in this mode.
- **The artifacts are plain Markdown in the repo.** Everything lands in
  `specs/NNN-<feature>/` (`spec.md`, `plan.md`, `research.md`, `tasks.md`…) and
  `.specify/memory/constitution.md`. So **any agent can be pointed at them**, even
  one without Spec Kit installed: *"Implement the unchecked tasks in
  `specs/001-place-order-flow/tasks.md`, following the constitution, and tick each
  one when it's done."*
- **Several agents on one repo:** install more integrations and choose the default:

  ```bash
  specify init --here --integration claude --script sh    # first agent (--script ps on PowerShell)
  specify integration install copilot                      # add more
  specify integration install codex
  specify integration list
  specify integration use claude                           # set the default without uninstalling the others
  ```

  Commit the generated command folders so every teammate's agent has them.
- **When Spec Kit does call the agent: workflows.** `specify workflow run` executes a
  YAML workflow. Its `command` and `prompt` steps invoke a CLI agent headlessly, and
  **each step can name a different `integration`** (and `model`). Its `gate` steps
  pause for human approval. That's how you point *many* agents at one feature, e.g.
  Claude writes the spec and plan, a human approves, Codex implements:

  ```yaml
  # .specify/workflows/zenwave-flow/workflow.yml
  # Sketch: check the schema against the Spec Kit workflow reference for your version.
  schema_version: "1.0"
  workflow: { id: "zenwave-flow", name: "ZenWave flow feature", version: "0.1.0" }
  steps:
    - id: specify
      command: speckit.specify
      integration: claude
      input: { args: "{{ inputs.flow }}: behavior only, reference ZFL/ZDL names; findings in docs/zenwave-gap-report.md" }
    - id: clarify
      command: speckit.clarify
      integration: claude
    - id: review-spec
      type: gate
      message: "Resolve model gaps in ZDL (and regenerate) before planning."
      options: [approve, reject]
    - id: plan
      command: speckit.plan
      integration: claude
    - id: tasks
      command: speckit.tasks
      integration: claude
    - id: implement
      command: speckit.implement
      integration: codex
    - id: converge
      command: speckit.converge
      integration: claude
  ```

  ```bash
  specify workflow run zenwave-flow -i flow="PlaceOrderFlow from business-flows/place-order-flow.zfl"
  ```

  The built-in `speckit` workflow runs the full cycle with one integration:
  `specify workflow run speckit -i spec="…"`.

### 4.4 Install the skills and write the overlay ✅

Install **from a release**, not from someone's working copy. Pin a version:

```bash
ZWSDD=v0.1.0                                              # a zenwave-sdd release tag
tmp=$(mktemp -d) && git clone -q --depth 1 --branch $ZWSDD https://github.com/ZenWave360/zenwave-sdd "$tmp"
mkdir -p .claude/skills && cp -r "$tmp"/skills/* .claude/skills/         # Claude Code
# other agents: copy into their skills folder (e.g. .agents/skills/), or reference them from AGENTS.md
cp "$tmp"/templates/project-overlay.md docs/zenwave-sdd-overlay.md
cp "$tmp"/speckit/constitution-zenwave.md docs/
rm -rf "$tmp"
```

- Commit `.claude/skills/` (or your agent's folder) so the whole team gets the same version.
- In Claude Code, skills are available as `/zfl-to-zdl`, `/zenwave-gap-report`,
  `/zenwave-fill-gaps`, `/zenwave-test-data` and `/zenwave-test-scenarios`, and are also picked up
  automatically from their descriptions.
- Fill in `docs/zenwave-sdd-overlay.md` (shape, org prefix, paths, build and
  regenerate commands), then add to `AGENTS.md` / `CLAUDE.md`:
  `Before running any zenwave-* skill, read docs/zenwave-sdd-overlay.md.`

🛠 Later, `specify extension add zenwave` will do all of this as Spec Kit commands for
every installed integration (section 9).

### 4.5 Initialise Spec Kit and the constitution ✅

```bash
specify init --here --integration <agent> --script sh   # only adds .specify/ and the agent's commands
```

```text
/speckit-constitution Capture this project's existing practices (don't invent standards).
Include the article in docs/constitution-zenwave.md verbatim.
```

🛠 Later, the zenwave preset appends that article automatically, and overrides
`/speckit-plan` and `/speckit-tasks` (section 9). Until then, the article plus the
prompts in Step 5 give you the same behavior.

> Command names: skills-mode agents (Claude Code, Copilot…) show `/speckit-specify`.
> Other agents may show `/speckit.specify`. Same commands.

---

## 5. The workflow (after generation)

### Step 1 — Baseline health check ✅

```bash
mvn -DskipTests clean compile 2>&1 | tee target/compile.log
grep -i "unmapped target" target/compile.log               # objective list of mapper gaps
grep -rn "TODO CUSTOM_REQUIRED\|TODO: implement" src/main  # generated-once stubs
bash .claude/skills/zenwave-test-data/scripts/export-ddl.sh   # JPA: target/ddl/schema.sql
```

Does every entity have a table, and every ZDL field a column? A module whose ZDL
changed but whose tables and code didn't **wasn't regenerated**.

### Step 2 — Gap report 🧪

```text
/zenwave-gap-report
```

or, with any agent: *"Run the zenwave-gap-report skill for this repo, using
docs/zenwave-sdd-overlay.md. Read-only: do not edit src/."*

Output: `docs/zenwave-gap-report.md`. It contains model gaps (M-\*), a
traceability table per flow, code findings per bounded context (G-\*), baseline work
outside any flow, cross-cutting findings (X-\*), open questions (Q-\*), and a
suggested Spec Kit mapping. Commit it. Its diff across re-runs is your progress log.

### Step 3 — Model loop (repeat until there are no model gaps) ✅

For each model gap and open question, **you decide** (these are business
decisions), then:

1. Edit the ZFL/ZDL, following `zfl-to-zdl` and the naming conventions.
2. Validate each ZDL:

   ```bash
   jbang zw -p ZdlToJsonPlugin zdlFile=<file>.zdl > /dev/null
   ```

   - Syntax errors: `line L:C …` with exit code 1. Fix the first one; later ones
     are often cascades.
   - Semantic errors (unknown type, unknown event): `ZDL ERROR [path]: … [line, char]`
     **with exit code 0**, so read stderr.
   - `WARN … Unable to load referenced API`: a `zdl client` path is wrong, and
     cross-model checks were skipped.
   - Not checked today: `@transition` states missing from the lifecycle enum, and
     data lineage. See `zw lint` in section 9.
   - Dump the parsed model to see how a type resolved:
     `jbang zw -p ZdlToJsonPlugin zdlFile=<file>.zdl > model.json`.
3. Regenerate the OpenAPI/AsyncAPI declared in the ZDL, then the code
   (`zenwave-scripts.zw`). In microservices, release the new API/contract
   version first if other services consume it.
4. `git diff --stat`: check that **every** module whose ZDL changed has changes, and
   that customized generated-once files weren't overwritten (a forced `-f`
   regeneration overwrites them).
5. Re-run Steps 1 and 2. Update the "status after model pass N" table in the report.

Before any code is written, check each consumer's *data lineage*: every required
field of the target input must come from the triggering event (or AsyncAPI
message). On Arcadia, 8 of 11 listener mappings would have thrown a
`NullPointerException` on the first event, and every one was fixed in the model.

### Step 4 — Test data 🧪 (JPA)

```text
/zenwave-test-data
```

or: *"Regenerate data.sql and data/jpa/\*.json with the zenwave-test-data skill,
using docs/zenwave-sdd-overlay.md."* After a model change, refresh a basic set
with `zenwave-test-data`: keep existing chains and ids, add the new columns, and
add rows only for new entities. Refresh a scenario set with
`zenwave-test-scenarios`: keep its chains and ids, add the new columns, and add
coverage for new lifecycle states, branches and outcomes.

The skill runs `scripts/export-ddl.sh` itself. It boots one repository test with
the schema-generation settings as `-D` flags, so the project needs no DDL
configuration.

`zenwave-test-data` writes the **basic** set: one consistent example per entity,
enough for the repository tests and for loading the in-memory service tests. Before
writing service or flow tests, replace it with the **scenario** set:

```text
/zenwave-test-scenarios
```

It lists every case the tests need (each `@transition(from:)` state, each ZFL branch
and outcome, timers, redelivery, the statuses clients read), writes one chain per case,
and lists the assumptions it made for open questions. Run it after Step 2: it reads the
gap report's test-fixture finding and open questions when the report exists. Refresh
a scenario set with `zenwave-test-scenarios`, not `zenwave-test-data`, or the
scenario rows are lost.

### Step 5 — Implement through Spec Kit features 🧪

Features: one per flow (modulith), or this repo's slice of each flow (microservices),
plus `000-<bc>-baseline` for work outside any flow. For each feature, interactively
(or with the workflow in 4.3):

```text
/speckit-specify <FlowName> from <path>.zfl. Behavior only: reference ZFL steps and
ZDL elements by their exact names. The findings for this flow are in
docs/zenwave-gap-report.md.
```

```text
/speckit-clarify
```
Answer the remaining open questions (Q-\*). If an answer needs new structure, go back
to Step 3. Don't write the structure into the spec.

```text
/speckit-plan Structure is fixed by the ZDL and the generated code (constitution).
Do NOT write data-model.md or contracts/: add a "ZDL cross-reference" table
(element | file:line | used by) instead. Copy this flow's slice of
docs/zenwave-gap-report.md into research.md.
```

```text
/speckit-tasks Seed tasks from the gap-report findings for this flow, keeping their ids
(e.g. "T012 [G-OC-03] confirmOrder: load by orderId, guard, CONFIRMED, save, emit").
One phase per bounded context in flow order, then flow-level tests.
```

```text
/speckit-analyze
/speckit-implement Use the zenwave-fill-gaps skill for each task.
/speckit-converge
```

`/speckit-converge` only appends remediation tasks and never rewrites anything, so
it's safe to run after every implementation session and every regeneration.

### Step 6 — Verify and close ✅

`mvn test` should be green, apart from the known template issues in section 8. Then
re-run the gap report: the target is **zero blockers and zero majors** for the flow.
After that come manual and acceptance tests (Karate/HTTP files; in microservices,
also the end-to-end environment), and the merge.

### Step 7 — When the model changes later ✅ / 🛠

Edit ZFL/ZDL → validate → regenerate → Step 1 → gap report → refresh test data →
`/speckit-converge` on each affected feature (or a new feature for new behavior).
🛠 A scratch-regenerate-and-diff drift check wired into converge is planned.

---

## 6. Invocation cheat sheet

| I want to… | Claude Code (skills installed) | Any agent |
|---|---|---|
| ZFL → ZDL | `/zfl-to-zdl <flow.zfl>` | "Generate the ZDLs from <flow.zfl> with the zfl-to-zdl skill" |
| Validate a ZDL | `jbang zw -p ZdlToJsonPlugin zdlFile=<f>.zdl > /dev/null` | same |
| Find what's missing | `/zenwave-gap-report` | "Run zenwave-gap-report with the overlay" |
| Implement a finding | `/zenwave-fill-gaps G-OC-03` | "Implement G-OC-03 following zenwave-fill-gaps" |
| (Re)generate test data (basic) | `/zenwave-test-data` | "Regenerate test data with zenwave-test-data" |
| Generate scenario test data | `/zenwave-test-scenarios` | "Generate scenario fixtures with zenwave-test-scenarios" |
| Export the DDL only | `bash .claude/skills/zenwave-test-data/scripts/export-ddl.sh` | same |
| Spec a flow | `/speckit-specify …` (Step 5) | `/speckit.specify …` |
| Hand tasks to another agent | — | "Implement the unchecked tasks in specs/NNN-…/tasks.md" |
| Multi-agent pipeline | `specify workflow run zenwave-flow -i flow="…"` | same |
| Check drift | `/speckit-converge` | `/speckit.converge` |

---

## 7. Where the skills live, and releasing them

- **Working copy:** your clone of `zenwave-sdd`, where you develop the skills.
  Projects never reference it by path.
- **Release:** `github.com/ZenWave360/zenwave-sdd` (proposed). Tag semver releases
  (`v0.1.0`), keep a `CHANGELOG.md`, and bump each skill's `version:`
  frontmatter when it changes.
- **Projects:** install a pinned release (section 4.4) and commit the installed
  copy.

🛠 Target distribution, reaching every agent through Spec Kit:

```
zenwave-sdd/
├── skills/                      # source of truth (Agent Skills format)
├── speckit/
│   ├── constitution-zenwave.md  # ✅
│   ├── extension/               # 🛠 "zenwave" extension: commands generated from skills/,
│   │                            #    before_implement fence hook
│   ├── preset/                  # 🛠 "zenwave" preset: constitution (append),
│   │                            #    /plan and /tasks overrides (wrap)
│   └── workflows/zenwave-flow/  # 🛠 the multi-agent workflow from 4.3
├── templates/project-overlay.md
└── MANUAL.md
```

```bash
specify preset add --dev ./speckit/preset     # local try-out
specify extension add <zenwave extension>     # once packaged
```

To publish, attach the extension and preset to each release, then open PRs to Spec
Kit's community catalogs (`extensions/catalog.community.json`,
`presets/catalog.community.json`), following `EXTENSION-PUBLISHING-GUIDE.md` and
`presets/PUBLISHING.md`. The catalogs check format, not code. Keep the extension's
command files generated from `skills/*/SKILL.md`, so the two distributions can't
drift apart.

---

## 8. Known generator issues (check after every generation)

Found on Arcadia with zenwave-sdk 2.7.x Kotlin templates:

| Symptom | Cause | Workaround / fix |
|---|---|---|
| Testcontainers can't connect: database `DATABASENAME` doesn't exist | placeholder in `DockerComposeInitializer-jpa.java.hbs` | set the DB name in `DockerComposeInitializer` (reapply after a forced regeneration) |
| "Named arguments are prohibited for non-Kotlin functions" in the controller test | the template uses Kotlin named arguments on Java OpenAPI DTOs | use fluent setters |
| Repository `updateTest` fails for entities with `Instant` fields | asserts `assertEquals(Instant.now(), …)` | assert not-null / use a fixed instant |
| Fixture folders for embedded / non-aggregate types | the test-data template covered all entities | **being fixed in the SDK**; with older versions, delete them |
| OpenAPI `minLength: 1` on an array's item `$ref` | `X[] minlength(1)` maps to the wrong keyword | should be `minItems` on the array |
| Unimplemented methods emit **all** `withEvents` alternatives, and never load or save | expected: that's the generated-once TODO body | the gap report lists them; fill-gaps implements them |
| Mappers pass `null` into non-null Kotlin DTO parameters | unmapped fields (`Unmapped target` warnings) | fix the data lineage in the model, then `@Mapping` |

`data.sql`, the fixtures, `DockerComposeInitializer`, the `*Impl`, the listener /
consumer adapters and their `*MapStructMapper`s are **generated once**
(`skipOverwrite`). A normal regeneration keeps your edits, and a forced one (`-f`)
replaces them.

---

## 9. `jbang zw lint`

Implemented in **zenwave-sdk 2.8.0-SNAPSHOT** (`zenwave-sdk-cli` `lint` subcommand), with structured syntax diagnostics in **dsl-kotlin 1.10**. Overlay-shape contradiction and pluggable naming conventions remain out of this first cut.

`ZdlToJsonPlugin` is the parser entry point for generators, but it isn't a linter:
- file names are missing from syntax errors;
- one mistake cascades into false errors, and the output ends with a bare `null`;
- semantic errors exit with code 0;
- broken `zdl client` references only produce a WARN, which silently skips
  cross-model checks;
- some rules aren't checked at all.

So **yes, a lint command is worth it**, especially for agents and CI. It needs a
reliable exit code and machine-readable output. Suggested contract:

```bash
jbang zw lint <file-or-dir>... [--format text|json|sarif] [--output <file>] [--root <dir>] [--strict]
```

**Streams**
- **stdout** carries only the report: exactly one document per run, in the chosen
  format. With zero findings it's still a valid document (an empty `diagnostics` /
  `results` array), so consumers can always parse it.
- **stderr** carries everything else: logs, progress, jbang dependency resolution,
  fatal tool errors. The lint code never writes anything but the report to
  `System.out`.
- **`--output <file>`** writes the report as UTF-8 to a file instead of stdout.
  It's needed on Windows PowerShell 5.1, whose `>` writes UTF-16, and it fits CI
  upload steps such as GitHub's `upload-sarif`.

**Exit codes** (the same for every format)

| Code | Meaning |
|---|---|
| `0` | no failing findings |
| `1` | findings at error level, or warnings with `--strict` |
| `2` | the tool itself failed: bad arguments, unreadable file, internal error |

So CI can tell "the model is wrong" (1) apart from "lint broke" (2).

**Text** (default, for humans): `<file>:<line>:<col>: <severity> <ruleId> <message>`,
one per line, colored only when stdout is a terminal.

**JSON**: a versioned envelope, not a bare array, so fields can be added later.

```json
{
  "schemaVersion": "1",
  "tool": { "name": "zenwave-lint", "version": "2.8.0" },
  "summary": { "files": 6, "errors": 1, "warnings": 2 },
  "diagnostics": [
    {
      "file": "fulfillment-shipping-domain-model.zdl",
      "line": 28, "column": 16, "endLine": 28, "endColumn": 21,
      "severity": "error",
      "ruleId": "zdl.unknown-type",
      "message": "Strin is not a valid type",
      "modelPath": "entities.Fulfillment.fields.customerId.type"
    }
  ]
}
```

- `file`: relative to the working directory (or `--root`), with forward slashes.
- `line`, `column`, `endLine`, `endColumn`: **1-based**. `end*` are optional.
- `severity`: `error | warning | note`, the same levels as SARIF.
- `ruleId`: stable and namespaced (`zdl.syntax`, `zdl.unknown-type`,
  `zdl.unknown-event`, `zdl.unresolved-api`, `zdl.transition-state`,
  `zdl.data-lineage`…). Rule ids are never renamed; retired ones are left unused.
- `modelPath`: the model location (as in today's `ZDL ERROR [entities.…]`), so
  agents can find the element without parsing positions. Optional for syntax errors.
- Order: deterministic, by file, line, column, then rule id, so runs diff cleanly.

**SARIF 2.1.0**
- `$schema` and `version: "2.1.0"`, with one `run`.
- `tool.driver`: `name`, `version`, `informationUri`, and `rules[]`, each with
  `id`, `shortDescription`, `helpUri` and `defaultConfiguration.level`.
- Each result has `ruleId`, `ruleIndex`, `level` and `message.text`. Its location is
  `physicalLocation.artifactLocation` with a relative `uri` and `uriBaseId: "%SRCROOT%"`
  (declared in `run.originalUriBaseIds`), plus `region` with 1-based `startLine` /
  `startColumn` (and optional end positions).
- `partialFingerprints`: e.g. a hash of `ruleId` + `modelPath`. Code scanning uses
  them to track the same finding across commits when line numbers shift.
- Tool failures go in `invocations[0]` (`executionSuccessful: false` plus
  `toolExecutionNotifications`), with exit code 2.

**Positions:** normalize every source to 1-based. ANTLR's `charPositionInLine`
(today's `line 29:11`) is 0-based. Check the base of the semantic validator's
`char:` too. Otherwise IDE and code-scanning annotations land one character off.

| Rule | Level |
|---|---|
| syntax (stop at the first error per file, no cascade) | error |
| unknown types / events / inputs / outputs | error |
| `zdl client` / `asyncapi client` not resolvable | error |
| `@listener(zdl:, event:)` event missing in the referenced model; `@calls` target command missing | error |
| `@transition` state missing in the `@lifecycle` enum; `@lifecycle(initial:)` missing | error |
| `@asyncapi` and `@listener` mixed for the same event; style contradicts the overlay shape | warning |
| data lineage: a required input field of an event-triggered command is missing from the triggering event | warning |
| naming conventions (channel/topic/id formats) | warning (pluggable) |

It could reuse the diagnostics that `zenwave-lsp` already computes, so the CLI, the
IDE and agents report the same errors.

---

## 10. Build checklist (in order)

| # | Item | Why | Status |
|---|---|---|---|
| 1 | **Validate the skills on a replay.** Check out Arcadia at `zenwave-generated-v1` in a worktree, run `zenwave-gap-report`, compare it with the committed report, run `zenwave-fill-gaps` on a few findings, and `zenwave-test-data` end to end | the skills haven't run as skills | 🛠 |
| 2 | Pilot on a **microservice** (Kafka + AsyncAPI) project | the skills were derived from a modulith | 🛠 |
| 3 | Release `v0.1.0`: `version:` frontmatter, CHANGELOG, tag | installable by others | 🛠 |
| 4 | `jbang zw lint` (section 9): rules, stdout-only reports (text / JSON / SARIF 2.1.0), exit codes 0/1/2 | reliable model validation for agents and CI | ✅ 2.8.0-SNAPSHOT (overlay-shape and naming conventions still open) |
| 5 | SDK template fixes (section 8); embedded fixture folders are in progress | fewer gaps to find | 🛠 |
| 6 | Preset: constitution append + `/plan` and `/tasks` wraps | automates the Step 5 prompts | 🛠 |
| 7 | Extension: skill commands + `before_implement` fence hook (deny edits to regenerated files) | one-command install for every agent; mechanical guard | 🛠 |
| 8 | `zenwave-flow` workflow (4.3), validated against the Spec Kit workflow schema | multi-agent pipelines | 🛠 |
| 9 | Converge drift check: regenerate into a scratch folder, diff, append tasks | catches "model moved, code didn't" | 🛠 |
| 10 | Read `AI-MDE/spec-kit-preset-mde` before building 6–7 | closest existing model-driven preset | 🛠 |
| 11 | Archetypes on Maven Central | section 4.1 without a local build | 🛠 |
| 12 | Publish to the Spec Kit catalogs | adoption | 🛠 |

---

## 11. Arcadia as the worked example (modulith)

| Stage | Result |
|---|---|
| First gap report | 12 model gaps, 34 code gaps, 8 cross-cutting, 15 open questions. 8/11 listener mappings would crash on the first event |
| Model passes 1–2 | customer data snapshot at checkout, multi-line orders with one reservation per line, a `ReserveStockResult` wrapper, same-module `@listener`s, `releaseStock from [RESERVED, CONFIRMED]`, ZFL identity fixes |
| Test data | 7 scenario chains, 35 rows; `data.sql` and JSON identical |
| Implementation | done directly from the report (not yet through Spec Kit or fill-gaps) |

Files: `arcadia-editions-modulith-service-kotlin/docs/zenwave-gap-report.md`,
`arcadia-editions-architecture/skills/arcadia-zenwave-overlay.md`,
`research/spec-kit/` (Spec Kit research and the pilot).
