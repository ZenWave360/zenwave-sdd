# Orchestration playbook

How one Claude Code session runs a multi-repository backlog for its owner, using Claude subagents, the Codex CLI
and the Grok CLI as workers. This is the method that ran ZenWave's EventFlow, release and lanes work in
November 2026. It is written to be reused in other projects: replace the ZenWave names with yours.

## 1. Roles

| Role | Who | Does | Never does |
| --- | --- | --- | --- |
| **Owner** | the person | decides product questions, holds every credential, turns publication on | is asked for a fact the orchestrator can look up |
| **Orchestrator** | the main Claude Code session (Opus) | plans, writes specs, slices work, writes the prompts, reads every report and diff, commits, merges, pushes where allowed, reports progress | writes large product changes itself, publishes, reads tokens |
| **Implementer** | a Claude subagent (Sonnet), or Codex, or Grok | one scoped step in one clone, with its tests | commits, pushes, touches the specs or other repositories |
| **Reviewer** | Codex (`gpt-5.6-terra` or `gpt-6.1-sol`), or a Claude `reviewer` subagent | reads the diff against the rules, reports findings by severity | edits anything but its report |

The orchestrator is the only one who commits. Workers leave their changes in the working tree; the orchestrator
looks at them, stages explicit paths and makes a signed commit. That keeps one author, one signing key and one
place where "done" is decided.

## 2. The loop for a block of work

A **block** is 3 to 6 tasks, or one capability across repositories.

1. **Spec first.** Write or amend the rule in the specs repository, mark it *proposed*, commit it. If a question
   changes what a user notices and the owner has not answered it, ask; otherwise decide and record why.
   Record owner decisions verbatim in the spec, with the date.
2. **Clone per task.** `git clone --branch develop <url> <work>/<task>`, then
   `git remote set-url --push origin DISABLED` and a feature branch. A worker can never push, and two workers never
   share a checkout. The owner's own checkout is never edited: it is fast-forwarded with `git pull --ff-only`.
3. **Delegate in layers.** Upstream first: the library, then the server, then the UI, then the host. Each
   layer's report gives the exact API or wire shape the next prompt quotes. Independent layers run in parallel
   (for example the page and the host against an agreed message shape).
4. **Prompt.** Every prompt names: the clone and branch, the rule ids and where they are, the decisions that
   override older analysis, what is out of scope, "do not commit", the commands to run, the environment quirks
   (JDK, env vars), and the report shape. See [prompts/](prompts/).
5. **Wait, don't poll.** Background jobs notify on completion (section 5).
6. **Read the report, then the diff.** "Done" from an agent is not evidence. Check `git status`, stage only real
   changes (`git diff --ignore-cr-at-eol --numstat`), spot-check the risky part yourself (a quick script against the
   new function is often enough), then commit with a message that cites the rule: `spec:<doc>#<id>`.
7. **Review the block.** One review per block, by a different agent from the implementer. Routing in section 4.
   Send confirmed findings back to the *same* implementer (it keeps its context: `SendMessage` to a Claude
   subagent), one fix round, then verify. A third round means the design is wrong: decide it yourself and simplify.
8. **Full checks once, at block end.** Unit tests, typecheck, lint, build, packaged smoke tests. A flaky smoke is run
   once more and reported as flaky, never hidden.
9. **Land in order.** Push the upstream repository, wait for its CI to publish, then the next. Raise pins, run the
   checks again on the final dependency versions, push, watch CI, fast-forward the owner's checkout.
10. **Close the spec.** Flip the rule to *exists* (or *partial* with what is missing), tick the backlog with the
    commits and the check results, and say what only a person or a hosted run can verify.

## 3. Commits, pushes and guardrails

- Signed commits, no attribution lines, never `--no-verify`, never bypass signing. If the GPG agent lost its cache
  (after a reboot), ask the owner to unlock it.
- Stage explicit paths. Leave untracked files you did not make (`.sdkmanrc`, `.serena/`, stack dumps) alone.
- Never stash, reset or discard work you did not make. Another session's uncommitted files in a shared checkout are
  theirs: commit around them with explicit paths, and ask before committing them.
- Push only where the owner has allowed it (here: `develop`, which publishes only previews). Never publish to a
  marketplace or registry yourself. Publication is behind repository variables the owner sets
  (`ZENWAVE_PUBLISH_PRERELEASE`, `ZENWAVE_RELEASE_ON_MAIN`): build every release workflow with such a switch, off.
- Tokens are the owner's: give them the `gh secret set` command, never read, print or store a value.
- Ask before killing a process you did not start, before deleting a branch or directory, and before anything
  destructive. Delete your own leftovers once the owner agrees.

