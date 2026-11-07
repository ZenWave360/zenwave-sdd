---
name: zenwave-grill-domain
description: Greenfield discovery to models - interview the person about a new domain, from a brief, PRD, Event Storming photos or meeting transcripts, until the business flows, bounded contexts, commands, events, outcomes and rules are decided, writing GLOSSARY.md (with the ZFL/ZDL identifiers) and ADRs as decisions settle, and then draft all the models - one ZFL file per flow and one ZDL per bounded context - ready to be challenged with zenwave-grill-models. Use at the start of the HITL loop of a new project. In an existing project, use it to grill a new business flow against the existing models and write only its ZFL; zenwave-extend-models then brings the existing ZDL up to it.
---

# Grill the domain

The first step of the HITL loop of a new project. Inputs are what discovery produced: a brief or PRD, Event Storming
pictures, a whiteboard export, meeting transcripts, notes. The output is a shared understanding, written down, and
the first draft of every model:

- `GLOSSARY.md`: the language, with the identifier each term will have in ZFL and ZDL.
- `docs/adr/`: the decisions that are hard to reverse, among them the deployment shape.
- `docs/domain.md`: a one-page summary: structure, rules, lifecycles, and the list of flows.
- **The models**, drafted after the person confirms the understanding: one ZFL file per business flow, and one ZDL per
  bounded context, in the shape the project uses.

Follow [grilling.md](references/grilling.md) for how to ask (it includes Matt Pocock's skill verbatim),
[glossary-format.md](references/glossary-format.md) and [adr-format.md](references/adr-format.md) for what to write,
and [the ZenWave languages](references/zenwave-languages/README.md) for the models. Write in the language of the
person and of the repository's documents; identifiers stay in English unless an ADR says otherwise.

## Before the first round

Read every input, and the existing `GLOSSARY.md`, `docs/adr/` and models, if any. Look up facts yourself.
Then show the person, in a few lines, what you understood: the actors, the flows you can see, and the open branches.
The first round starts from there.

**A new flow in an existing project.** When the project already has ZDL models and the person wants a new flow on top
of them, grill only that flow, against what exists:

- skip the branches already settled for the project (scope, bounded contexts, deployment shape) unless the new flow
  reopens them;
- for each step, ask whether an existing command or event already does it before naming a new one: reuse beats a near
  copy;
- when a step needs a context nobody owns yet, that is a new bounded context and an ADR.

Write the glossary entries and ADRs as usual, then only the new ZFL file. Do not edit the existing ZDL: hand over to
`zenwave-extend-models`, which takes the new flow and brings each ZDL up to it.

## The design tree for a ZenWave domain

Walk these branches. Each answer opens the next ones; the order is a guide, not a script.

1. **Scope**: what is in and what is explicitly out. Who the actors are (people, other systems, the Scheduler).
2. **Business flows**: each one from the actor's intent (`start`) to every way it can end (`end` outcomes: success,
   rejection, cancellation, expiry). Name them. One flow per process that a person would explain separately.
3. **Policies**: in each flow, every `when <event> do <command>`, the business rule behind it, and what it may emit.
   Every branch: `@outcome`, `@failure` (technical, retried) versus a business rejection (not retried).
4. **Bounded contexts**: who owns each command and each aggregate; which context is the single owner of each
   transition ("only OrdersCheckout cancels an order").
5. **Deployment shape**: microservices (one repository per context, Kafka and AsyncAPI) or a modulith (modules,
   in-process events). It decides the ZDL annotations; an ADR records it. Also: the organization prefix for ids and
   packages, the persistence, and where the models will live (this repository, a sibling one, a packaged artifact).
6. **Synchronous or not**: a `call` when the answer is needed inside the same step, an event when a failure there must
   not fail this step. Where a transaction must span two aggregates, decide which.
7. **Compensations**: after each side effect (stock reserved, payment authorized), what undoes it on each later
   failure path. `@compensates`.
