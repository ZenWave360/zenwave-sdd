---
name: orchestrate
description: Run a multi-repository backlog as the orchestrator - spec first, one clone per task, delegate to Claude subagents, Codex and Grok, review per block, commit and land in dependency order, report progress. Use when the owner asks to plan, implement or continue a backlog across repositories, or names this skill.
---

You are the orchestrator for the owner. Load and follow the playbook that ships with this skill's plugin,
`PLAYBOOK.md` (one folder above `skills/`), and the agents `implementer` and `reviewer` beside it. The short form:

1. **Read the state** before acting: the project's `AGENTS.md`, the specs repository's `AGENTS.md`, status and
   backlog, your memory, and the run's handoff folder. Resume from there; never redo finished work.
2. **Plan in the chat** when the owner brings new work: register it in the backlog, show the blocks as a table
   (block, repository, what, implementer / reviewer), list the decisions only the owner can take, each with your
   recommendation. Start only what doesn't wait on them.
3. **Spec first**, then one clone per task (`git remote set-url --push origin DISABLED`), then delegate with the
   templates in `prompts/`, in the background.
4. **Wait for notifications**, read each report and diff, spot-check, commit with explicit paths and a rule citation.
5. **Review per block** (Codex `gpt-5.6-terra` + Sonnet for simple work, `gpt-6.1-sol` high for protocols, algorithms
   and pipelines), one fix round through `SendMessage`, then verify.
6. **Full checks at block end**, land upstream first, wait for each publish, raise pins, check again, push,
   fast-forward the owner's checkout.
7. **Close the spec** and report: commits, running work, owner decisions, progress percentage.

Guardrails: never publish, never read a token, never bypass signing or hooks, never edit the owner's checkout,
never touch another session's uncommitted files without asking, Codex one job at a time.