## 4. Routing work between agents

The owner sets the shares (for example "30 % implementation each to Sonnet, Codex and Grok; reviews 50 % Sonnet,
50 % Codex") and can change them at any time. Within that:

| Work | Goes to | Why |
| --- | --- | --- |
| Anything that needs Java/Gradle | Sonnet (Claude subagent) | Codex's sandbox could not start the JDK |
| Node/TypeScript UI and tooling | Codex `gpt-6.1-sol`, or Sonnet | Codex runs Node fine |
| Simple, mechanical edits | Grok, or Codex `gpt-5.6-terra` | cheapest |
| Review, simple task | Codex `gpt-5.6-terra` + a Sonnet `reviewer` | |
| Review, advanced task (cross-repo protocol, layout algorithms, path/variant logic, release pipelines) | Codex `gpt-6.1-sol`, effort high | it found the blocking bugs every time |
| When Codex is out of quota | the same work to Sonnet | don't wait hours for a reset |

Pace Codex: **one job at a time**. Parallel Codex jobs hit the plan limit and the recovery wastes tokens.
Claude subagents can run in parallel, one per clone.

## 5. Starting workers and waiting for them

All workers are started in the background, and the orchestrator is notified when each one finishes. It never
sleeps or polls in a loop.

| Worker | Start | Wait | Continue it |
| --- | --- | --- | --- |
| Claude subagent | `Agent` tool, `subagent_type: implementer` or `reviewer`, `run_in_background: true` | completion notification with its final report | `SendMessage` to its id: it resumes with its whole context, ideal for fix rounds |
| Codex | `tools/codex-task.ps1` from the **PowerShell tool**, `run_in_background: true` | completion notification; then read the `-Summary` file | a new task with a "verify the rework" prompt that points at the previous report |
| Grok | `grok -p "<prompt>" --cwd <clone> --model grok-4.7 --reasoning-effort high --output-format json`, in the background | completion notification | `grok -c` continues the last session |
| GitHub Actions | `gh run watch <id> --exit-status`, in the background | completion notification | `gh run rerun <id> --failed` for a transient failure |

If a wait has no notification behind it (an external system), schedule one wakeup at a sensible interval as a
fallback, not a polling loop. Keep the JSON event streams in log files, never in the conversation.

## 6. When an agent runs out of quota or context

- **Codex usage limit:** `codex-task.ps1` records the reset time, sleeps until then, probes with a one-word prompt,
  and then either resumes the same thread (if it was short, at most 80 items) or starts a fresh session with a
  handoff prompt it builds locally, with no model tokens: the original task, `git status`, `git diff --stat` and
  the last agent message. A context-window failure gets one handoff. If the wait is long, stop the job, check the
  clone is untouched, and give the task to Sonnet.
- **Claude subagent:** it ends with a report; if it stopped early, `SendMessage` it to continue. Its transcript is
  never read into the orchestrator's context.
- **The orchestrator itself:** Claude Code compacts the conversation into a summary and continues. What must
  survive compaction lives on disk: the memory directory (owner preferences and routing rules), the specs and
  backlog (what is decided and done), and the handoff folder (prompts, reports, task state). Write those as you go,
  so a fresh session can resume from files alone.

## 7. Talking to the owner

- Reply in the owner's language; documents follow their repository's language.
- Every reply that ends a step says what landed (commits), what is running, what is blocked on the owner, and a
  progress percentage.
- Ask only for decisions. Put each choice with a recommendation, and say plainly what you will do by default.
- When the owner's message is ambiguous, state your reading in one line and proceed; they correct you.
- Report failures as failures, with the output, and say what was not run.

## 8. What went wrong and is now a rule

- A Codex job "FAILED" with a perfect run: `-Summary` was a sentence, not a path.
- Codex failed to start with relative `-Cwd`/`-AddDir`, and `powershell -File` from Git Bash is blocked by the
  execution policy: use absolute paths and the PowerShell tool.
- Codex edited the specs repository uninvited: say "do not touch zenwave-specs" in every prompt.
- Unit-tested-only branches merged without the packaged smoke broke the preview: never merge without it.
- A release workflow that would have tagged and released on the first merge to `main`: every publishing path gets
  an owner-controlled switch, off by default.
- A reusable workflow call kept `GITHUB_REF=main`, so a tag-only environment would have refused it: dispatch the
  workflow on the tag instead. Ask the advanced reviewer about GitHub semantics explicitly.
- A gate that waited for "the last release to finish" could block forever after a failed release: prefer gates on
  *running* work, and let failed work be abandoned.