8. **Time**: timers, deadlines, expiries (`@time`), what starts them and what stops them.
9. **Aggregates and lifecycles**: states and transitions, who triggers each, which states are terminal.
10. **Correlation and lineage**: how each event finds the aggregate it acts on (which id); for each command input,
    where every field comes from. A field that exists nowhere upstream is a missing decision.
11. **Rules and limits**: invariants, who enforces them, the numbers (capacities, windows, retry counts).
12. **Concurrency and repetition**: two actors on the last place, the same event delivered twice.
13. **Data**: personal data, retention, erasure; what each context may keep.

## Summary of the domain

When the frontier is empty, write `docs/domain.md`: structure, rules, lifecycles (states and transitions as a short
block), and the flows table:

```markdown
| Flow | Start (actor) | End outcomes | Contexts |
|---|---|---|---|
| place-order | StartOrderCheckout (Customer) | completed, stockGone, orderCancelled | orders, inventory, payments, shipping, notifications |
```

Link terms to the glossary and decisions to their ADRs; don't repeat them. Show the person the summary and the list
of flows and contexts, and ask for their confirmation of the shared understanding. Nothing is drafted before it.

## Draft the models

After the confirmation, draft every model. This is the work of this skill, not an extra: the person reviews and
challenges the result, and nobody has to write the first version of a model by hand.

**Where.** The locations decided in branch 5, or the overlay's. Without a decision, these defaults (say which you
used): flows in `architecture/business-flows/<flow>.zfl`; ZDL in `architecture/models/<context>-domain-model.zdl`
for a modulith, or `<context>-api/domain-model.zdl` for microservices (one folder per context, as the examples do).
Never overwrite a model that exists without the person's say.

**Flows first.** For each flow, write the ZFL with the guide and the example open:

- the `systems` block with every context the flow touches, each with its `@zdl("...")` path and its services and
  commands; a policy whose owner is still undecided leaves `service` out;
- the `start`s with their actors and payload fields, the policies, `call`s and `response`s, `@outcome` and `@failure`
  branches, `@compensates`, `@time`, and the `end` outcomes;
- each business rule in the doc comment of its policy, in the language of the glossary, with the glossary's
  identifiers for every command and event.

**Then one ZDL per bounded context.** Apply [modeling-rules.md](references/zenwave-languages/modeling-rules.md) to
every system of every flow, in the project's shape only (follow `examples/<shape>/`), and
[asyncapi-naming-conventions.md](references/zenwave-languages/asyncapi-naming-conventions.md) for ids, channels and
topics in microservices:

- the aggregates, entities, enums and lifecycles decided in the grilling, with the fields, the validations and the
  rules that were decided, and nothing that was not: a field the flow needs and nobody decided goes back to the person
  as a question, and the draft says so in a doc comment marked `TODO(question)`;
- the services with their commands, inputs, outputs and `withEvents`; `@transition` for every state change;
- the events, and the consumers and synchronous calls in the shape's annotations (`@asyncapi` or `@listener`,
  `@calls`), with the `apis` entries they need;
- the data lineage of every event-triggered command: every required input field exists in the triggering event, or is
  resolvable by a lookup in the consuming context.

When a context takes part in several flows, write it once with the union of what the flows need.

**Lint** every ZDL ([lint.md](references/zenwave-languages/lint.md)) and fix the errors and the `--strict` warnings
until it is clean. If the lint cannot run (no `jbang zw` with the `Lint` plugin), say so: the models are not
validated.

**Quality pass.** Run the checklist at the end of modeling-rules.md on each ZDL, and check every ZFL against the
glossary: every identifier in a model is in the glossary and the other way round, and no model contradicts an ADR.

## Hand over

Tell the person: the files written, the open questions marked `TODO(question)`, and the assumptions you had to make.
For a new flow in an existing project, the next step is `zenwave-extend-models` on the new ZFL. Otherwise, the next
step is `zenwave-grill-models`, which challenges the models and asks the person about each finding, then
generating the code (ZenWave SDK projects) and the test data.

The brief or PRD this started from is not kept as a spec: once the models are approved, the models are the spec.
Suggest deleting it then, so no agent reads an outdated requirement as current.
