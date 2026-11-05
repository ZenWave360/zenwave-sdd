# Prompt templates

Each worker gets one self-contained prompt file, written by the orchestrator into the run's handoff folder
(`.handoff/<run>/`) and passed to the worker as is. Fill the `<…>` parts. The same text works for a Claude
subagent (as the `Agent` prompt), Codex (`-PromptFile`) and Grok (`--prompt-file`).

| File | Use |
| --- | --- |
| [implement.md](implement.md) | one step in one clone |
| [review.md](review.md) | a block review of the last commit(s) |
| [verify-fix.md](verify-fix.md) | check that a fix round resolved the previous report |
| [fix-round.md](fix-round.md) | findings sent back to the implementer that did the work |

Lessons that are in every template on purpose: absolute paths; "do not commit"; "do not touch the specs";
the environment quirks (JDK, env vars, no Gradle in Codex's sandbox); the decisions that override older analysis;
the exact report shape; and, for reviews, the questions you are most worried about, named one by one.
