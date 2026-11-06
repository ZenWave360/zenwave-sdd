# Grilling, for ZenWave models

**Follow [grilling/mattpocock-grilling.md](grilling/mattpocock-grilling.md)**: Matt Pocock's `grilling` skill, copied
verbatim under its MIT licence ([grilling/LICENSE-mattpocock](grilling/LICENSE-mattpocock)). It is how to ask: a
design tree, rounds over its frontier, a recommended answer per question, facts looked up by you, decisions asked to
the person, done when the frontier is empty. This file only adds what is specific to ZenWave. Where the two
disagree, this file wins.

## What to write, as you go

Matt Pocock pairs grilling with his `domain-modeling` skill; here it is replaced by these, so don't install or call it:

- **Glossary**: each term when it is settled, with its ZFL/ZDL identifier ([glossary-format.md](glossary-format.md)).
- **ADR**: only when the decision is hard to reverse, surprising without context, and the result of a real
  trade-off ([adr-format.md](adr-format.md)). Offer it; the person accepts.
- **Models**: ZFL and ZDL, in the languages of [zenwave-languages/](zenwave-languages/README.md). In the HITL loop an
  agent edits a model only when the person asks for that change; otherwise list the change for them.

## Sharpen the language

- When the person uses a term that contradicts the glossary, say so at once: "the glossary says a Booking occupies
  one Slot; here it spans two. Which is it?"
- When a term is vague or overloaded, propose one precise term and the words to avoid.
- Stress-test with concrete scenarios: an order with three lines, two citizens booking the last place at the same
  second, a payment that fails after the stock is reserved.
- When the person states how something works and the models or the code say otherwise, show both.

## Rounds

- Keep a round to around five questions, answerable in a few minutes; the rest of the frontier waits.
- Never invent a business rule: if nobody has decided it, it is a question.
- When the person is short of time, answer the remaining frontier yourself, marked as your recommendations, and list
  them for a quick yes or no.

## Done

Summarise what was decided and where it was written (glossary, ADRs, models), and do not act on it until the person
confirms the shared understanding.
