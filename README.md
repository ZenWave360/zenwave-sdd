# zenwave-sdd

Spec-driven development on top of ZenWave: agent skills and Spec Kit integration
that take a ZenWave project (microservices with Kafka + AsyncAPI, or a modulith) from "structure generated" to "flows
implemented, tested and tracked".

- **[GETTING-STARTED.md](GETTING-STARTED.md)**: step by step, from installing the
  skills to a verified flow. Start here.
- **[MANUAL.md](MANUAL.md)**: the workflow in depth, the reasoning behind it, and
  the release plan.
- **[skills/](skills/)**: Agent Skills (`SKILL.md` format)
  - `zfl-to-zdl`: ZFL flow → one ZDL per bounded context (microservices or modulith)
  - `zenwave-gap-report`: find the behavior the generator left out (read-only)
  - `zenwave-fill-gaps`: implement it with ZenWave-aware patterns
  - `zenwave-test-data`: DDL-driven `data.sql` + JSON fixtures, one consistent example per entity (basic)
  - `zenwave-test-scenarios`: the same files with a fixture per command precondition, branch, failure path and outcome
- **[speckit/](speckit/)**: Spec Kit integration (the constitution article today;
  the extension and preset are planned)
- **[templates/](templates/)**: the project overlay template

Status: early. The skills were extracted from the Arcadia Editions reference
project and haven't yet been validated as standalone skills (see MANUAL §8).
