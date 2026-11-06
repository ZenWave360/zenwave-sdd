# The ZenWave languages

Reference for reading and writing ZFL and ZDL. Read what the task needs, not everything. Refreshed from their sources
with `scripts/update-references.sh` of zenwave-sdd, except the three files marked ours: don't edit the copies.

| File | What it is | Read it when |
|---|---|---|
| [ZFL-Flow-Language.mdx](ZFL-Flow-Language.mdx) | the ZFL guide and reference (the zenwave360.io docs page) | writing or reviewing a business flow |
| [ZDL-Domain-Language.mdx](ZDL-Domain-Language.mdx) | the ZDL guide and reference (the zenwave360.io docs page) | writing or reviewing a bounded context |
| [modeling-rules.md](modeling-rules.md) (ours) | how a flow becomes ZDL models: one model per context, commands, events, direct calls with `@calls`, multi-response results, lifecycles, transport annotations per shape, `apis` entries, a quality checklist | turning flows and decisions into ZDL, in a new project or on top of an existing one |
| [asyncapi-naming-conventions.md](asyncapi-naming-conventions.md) (ours) | model ids, plugin ids, channel ids and topic names | writing `config`, events and consumers of a microservice |
| [lint.md](lint.md) (ours) | how to run the ZDL lint and read its report | always, after writing a ZDL |
| [examples/place-order-flow.zfl](examples/place-order-flow.zfl) | Arcadia Editions' place-order flow: starts, policies, calls and responses, outcomes, a retry loop, compensations, a timer, end outcomes | a complete flow to imitate |
| [examples/microservices/](examples/microservices/) | orders-checkout and payments-processing as **microservices**: `@rest` services, events with `@asyncapi(channel, topic)`, consumers with `@asyncapi(api: ..., channel: ...)` | the project's shape is microservices with Kafka and AsyncAPI |
| [examples/modulith/](examples/modulith/) | the same two contexts as **modulith** modules: consumers with `@listener(zdl: ..., event: ...)` or `@listener(event: ...)`, synchronous calls with `@calls` | the project's shape is a modulith with in-process events |
| [grammar/Zfl.g4](grammar/Zfl.g4), [grammar/Zdl.g4](grammar/Zdl.g4) | the ANTLR grammars of dsl-kotlin, the parser the tools use | a syntax question the docs and the examples don't answer |

Use the examples of one shape only: the shape is in the project overlay. Mixing `@asyncapi` consumers and `@listener`
for the same event is a lint warning (`zdl.mixed-event-binding`).

Whatever you write, lint it ([lint.md](lint.md)). The lint is the judge of syntax, not your reading of the grammar.
