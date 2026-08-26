# S11 Physical Diagnostics Contingency

Status: CONTINGENCY_ONLY / DO_NOT_INTEGRATE_BEFORE_BUILD7_PHYSICAL_RESULT

Base HQ: `f5703c054e98c9b1d589af5081eeede470d573b0`

Purpose: if Build 7 fails the real-iPhone reconstruction gate, expose the exact resource stop reason and measured memory values on the failure screen so the next change is evidence-driven rather than a blind ResourceGuard or quality change.

Displayed evidence:
- `memoryWarning` / `availableMemoryReserve` / `residentMemoryBudget` / other resource reason
- iteration
- active splat count
- resident memory and configured resident budget in MiB
- available process memory and configured reserve in MiB

Protected contracts remain unchanged:
- standard reconstruction iterations: 7,000
- dataset downscale: 4.0
- SH degree: 3
- capture JPEG: 0.90
- ResourceGuard thresholds and splat budget unchanged
- optimizer / densification semantics unchanged

S11 is not part of distributed Build 7 and must not be fast-forwarded into HQ before Build 7 physical evidence is evaluated. If Build 7 completes the full physical flow, S11 should be reviewed as optional observability rather than automatically integrated.
