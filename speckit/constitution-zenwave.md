<!--
ZenWave constitution article for Spec Kit.
Available now: paste it into .specify/memory/constitution.md through /speckit-constitution.
To build: ship it in the zenwave preset as templates/constitution-template.md (strategy: append),
so every repo that installs the preset inherits it.
-->

### ZenWave: Models Own Structure

The ZenWave models are the single source of truth for structure. ZFL flows own
*when and why*, and ZDL models own *what*: aggregates, entities, lifecycle states and
transitions, commands, inputs and outputs, events, listeners, and calls between
contexts. Code generated from them by the ZenWave SDK (domain classes, repositories,
DTOs, mappers, controllers, event publishers and listeners) is a projection of the
models, not a design to revisit.

- Specs, plans and tasks MUST reference ZFL/ZDL elements by their exact names, and
  MUST NOT redefine, restate or re-derive them. `/speckit-plan` MUST NOT write a
  `data-model.md` or `contracts/` for structure that the ZDL or the generated
  OpenAPI/AsyncAPI already declare. It cross-references them instead.
- When a feature needs structure that the models lack (a field, input, event,
  command, state or transition), that is a **model gap**. It is raised through
  `/speckit-clarify` and fixed by editing the ZFL/ZDL and regenerating, never by
  hand-writing the structure in code.
- Behavior the models can't express (service method bodies, branching on
  outcomes, calls to other contexts, adapters to external systems, mapper
  configuration, tests and test data) is implemented in the generated-once,
  developer-owned files, and tracked as tasks.
- Regeneration is a deliberate human action. Agents may regenerate into a
  scratch folder to compare, but never overwrite the working tree on their own.
