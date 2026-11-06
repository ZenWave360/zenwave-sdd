# Glossary: `GLOSSARY.md`

The ubiquitous language of the project, and the bridge between the words people use and the identifiers in the ZFL
and ZDL. One file at the root of the repository that holds the models. Free of implementation details: not a spec,
not a scratch pad.

```markdown
# <Project> glossary

<One or two sentences: what the domain is.>

## Bookings

| Identifier | Term | Definition |
|---|---|---|
| `Booking` | Booking | Occupation of one Slot of a BookableUnit. Confirmed at once, with no approval or payment. Avoid: reservation. |
| `partySize` | Party size | How many people of one household take part in a Booking of a unit with capacity. |
| (not modeled) | Deployment | One installation of the application, for one or several municipalities. |
```

- **Identifier**: the name in ZFL or ZDL (`Booking`, `bookSlot`, `BookingCancelled`, `partySize`), or `(not modeled)`
  when the term matters to people but has no element, or `(operation)` for something people do that is not a single
  command. Identifiers are settled when the models are written; until then, the proposed one.
- **Term**: the word people use. A project in several languages adds one column per language (`Término`, `Termo`).
- **Definition**: one or two sentences, what it *is*, not what it does. End with `Avoid:` and the synonyms not to
  use, when there are any.
- Group terms by bounded context or by natural clusters, under `##` headings.
- Only terms of this domain. General programming concepts don't belong.
- A project with several glossaries (one per context) adds a `GLOSSARY-MAP.md` that lists them and how the contexts
  relate.
