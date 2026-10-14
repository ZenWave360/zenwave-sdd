# <Project> — ZenWave SDD Overlay

Project-specific inputs for the zenwave-sdd skills (`zenwave-gap-report`,
`zenwave-fill-gaps`, `zenwave-test-data`, `zenwave-test-scenarios`). Agents read
this file first, then the skill. Reference it from the project's `AGENTS.md` /
`CLAUDE.md`.

## Where things are

Paths are relative to the implementation repo root. Models in sibling repos are
fine (`../<architecture-repo>/...`); say which repos must be checked out.

| What | Path |
|---|---|
| Business flows (ZFL) | `<path>/*.zfl` |
| Domain models (ZDL) | `<path>/*.zdl` (one per bounded context) |
| Generated API contracts | `<path>/*-openapi.yml`, `<path>/*-asyncapi.yml` |
| Models as the generator sees them | the path, or the `groupId:artifactId:version` jar and the folder inside it that `zenwave-scripts.zw` reads (`classpath:/...`) |
| Implementation repo | `<path>` |
| Generation script | `<implementation repo>/zenwave-scripts.zw` |
| Gap report | `<implementation repo>/docs/zenwave-gap-report.md` |

If `zenwave-scripts.zw` reads the models from a packaged artifact (`@import(...)` +
`classpath:/...`), add:

- how to extract them when the source repo isn't checked out (e.g.
  `unzip -o -j <jar> '<folder>/*.zdl' -d target/models`);
- how to check the packaged copy matches the working copy (a `diff -q` loop), and
  the command that repackages it. The generated code reflects the packaged copy.

If ZFL `@zdl(...)` paths don't match where the ZDLs live for this deployment,
explain how to resolve them here (a table from each `@zdl` path to its file).

## Shape

- Deployment shape: **microservices** (one bounded context per repo; Kafka +
  AsyncAPI; ZDL consumers use `@asyncapi`) | **modulith** (bounded contexts =
  modules; in-process events; ZDL consumers use `@listener`).
- Organization prefix `<org>` (ids `urn:<org>:<domain>:<subdomain>`, packages `<org>.<domain>.<subdomain>`): `<e.g. com.example>`
- Base package and module packages: `<...>`
- Persistence: `jpa` | `mongodb`
- Spec Kit feature rule: one feature per ZFL flow (`NNN-<flow>`) in a modulith, or
  this repo's bounded-context slice of each flow in microservices, plus
  `000-<bc>-baseline` for work outside any flow.

## Build, generate, test

```bash
# JDK / tools
export JAVA_HOME=<jdk>
# regenerate after a ZDL change (how the ZDLs reach the generator: path, packaged artifact...)
<commands>
# compile and collect MapStruct warnings
mvn -DskipTests clean compile 2>&1 | tee target/compile.log
# export the Hibernate DDL (JPA only; no project config needed)
bash <zenwave-test-data skill>/scripts/export-ddl.sh
```

## Project rules

- Naming conventions (ids, channels, topics): `<link>`
- Decisions already taken (e.g. how multi-response calls are modeled, where the
  customer data comes from): `<list>`
