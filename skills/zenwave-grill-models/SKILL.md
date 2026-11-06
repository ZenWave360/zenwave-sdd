---
name: zenwave-grill-models
description: Challenge the ZFL flows and ZDL models of a project before they are approved - lint and identity checks, then a hunt for contradictions, missing correlations and lineage, events nobody handles, branches with no end, uncompensated side effects, timers with no stop, glossary drift and ADR conflicts - and grill the person on each, round by round, until every open decision is taken. Use in the HITL loop after drafting or changing models, before generating test data and the board, and to resolve a model gap proposal (docs/proposals/P-xx.md).
---

# Grill the models

Agents are good at holding every model in context at once and finding what does not add up. People are good at
deciding what the business wants. This skill does the first and asks the second.

Follow [grilling.md](references/grilling.md) for how to ask. Write in the person's language.

**Who edits.** The person decides every change. An agent edits a ZFL or ZDL file only when the person asks for that
change in this session; otherwise it lists the change for them. Never in the AFK loop.

## 1. Inputs

From the project overlay (`docs/zenwave-sdd-overlay.md`) or the repository: the ZFL flows, the ZDL of each bounded
context, the API contracts, `GLOSSARY.md`, `docs/adr/`, `docs/domain.md`, and the open proposals in
`docs/proposals/`. Which flows: the ones the person names, or all.

For what a ZFL or ZDL construct means, and how a change should be written, read
[the ZenWave languages](references/zenwave-languages/README.md): the guides, the Arcadia Editions examples in the
project's shape (microservices or modulith), and the grammars as the last word on syntax.

## 2. Deterministic checks first

```bash
bash .zenwave/bin/lint-zdl.sh --strict <zdl files>
```

Lint errors and `zdl.data-lineage` warnings go to the top of the list. Then the identities: every `@zdl(...)` path
resolves, every command and event in a flow exists in its ZDL, every `@compensates(x)` names a command, every
`systems` entry matches a service. These are facts: fix the list, don't ask about them, except to ask whether to
apply the obvious fix.

## 3. Hunt

Read every model together and build the list of findings. For each flow path (from a `start` to each `end`):

- **Correlation**: how each event reaches the aggregate it acts on. A command that takes the id of one entity when
  the event carries the id of its parent (an order with three reservations, confirmed by one reservation id).
- **Lineage**: every required field of every command input has a source upstream: the start payload, an event, a
  call result, or a lookup in the context. A field with no source is a missing decision.
- **Handled**: every emitted event is either handled by a policy, ends the flow, or is published on purpose (say for
  whom). Every command is triggered by something.
- **Ended**: every branch (`@outcome`, `@failure`, `on <Result>`) reaches an `end` outcome or a deliberate wait.
- **Compensated**: after each side effect, every later failure path undoes it (`@compensates`), exactly once, even
  when two failure paths converge.
- **Timers**: what starts each `@time`, what stops it, and what happens when it fires after the flow already ended.
- **Lifecycle**: every `@transition` is reachable, the `from` states agree with the flow order, terminal states are
  terminal, no two flows fight over one transition.
- **Ownership**: one context owns each transition and each aggregate; a `call` into a context does not mutate an
  aggregate another context owns.
- **Repetition and concurrency**: redelivered events, two actors on the same resource, a retry that races a timer.
- **Contracts**: OpenAPI and AsyncAPI agree with the ZDL services and events; an asynchronous flow lets the actor see
  its outcome.
- **Language**: identifiers missing from the glossary, glossary terms missing from the models, synonyms the glossary
  says to avoid.
- **Decisions**: anything that contradicts an ADR.
- **Test data**: an `@outcome` or precondition that no fixture can represent with the current fields.

Each finding names the model lines (`file:line`), a concrete scenario that shows it, and the options.

## 4. Grill

Turn the findings into the design tree and ask in rounds. Each answer becomes one of:

- a model change: applied by the person, or by you when they ask, then lint again;
- an ADR, when it qualifies ([adr-format.md](references/adr-format.md));
- a glossary entry ([glossary-format.md](references/glossary-format.md));
- a scenario the test data must cover;
- "as designed": record why in a doc comment of the model element when a reader would wonder.

A model change can open new findings: rerun step 2 and the affected part of step 3 before the next round.

## 5. Resolving a proposal

For an open `docs/proposals/P-<nn>.md` (from the board or the AFK loop): read it, check its evidence against the
models, grill the person on its options and anything they touch, and when they decide, write the decision in the
proposal (`status: accepted A`, the date, what changed). Then tell them what follows: regenerate, update the test
data and the board, tag a new baseline.

## Done

The frontier is empty, lint is clean, and every finding is decided. Summarise: model changes (with their commits if
the person committed), ADRs and glossary entries written, scenarios for the test data. Next step: the test data, then
the board.
