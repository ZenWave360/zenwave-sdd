# Harnesses: Claude Code, Codex and Grok

What each tool needs installed, how the orchestrator calls it, and whether its agents or skills have to be
installed there too. Versions this was run with: Claude Code 2.1.195, codex-cli 0.166.0, grok 1.0.70.

## Do the other harnesses need subagents installed?

No. The orchestrator is always Claude Code. Codex and Grok are called as command-line programs with a complete
prompt each time, so they need no agent definitions: the role lives in the prompt templates in
[prompts/](prompts/). What they do need is the project's instructions file, which both read on their own:
`AGENTS.md` at the repository root. Claude Code reads `CLAUDE.md`, so make it one line: `See [AGENTS.md](AGENTS.md).`

Installing the same skills in every harness is still worth it for skills that the *worker* should apply while
coding (a domain-modeling or test-writing skill, say). Skills that run the process, such as `orchestrate`, only
matter to Claude Code.

| Harness | Project instructions | Skills folder (project / user) | Its own subagents |
| --- | --- | --- | --- |
| Claude Code | `CLAUDE.md` → `AGENTS.md` | `.claude/skills/` / `~/.claude/skills/`, or a plugin | `.claude/agents/*.md`, or a plugin |
| Codex | `AGENTS.md` | `.agents/skills/` / `~/.codex/skills/` | not used here |
| Grok | `AGENTS.md` | `~/.grok/skills/` | `--agent <file>` or `--agents <json>`, optional |

The `npx skills` installer (it writes `skills-lock.json`) puts skills in `.agents/skills/`; link them into
`.claude/skills/` so Claude Code sees the same copy (that is how `grill-with-docs` is installed in
`zenwave-platform-vscode`).

## Claude Code

**Install the agents and skills** either per project, by copying [agents/](agents/) to `.claude/agents/` and
[skills/](skills/) to `.claude/skills/`, or once as a plugin from this repository:

```text
/plugin marketplace add ZenWave360/zenwave-sdd
/plugin install zenwave-orchestration@zenwave-sdd
```

**Start the orchestrator** as the main session. Either open Claude Code in the project and say what to run (the
session that wrote this playbook did that, in the VS Code extension), or start it with the agent definition:

```bash
claude --agent orchestrator --add-dir ../other-repo --add-dir ../specs
```

Give it every sibling repository with `--add-dir` (or `/add-dir`), or it cannot read them.

**Start a worker** with the `Agent` tool: `subagent_type: "implementer"` (or `"reviewer"`), a self-contained
prompt, `run_in_background: true`. The worker cannot see the conversation: everything it needs is in the prompt.
When it finishes, its report arrives as a message. To continue it, for a fix round, `SendMessage` to its id: it
resumes with its context, which is much cheaper than a new agent.

**Wait** with background commands (`run_in_background: true`) and their completion notifications. `sleep` is
blocked; a single `ScheduleWakeup` is the fallback when nothing will notify.

**Permissions.** Auto mode's classifier may refuse to start another agent with "approve everything" flags
(`grok --always-approve`, `codex --dangerously-bypass-approvals-and-sandbox`). Don't work around it: run the
worker in a sandbox profile, add an explicit permission rule, or have the owner start it.

## Codex

**Install:** `npm i -g @openai/codex`, then `codex login`. Nothing else: no agents, no skills required.

**Run a task** through [tools/codex-task.ps1](tools/codex-task.ps1), from Claude Code's PowerShell tool, in the
background:

```powershell
& .\orchestration\tools\codex-task.ps1 -Name lanes-page `
  -Cwd C:\work\vistas-lanes -AddDir C:\work\specs,C:\work\dsl-lanes `
  -PromptFile C:\work\.handoff\lanes-page-prompt.md `
  -Summary C:\work\.handoff\lanes-page-report.md `
  -Model gpt-6.1-sol -Effort high
```

- Paths absolute. `-Summary` is a file path: Codex writes its final message there, and the task is only `DONE` if
  the file exists. `-AddDir` gives read access to sibling repositories (the specs, an upstream clone).
- `-Name` must be new, or a `FAILED` one. State and event logs go to `$env:AGENT_HANDOFF_DIR\codex-tasks`.
- `-Recover -Name <n>` resumes a task that stopped at a usage limit.

What the script runs underneath:

```bash
codex exec -C <clone> --add-dir <dir> --model gpt-5.6-terra --config 'model_reasoning_effort="medium"' \
  --approve-for-me --json --output-last-message <report.md> - < prompt.md
```

**Codex reviews** are read-only by prompt: "Do not modify any file, do not commit; write nothing except your final
report." Its sandbox could not start Java, so tell it not to run Gradle and review by reading.

## Grok

**Install** from x.ai, then log in; the auth file is the owner's and is never read.

```bash
grok -p "$(cat prompt.md)" --cwd <clone> --model grok-4.7 --reasoning-effort high --output-format json > grok.log
```

`--always-approve` has no sandbox: use it only in a clone whose push URL is `DISABLED`, or with
`--sandbox <profile>`. `--worktree` starts it in a fresh git worktree. Grok can define its own subagents
(`--agents '<json>'`), not needed here.

## Third-party skills: Matt Pocock's grill-with-docs

`grill-with-docs` is an interview that sharpens a plan and writes the docs (ADRs, glossary) as it goes. It is from
[mattpocock/skills](https://github.com/mattpocock/skills). Install it with the `skills` CLI, which works for every
harness above:

```bash
npx skills add mattpocock/skills --skill grill-with-docs grilling domain-modeling setup-matt-pocock-skills
```

`--list` shows what the repository offers, `-a <agent>` picks the harnesses (`'*'` for all), `-g` installs for the
user instead of the project. Where the installer did not link them, link the Claude copies
(`.claude/skills/<name>` → `.agents/skills/<name>`), and run `/setup-matt-pocock-skills`
once per repository: it records where the issue tracker, the glossary and the ADRs live.

`grill-with-docs` is only two lines: "call the `grilling` and `domain-modeling` skills". **Install
`domain-modeling` too**: `zenwave-platform-vscode` has `grilling` and `grill-with-docs` but not `domain-modeling`, so
there it grills and writes no docs. In a ZenWave project, point its ADRs at the specs repository's `decisions/` and
its glossary at `architecture/glossary.md`.

The skills are not copied into this repository: install them from their source, so updates and the licence stay
with their author.

## Extending this further

- **A Claude Code plugin** (this repository is one, see [README](README.md)) bundles agents, skills, slash commands
  and hooks, and installs in one command in any project. Add commands under `orchestration/commands/` and hooks in
  `orchestration/hooks/hooks.json` when a step should run automatically.
- **Memory:** Claude Code keeps per-project memory files; seed a new project with the standing rules of
  [templates/standing-rules.md](templates/standing-rules.md) and let it grow.
- **Codex and Grok** take plugins and skills of their own; keep their roles in the prompt templates, so one change
  reaches all three.
