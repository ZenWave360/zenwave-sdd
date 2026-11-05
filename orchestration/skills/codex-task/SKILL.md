---
name: codex-task
description: Start a Codex CLI job (implementation or review) through codex-task.ps1, wait for it in the background, read its report, and recover it after a usage limit. Use whenever work is routed to Codex.
---

1. Write the prompt to a file in the run's handoff folder, from `prompts/` of this plugin. Absolute paths everywhere.
2. Start it from the **PowerShell** tool (not `powershell -File` from Git Bash: the execution policy blocks it),
   with `run_in_background: true`:

   ```powershell
   $env:AGENT_HANDOFF_DIR = '<absolute handoff folder>'
   & '<plugin>/tools/codex-task.ps1' -Name <new-unique-name> -Cwd <abs clone> -AddDir <abs dir1>,<abs dir2> `
     -PromptFile <abs prompt.md> -Summary <abs report.md> -Model gpt-5.6-terra -Effort medium
   ```

   Reviews of advanced work: `-Model gpt-6.1-sol -Effort high`. One Codex job at a time.
3. Check it started: `<handoff>/codex-tasks/<name>.json` has `"status": "RUNNING"`. `FAILED` within seconds means a
   bad path: read `<name>-1.jsonl.stderr`.
4. Wait for the completion notification. Then read the `-Summary` file. The script prints
   `<name> DONE|FAILED|WAITING_FOR_QUOTA|NEEDS_HANDOFF`.
5. `WAITING_FOR_QUOTA`: the script sleeps until the reset and resumes by itself. If the wait is hours, stop the
   background task, check the clone is untouched (`git status`), and give the task to a Claude implementer instead.
   Later, `-Recover -Name <name>` resumes it.
6. Codex leaves changes uncommitted: review the diff and commit yourself.

Codex's sandbox could not start Java: give it no Gradle work; for Gradle repositories use it read-only.
