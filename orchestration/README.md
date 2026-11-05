# Orchestration

How to run a multi-repository backlog with one Claude Code session as the orchestrator, Claude subagents, Codex and
Grok as implementers, and Codex or Claude as reviewers. It is the method that built ZenWave's EventFlow, release and
lanes work, packaged so another project can start with it in minutes.

| File | What it is |
| --- | --- |
| [PLAYBOOK.md](PLAYBOOK.md) | the method: roles, the block loop, routing, waiting, quota recovery, guardrails, lessons |
| [HARNESSES.md](HARNESSES.md) | Claude Code, Codex and Grok: install, invoke, wait, continue; third-party skills such as Matt Pocock's `grill-with-docs` |
| [agents/](agents/) | `orchestrator`, `implementer`, `reviewer` as Claude Code agent definitions |
| [skills/](skills/) | `orchestrate` (run the playbook) and `codex-task` (start and recover a Codex job) |
| [prompts/](prompts/) | prompt templates for implement, review, verify-fix and fix rounds, for any harness |
| [tools/codex-task.ps1](tools/codex-task.ps1) | runs one Codex job, records its state, waits out usage limits, resumes or hands off |
| [templates/standing-rules.md](templates/standing-rules.md) | the owner's standing rules, to seed memory or `AGENTS.md` |

## Start in a new project

1. **Install the Claude Code plugin** (agents and skills), once per machine:

   ```text
   /plugin marketplace add ZenWave360/zenwave-sdd
   /plugin install zenwave-orchestration@zenwave-sdd
   ```

   Or copy `agents/` to `.claude/agents/` and `skills/` to `.claude/skills/` in the project.
2. **Install the workers' CLIs** you will route to: `npm i -g @openai/codex` and `codex login`; Grok from x.ai. They
   need no agents or skills: their role is in each prompt.
3. **Lay out the workspace**: the repositories side by side, a specs repository (rules with ids, decisions, a
   backlog), a `work/` folder for clones and a `.handoff/` folder for prompts, reports and Codex task state
   (`AGENT_HANDOFF_DIR`).
4. **Give every repository an `AGENTS.md`**, and a `CLAUDE.md` that says `See [AGENTS.md](AGENTS.md).`
5. **Seed the rules**: tell the session which of [standing-rules.md](templates/standing-rules.md) apply, and the
   routing shares ("implementation 40 % Sonnet, 40 % Codex, 20 % Grok; reviews half Codex, half Sonnet").
6. **Start**: `claude --agent orchestrator --add-dir ../repo-a --add-dir ../specs`, or open Claude Code and say
   "use the orchestrate skill: plan <the work> in the chat". Optionally grill the plan first with `grill-with-docs`.

## What the owner does

Decides product questions, holds the credentials, sets the routing shares, turns publication on, and runs the checks
only a person can (a real IDE, a marketplace account, a visual judgement). Everything else, including looking up
facts, is the orchestrator's.
