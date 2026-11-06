---
name: zenwave-extend-models
description: Brownfield modeling - add a new business flow on top of an existing project's code and models - interview the person about how the new flow reuses and extends what exists, show the impact on existing models, flows, consumers, data and code, then write the new ZFL flow and change the existing ZDL models additively (new commands, events, listeners, calls, fields, enum values, states, transitions, or a new bounded context), and lint everything. Use in the HITL loop when the project already has models and code; for a new project use zenwave-grill-domain.
---

# Extend the models for a new flow

The project already has code, ZFL flows and ZDL models, and the person wants a new flow, or a change that is big enough
to be one. The new flow reuses what exists and adds to it. The risk is not writing the new flow: it is changing a model
that running code, stored data and other services depend on without anyone noticing. So this skill shows the impact
before it writes, and changes existing models only by adding to them, unless the person approves otherwise.

Follow [grilling.md](references/grilling.md) for how to ask (it includes Matt Pocock's skill verbatim),
[glossary-format.md](references/glossary-format.md) and [adr-format.md](references/adr-format.md) for what to write,
and [the ZenWave languages](references/zenwave-languages/README.md) for the models. Write in the language of the
person and of the repository's documents.

**Who edits.** This skill changes ZFL and ZDL files because the person asked for it by invoking it. Never in the AFK
loop. Never a model that is outside the scope the person gave.

## 1. Inputs

The person gives the idea of the new flow (a brief, notes, a draft ZFL, or just a conversation) and, if they are not in
the overlay (`docs/zenwave-sdd-overlay.md`), where everything is. You need:

| What | Why |
|---|---|
| the existing ZFL flows and the ZDL of every bounded context | what the new flow reuses and extends |
| the API contracts (OpenAPI, AsyncAPI) | who consumes what today |
| the code (read-only here) | what is already implemented, and what depends on the models |
| the test data (`data.sql`, JSON aggregates) | what existing data a model change would affect |
| `GLOSSARY.md` and `docs/adr/` | the language and the decisions to respect |
| the deployment shape, organization prefix and conventions | from the overlay |

If something is missing or the paths do not resolve, ask. Do not guess where the models are.

Read them all before the first question, and run the lint on the existing ZDL to know the starting point
([lint.md](references/zenwave-languages/lint.md)): do not mix new findings with old ones.

## 2. Grill the new flow against what exists

Show the person what you understood of the new flow and which existing flows, contexts and commands it touches. Then
walk this tree in rounds. Facts about the existing models and code are yours to look up.

1. **The flow.** Its actors, its `start`s, every way it ends (`end` outcomes).
2. **Reuse.** For each step: is there an existing command or event that already does it? Reuse beats a near copy. Where
   an existing one almost fits, what exactly differs, and is that a new command, a new branch of the old one, or a
   new input field?
3. **Ownership.** Which context owns each new command, event and state. A new bounded context only when no existing
   one owns the concept (then an ADR, and a new ZDL).
4. **What is new in the models.** Commands, events, listeners and calls to add; fields, enum values, states and
   transitions to add to existing aggregates; for every new field, whether it is required, and what existing rows get.
5. **What changes for existing behavior.** A new state an existing command's `@transition(from: ...)` does not
   expect; a new event emitted by an existing command; a new `withEvents` alternative; a listener on an event that
   already has others. Which existing flows are affected, and how.
6. **Contracts and consumers.** Anything that changes an event payload or an API consumed elsewhere; whether it can
   be additive (a new optional field) or needs a new version; who has to be told.
7. **Data.** Existing data and migrations: a new required field, a new non-null column, a changed enum.
8. **Compensation, time, repetition, concurrency, lineage.** As in a new flow: what undoes each side effect, timers,
   redelivery, two actors, and where every field of every new input comes from.

Write the glossary entries and the ADRs as decisions settle. The session is done when the frontier is empty and the
person confirms the understanding.

## 3. The impact, before any change

Write the change list and show it. One row per change:

| Model element | Change | Kind | Touches |
|---|---|---|---|
| `payments-processing` `PaymentService.refundPayment` | new command | additive | new flow only |
| `Order.status` | new value `REFUNDED`; `cancelOrder` `from` gets it | behavior | `cancel-order-flow`, `OrderTransitions`, status API enum |
| `PaymentCaptured` | new optional field `captureId` | additive, contract | AsyncAPI v1 consumers, `data.sql` |
| `Payment.attemptCount` | type `Integer` → `Long` | **breaking** | column, mappers, event payload |

Kinds: **additive** (nothing existing changes meaning), **behavior** (existing code or flows see something new),
**breaking** (a field removed, renamed or retyped; an event or API shape consumers rely on; a required field on
existing data). Breaking changes are made only with the person's explicit approval, one by one, and an ADR when they
qualify. Prefer the additive alternative and offer it.

Wait for the person's go on the whole list before writing.

## 4. Write

- **The new flow**: a new ZFL file, in the place the models live, following the ZFL guide and the example. Its
  `systems` block points at the existing ZDL files with `@zdl(...)`; each policy's rule goes in its doc comment, in
  the glossary's words.
- **The existing ZDL files**: edit in place. Add the commands, events, listeners, calls, fields, enum values, states,
  transitions and `apis` entries the list says, following
  [modeling-rules.md](references/zenwave-languages/modeling-rules.md) and the shape of the file (microservices:
  `@asyncapi`; modulith: `@listener`, `@calls`), never both for one event. Leave everything else as it is: order,
  formatting, comments, names. Do not reformat a file.
- **A new bounded context**: a new ZDL as in `zenwave-grill-domain`, drafted after the existing ones so the
  `zdl client` entries and the ids are consistent.
- Every new field is optional unless the person decided it is required and what existing data gets.
- A decision nobody made is a question, not a guess: put a doc comment `TODO(question)` and tell the person.
- Update `GLOSSARY.md` and `docs/domain.md` for what is new.

## 5. Check

1. **Lint** every ZDL you changed, and every ZDL that refers to one of them (`zdl client`). Compare with the baseline
   of step 1: you may not add findings. Fix the errors and the `--strict` warnings of your changes.
2. **Existing flows still hold**: every existing flow's systems, commands and events still resolve; no `when` policy
   became ambiguous; the `@transition`s of existing commands still cover the lifecycle.
3. **The change list matches the diff**: `git diff` of the models shows exactly the rows you showed, no more. A row
   that is missing or an extra change is a bug in your work.
4. The checklist at the end of modeling-rules.md, for the parts you touched.

## 6. Hand over

Tell the person: the files written, the change list as it ended, the `TODO(question)`s, and what comes next, in order:

1. **Review the projections** of the new flow and of the changed aggregates in the IDE.
2. **Generate.** ZenWave SDK projects: run the plugins of `zenwave-scripts.zw`. Files generated once (service
   implementations, listeners, mappers, tests, test data) are not overwritten by a normal run, so a new command in an
   existing service shows up as a missing method; regenerate into a scratch folder to compare when in doubt, and
   review `git diff`. Regeneration is the person's action, or yours when they ask.
3. **`zenwave-grill-models`** on the new flow and on the changed contexts.
4. **Test data**: `zenwave-test-scenarios` for the new states, branches and outcomes; the new flow's chains must exist
   before its board.
5. **The board**: `zenwave-tasks-from-code-and-models` for the new flow (the code exists, the new behavior does not),
   then `zenwave-gate-check`, and a new baseline tag for this flow.
