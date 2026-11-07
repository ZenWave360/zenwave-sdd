---
name: zenwave-extend-models
description: Brownfield modeling - take a new ZFL business flow, written with zenwave-grill-domain on top of a running system, and bring every existing ZDL up to it - the new commands, events, listeners, calls, entities, fields, enum values, states and transitions each bounded context needs for that flow - showing the change list and its impact on existing flows, contracts and data before editing, changing the ZDL additively, and linting. Use in the HITL loop of an existing project, after the new flow's ZFL exists; for a new project zenwave-grill-domain drafts all the models itself.
---

# Extend the ZDL models for a new flow

The system is running: it has code, ZFL flows and one ZDL per bounded context. A new business flow was decided and
written as a ZFL file with `zenwave-grill-domain`. That flow asks things of the existing contexts that their ZDL does
not have yet: a new command, an event, a listener, a field, a state. This skill reads the new flow and edits each ZDL
so the flow can run on it.

The flow is the input and it is already decided. This skill does not design the flow again; it derives what each ZDL
needs from it. The risk is changing a model that running code, stored data and other services depend on without anyone
noticing, so it shows the change list before it writes, and changes existing models only by adding to them unless the
person approves otherwise.

Follow [modeling-rules.md](references/zenwave-languages/modeling-rules.md) and
[the ZenWave languages](references/zenwave-languages/README.md) for the models, and
[grilling.md](references/grilling.md) for how to ask when something is missing. Write in the language of the person and
of the repository's documents.

**Who edits.** This skill changes ZDL files because the person asked for it by invoking it. Never in the AFK loop. It
does not change the new ZFL flow, nor any existing one: a gap in the flow goes back to the person.

## 1. Inputs

The person points at the new ZFL flow. From the overlay (`docs/zenwave-sdd-overlay.md`), or from the person, you need:

| What | Why |
|---|---|
| the new ZFL flow | what is asked of each context |
| the existing ZDL of every bounded context in the flow's `systems` block | what is there already |
| the existing ZFL flows | what else depends on the same commands, events and states |
| the API contracts (OpenAPI, AsyncAPI) | who consumes what today |
| the test data (`data.sql`, JSON aggregates) and the code, read-only | what a model change would affect |
| `GLOSSARY.md` and `docs/adr/` | the names and the decisions to respect |

If a path does not resolve, ask. Do not guess where the models are.

Run the lint on the existing ZDL first ([lint.md](references/zenwave-languages/lint.md)) to know the starting point:
do not mix new findings with old ones.

## 2. What the flow asks of each context

Walk the new flow from each `start` to each `end`, and for every system in its `systems` block list what its ZDL must
have:

- **Commands**: every command the flow calls on the context, with its input (the fields the triggering event or the
  `start` provides), its output, and the events it emits (`withEvents`, one alternative per `@outcome` branch).
- **Events**: every event the context emits in the flow, with the fields the next steps need (data lineage: every
  field a later command needs must come from somewhere).
- **Consumers and calls**: every `when <event> do <command>` where the event comes from another context becomes a
  listener in the shape's annotations (`@asyncapi` or `@listener`); every `call` becomes `@calls`, with its `apis`
  entry.
- **Aggregates and entities**: new entities, new fields on existing ones, new enum values.
- **Lifecycles**: new states and `@transition`s the flow's outcomes imply.
- **Compensations and timers**: the commands behind `@compensates` and `@time`.

Then compare with what each ZDL has. Reuse beats a near copy: when an existing command or event already does the step,
use it; when it almost does, say what differs.

What the flow does not decide is a question, not a guess: a field with no source, whether a new field is required and
what existing rows get, which context owns a new concept, whether a payload change can be additive. Ask them in one
round, each with a recommended answer. If the flow itself turns out to be wrong or incomplete, stop and say so: that is
`zenwave-grill-domain` or `zenwave-grill-models` work, on the ZFL.

## 3. The change list, before any edit

One row per change:

| ZDL | Element | Change | Kind | Touches |
|---|---|---|---|---|
| payments-processing | `PaymentService.refundPayment` | new command | additive | new flow only |
| orders-checkout | `Order.status` | new value `REFUNDED`; `cancelOrder` `from` gets it | behavior | `cancel-order-flow`, status API enum |
| payments-processing | `PaymentCaptured` | new optional field `captureId` | additive, contract | AsyncAPI consumers, `data.sql` |
| payments-processing | `Payment.attemptCount` | `Integer` → `Long` | **breaking** | column, mappers, event payload |

Kinds: **additive** (nothing existing changes meaning), **behavior** (existing code or flows see something new),
**breaking** (a field removed, renamed or retyped; an event or API shape consumers rely on; a required field on
existing data). Breaking changes only with the person's explicit approval, one by one, and an ADR when they qualify.
Offer the additive alternative.

Wait for the person's go on the whole list.

## 4. Edit the ZDL

- Edit each ZDL in place, following modeling-rules.md and the shape of the file (microservices: `@asyncapi`;
  modulith: `@listener`, `@calls`), never both for one event.
- Add only what the list says. Leave everything else as it is: order, formatting, comments, names. Do not reformat a
  file.
- Every new field is optional unless the person decided it is required and what existing data gets.
- A decision nobody made goes in a doc comment `TODO(question)`, and you tell the person.
- A new bounded context, when the person decided one: a new ZDL drafted as `zenwave-grill-domain` does, after the
  existing ones, so `zdl client` entries and ids are consistent.
- Add to `GLOSSARY.md` the new identifiers; to `docs/domain.md` the new flow, if it is not there.

## 5. Check

1. **Lint** every ZDL you changed and every ZDL that refers to one of them (`zdl client`). You may not add findings
   to the baseline of step 1. Fix the errors and the `--strict` warnings of your changes.
2. **The new flow resolves**: every system, command and event of the new ZFL exists in its ZDL, and every field of every
   event-triggered command has a source.
3. **Existing flows still hold**: their commands and events still resolve, no `when` policy became ambiguous, the
   `@transition`s of existing commands still cover the lifecycle.
4. **The change list matches the diff**: `git diff` of the models shows exactly the rows you showed.

## 6. Hand over

Tell the person: the files changed, the change list as it ended, the `TODO(question)`s, and what comes next:

1. **Review the projections** of the changed aggregates in the IDE.
2. **`zenwave-grill-models`** on the new flow and the changed contexts.
3. **Generate.** ZenWave SDK projects: run the plugins of `zenwave-scripts.zw`. Files generated once (service
   implementations, listeners, mappers, tests, test data) are not overwritten by a normal run, so a new command in an
   existing service shows up as a missing method. Review `git diff`.
4. **Test data**: `zenwave-test-scenarios` for the new states, branches and outcomes.
5. **The board**: `zenwave-tasks-from-code-and-models` for the new flow, then `zenwave-gate-check` and a new baseline.
