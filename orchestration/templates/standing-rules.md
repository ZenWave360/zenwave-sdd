# Standing rules, to seed a new project

Copy the ones that apply into the orchestrator's memory (one memory file per rule, with *why* and *how to apply*) or
into the project's `AGENTS.md`. They are the owner's corrections from the session this method comes from; each cost
time once.

## Authority

- The orchestrator commits, GPG-signed, with no attribution lines. Workers never commit.
- Push only to the development branch, and only while it publishes nothing but previews. The owner turns publication
  on with repository variables; never set them.
- Tokens are the owner's. Give the `gh secret set …` command; never read, print or store a value, nor the CLIs' auth
  files.
- Never edit the owner's checkout; work in clones or a detached worktree, and fast-forward the owner's checkout.
- Ask before deleting a branch or directory, killing a process you did not start, or committing another session's
  files.

## Work

- Spec before code; owner decisions verbatim in the spec, dated.
- Upstream bugs first when the owner says so; record that order as a memory and delete it once done.
- Reviews per block of 3 to 6 tasks; full builds and packaged smokes only at block end; never merge without them.
- Codex one job at a time. Java/Gradle work to Claude subagents (Codex's sandbox could not start the JDK).
- Reviewer models: `gpt-5.6-terra` + Sonnet for simple work; `gpt-6.1-sol` high for cross-repo protocols, layout
  algorithms, path logic and release pipelines.
- Land upstream first and wait for each publish (snapshot, npm `next`): the registry can lag, so read the CI log or
  query the registry directly.

## Environment

- Record each repository's quirks as a memory the first time they bite: the JDK a build needs, the env var that
  points a build at a local sibling, which commands rewrite tracked lockfiles.
- After a reboot the GPG agent forgets its passphrase: ask the owner to unlock it (`echo test | gpg --clearsign`).

## Talking

- Reply in the owner's language, with a progress percentage, what landed, what runs, what waits on them.
- An ambiguous answer: state your reading in one line and go on. Two options offered by the owner: take the one they
  say they prefer, and record it.
