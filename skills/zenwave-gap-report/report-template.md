# ZenWave Gap Report — <service/repo name>

| | |
|---|---|
| Date | <YYYY-MM-DD> |
| Code baseline | `<git sha>` (<commit subject>) |
| Flows | <paths to *.zfl> |
| Models | <paths to *.zdl> |
| Deployment shape | <Modulith (in-process events) \| Microservice (AsyncAPI/<broker>)> |
| Produced with | `zenwave-gap-report` (read-only) |

## Summary

<3–6 numbered headline findings: crashes first, then model gaps, missing wiring, the recurring
generated pattern, tests.>

| Severity | Model (M) | Code (G) | Cross-cutting (X) | Open questions (Q) |
|---|---|---|---|---|
| blocker | | | | — |
| major | | | | — |
| minor | | | | — |
| **total** | | | | |

## 1. Model gaps (fix in ZFL / ZDL, then regenerate)

**M-01 · <severity> · <title>.** <What the model says, why the code can't satisfy it, the proposed
model change, and a link to the open question if a decision is needed.>

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
Phase 0 is always: clarify → fix model → regenerate → re-run this report.
Plus a `000-<bc>-baseline` feature for off-flow gaps.>
