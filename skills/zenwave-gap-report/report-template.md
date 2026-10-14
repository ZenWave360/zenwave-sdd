# ZenWave Gap Report — <service/repo name>

| | |
|---|---|
| Date | <YYYY-MM-DD> |
| Code baseline | `<git sha>` (<commit subject>) |
| Flows | <paths to *.zfl> |
| Models | <paths to *.zdl> |
| Deployment shape | <Modulith (in-process events) \| Microservice (AsyncAPI/<broker>)> |
| Produced with | `zenwave-gap-report` (read-only) |

## Model readiness: <✅ READY | ⛔ NOT READY>

<NOT READY:>
> ⛔ **NOT READY: the current models can't implement these flows.** Do not start or
> continue agentic implementation of <flows>. Agents must not edit ZFL/ZDL to get
> unblocked. A human has to decide, change the models, regenerate and re-run this report.
>
> | Flow | Implementable as modeled? | Blocked by |
> |---|---|---|
> | <FlowName> | no | M-01, M-03, Q-02 |
>
> **Decisions needed from a human:**
> 1. **M-01**: <what is missing, in one sentence>. Options: (a) <model change> → <consequence>;
>    (b) <alternative> → <consequence>.

<READY:>
> ✅ **READY.** No open model gaps and no open model-affecting questions. Implementation can start.

## Summary

<3–6 numbered headline findings: crashes first, then model gaps, missing wiring, the recurring
generated pattern, tests.>

| Severity | Model (M) | Code (G) | Cross-cutting (X) | Open questions (Q) |
|---|---|---|---|---|
| blocker | | | | — |
| major | | | | — |
| minor | | | | — |
| **total** | | | | |

## 1. Model gaps (human decision: ZFL / ZDL change + regeneration; agents never edit the models)

**M-01 · <severity> · <title>.** <What the model says, why the code can't satisfy it, the
options for a model change (proposals only, not applied), and a link to the open question if a
decision is needed.>

## 2. <FlowName> — traceability

| # | ZFL step | Trigger in code | Input mapping | Service body |
|---|---|---|---|---|
| 1 | `<Trigger> → <command>` | ✅/❌ `<path:line>` | ✅/❌ | ✅/❌ G-xx |

### 2.<n> <bounded-context> (phase order: steps …)

| Id | Sev | Where | Gap → expected behavior | Model ref |
|---|---|---|---|---|
| G-<BC>-01 | | `<path:line>` | | |

### 2.<n> Flow-level tests

| Id | Sev | Gap |
|---|---|---|

## 3. Baseline: not touched by any flow

| Id | Sev | Where | Gap |
|---|---|---|---|

## 4. Cross-cutting

| Id | Sev | Gap |
|---|---|---|

## 5. Open questions (→ `/speckit.clarify`)

| Id | Question | Blocks |
|---|---|---|

## 6. Suggested Spec Kit mapping

<Modulith: one feature per flow, one phase per bounded context in flow order.
Microservice: this repo's bounded-context slice of each flow, linking to the flow spec.
Phase 0 is always a human step: clarify → a human changes the model → regenerate → re-run this
report. Agents don't start Phase 1 until the verdict is READY.
Plus a `000-<bc>-baseline` feature for off-flow gaps.>
