# Linting ZDL

The judge of what you write. Run it on every ZDL you create or change, and read its answer before anything else:

```bash
bash .zenwave/bin/lint-zdl.sh --strict <file.zdl|dir>...
```

(`jbang zw -p Lint zdlFile=<file> format=json strict=true` for one file; the script runs it for each, with the real
path, because `zdl client` references resolve relative to the ZDL file.) It needs a `jbang zw` build that includes the
`Lint` plugin (zenwave-sdk 2.8.0 or newer). Reports go to `target/zdl-lint/<name>.json`.

Read the result like this:

- **Exit code.** `0` clean. `1` findings (errors, or warnings with `--strict`). `2` the tool failed (bad path, linter
  crash): it means "lint broke", not "the model is wrong"; read `<name>.stderr.log` (kept whenever the exit code is
  not 0) and fix the invocation.
- **The report.** One JSON document, even when clean (`diagnostics: []`). Each diagnostic has `file`, `line`,
  `column` (1-based), `severity`, `ruleId`, `message` and `modelPath`. `modelPath` (for example
  `entities.Customer.fields.name.type` or `services.X.methods.y.withEvents.0`) says which element to fix. Fix the
  first error first: `zdl.reference-unresolved` on a `zdl client` is usually a cascade of parse problems in the
  *referenced* file, so lint and fix that one first.
- **stderr.** Debug logs and the parser's own `ZDL ERROR` lines. Ignore it when the exit code is 0 or 1; read it when
  it is 2.
- **`--strict`** also fails on the warnings `zdl.data-lineage` and `zdl.mixed-event-binding`, which are worth
  resolving in any model that agents will implement.
- **Custom linters.** `linters=` *replaces* the default set (`ZdlProblems,ZdlReferences,ZdlCalls,ZdlListener`), so a
  custom list must name the built-ins it wants to keep. Add the jar with `ZW_DEPS`.

Rule ids: `zdl.syntax`, `zdl.parser`, `zdl.transition-state`, `zdl.lifecycle-initial`, `zdl.lifecycle`,
`zdl.unknown-type|event|input|output|aggregate`, `zdl.semantic`, `zdl.reference-unresolved`, `zdl.calls-command`,
`zdl.listener-event`, `zdl.mixed-event-binding`, `zdl.data-lineage`.

The lint checks the ZDL files. It does not check the ZFL; read the flow against the ZFL guide and the example.
