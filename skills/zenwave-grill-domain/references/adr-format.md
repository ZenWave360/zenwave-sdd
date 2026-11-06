# Architecture decision records: `docs/adr/NNNN-<slug>.md`

Sequential numbers (`0001-`, `0002-`…): scan `docs/adr/` for the highest and add one. Create the folder with the
first ADR.

```markdown
# 0004. Model the flows in ZFL before the ZDL

Status: accepted (2026-10-30)

<What the context was, what was decided, and why. One paragraph is often enough.>
```

Optional sections, only when they add something: **Context**, **Decision**, **Considered options** (when the
rejected ones are worth remembering), **Consequences** (when downstream effects are not obvious).

Status: `proposed`, `accepted (<date>)`, `deprecated`, `superseded by 0009`.

## When to write one

All three must hold:

1. **Hard to reverse**: changing your mind later costs something real.
2. **Surprising without context**: a reader of the models or the code would wonder why.
3. **A real trade-off**: there were alternatives and one was chosen for reasons.

What qualifies: how bounded contexts talk (a `call` or an event), what each context owns, scope decisions and the
explicit no's, constraints the models cannot show (law, an external contract), deliberate deviations from the
obvious path, technology with lock-in.

What doesn't: anything the models already say. A ZDL field or a ZFL policy is its own record; an ADR is for the why
behind it when the why is not obvious.
