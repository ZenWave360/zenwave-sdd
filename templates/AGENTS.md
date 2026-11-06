## ZenWave SDD

This project is designed with ZenWave models and built with the zenwave-sdd skills, in two loops per business flow.
Where the models are, the shape of the project and its commands: [docs/zenwave-sdd-overlay.md](docs/zenwave-sdd-overlay.md).

- The models are the spec: the ZFL flows say when and why, the ZDL models say what. Use the terms of `GLOSSARY.md`.
- ZFL, ZDL, API contracts and the approved test data change only when the person asks for that change in the
  session. In the AFK loop, never: write a proposal instead (`docs/proposals/`, skill `zenwave-model-gap`).
- Generated structure is not hand-edited: when a regenerated file is wrong, the model is. Generated-once files
  (service implementations, listeners, mappers, tests) are ours to fill.
- `docs/tasks.md` is the board of the flow in progress. Once its baseline is tagged, only the orchestrator changes it.
- AFK commits go to `afk/<flow>`, unsigned, with `AI-Agent`, `AI-Model` and `AI-Orchestrator` trailers. A person
  reviews and merges them with a signed merge.
