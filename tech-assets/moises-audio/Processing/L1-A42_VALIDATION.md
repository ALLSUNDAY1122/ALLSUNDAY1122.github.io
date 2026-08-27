# L1-A42 Validation — Exact Discovery Module Isolation Closure

Evidence state: `NON_PARITY_EVIDENCE_ONLY`  
PARITY claim: `NONE`

## Trigger

HQ Canonical Epoch 44 records exact Worker 1 A40 audit run `33028113833`, job `98374115217`, against A40 tip `6514ab8eea1570c18e75f012254db48c3a0418e6` on Python 3.12. The audit reached full unittest discovery and reported 767 tests, 0 failures, 1 error, 0 skipped. The remaining error was traced to `test_differential_execute_resume.py`: it installed a fake bare-name `differential_common` in `sys.modules` at import scope and never restored it, so later `test_differential_gate.py` imported the fake module and could not obtain the real `validate_plan` contract.

A40 had already fixed the analogous contamination in `test_differential_gate_a20_import.py` and the Python-3.12 rights-gate dynamic-import ordering defect. A42 closes the remaining execute-resume contamination and adds recurrence guards.

## Changes

1. `Separation/Tests/test_differential_execute_resume.py`
   - Moves fake `differential_common` installation into `isolated_execute_import()`.
   - Snapshots and exactly restores `differential_common`, real `differential_resume`, the unique dynamic probe module, and the complete `sys.path` list.
   - Registers the unique dynamic execute probe in `sys.modules` before `exec_module`.
   - Keeps the original execute/resume behavioral scenarios intact after the isolated import has produced direct function/class references.
   - Adds top-level postconditions proving import-state identity restoration before unittest discovery advances to the next module.

2. `Separation/Tests/test_differential_execute_resume_isolation.py`
   - Imports the execute-resume test as unittest discovery would.
   - Covers both initially absent modules and pre-existing sentinel modules.
   - Requires exact object-identity restoration for common/resume/probe modules and exact `sys.path` restoration.

3. `Separation/Tests/test_differential_module_isolation_policy.py`
   - AST-scans `test_differential*.py` modules.
   - Fails if a future test writes `sys.modules["differential_*"]` directly at module import scope.
   - Preserves the explicit restoration contract in the A40 gate probe and A42 execute probe.

4. `Separation/Tests/test_a42_dependency_binding.py`
   - Makes deletion or semantic weakening of the A42 source/regression/policy files visible to normal full unittest discovery.

The existing `lane1_dependency_audit.py` v5 dependency inventory remains unchanged at 28 checks. A42 intentionally does not rewrite that stable audit inventory inside the same discovery-repair wave; A42 is bound through full unittest discovery, which is the gate that actually failed in the observed exact run.

## Focused validation

An interface-compatible isolated import-state harness exercised the A42 restoration algorithm with a dynamic execute module that asserts it is registered in `sys.modules` during execution.

Result: **9/9 PASS**.

Validated:
- dynamic probe registered before `exec_module`;
- absent common/resume/probe modules remain absent after the probe;
- `sys.path` exactly restored when modules were initially absent;
- pre-existing common/resume/probe sentinel object identities restored exactly;
- `sys.path` exactly restored when sentinels were pre-existing.

This is not a repository-native checkout run and is not presented as A26 PASS.

## Remaining exact gate

A26 remains open. HQ must run `Separation/Evaluation/lane1_dependency_audit.py --expected-git-head <exact-final-A42-tip>` on a complete executable checkout of the final Worker 1 A42 tip and require all of the following before A26 can close:

- `overall_state=PASS`
- `git_head_binding.state=PASS`
- `owned_source_snapshot.state=PASS`
- `dependency_contracts.state=PASS`
- `unittest_discovery.state=PASS`
- zero unittest failures
- zero unittest errors

No P003/P004/P005/P020/P021/P024/P025 state is promoted by this wave.
