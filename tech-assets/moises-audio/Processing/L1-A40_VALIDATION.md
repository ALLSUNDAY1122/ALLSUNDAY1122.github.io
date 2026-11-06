# L1-A40 Validation — Exact-Audit Import Isolation / Python 3.12 Discovery Closure

Captured: 2026-08-27 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Close the two concrete Python unittest-discovery errors observed by HQ on the exact A39 Worker tip so the Lane 1 A26 full-regression/dependency gate can be re-run on a new exact tip without known test-loader contamination.

This wave does not claim A26 PASS or any product PARITY. The new final tip still requires an exact checkout/CI execution.

## HQ exact evidence that triggered A40

HQ executed the A26 audit against exact Worker tip:

`22ee8a44bb826b24047bc4e97442ac64a095e48b`

GitHub Actions:

- run: `33026092575`
- job: `98367641633`

Observed exact-tip gate results before A40:

- owned source snapshot: **352 PASS**
- Python compile: **103 PASS**
- JSON parse: **156 PASS**
- JSON Schema: **69 PASS**
- dependency contracts: **28 / 28 PASS**
- unittest discovery: **761 tests, 2 errors, 0 skipped**
- overall A26: **FAIL**

The remaining failures were both import/discovery defects in Worker-owned tests, not product-runtime assertion failures.

## Root cause 1 — A20 differential import probe polluted global module state

`Separation/Tests/test_differential_gate_a20_import.py` installed partial stubs under the production bare module names:

- `differential_common`
- `differential_execute`
- `differential_review`

and did not restore them.

Later discovery of `test_differential_gate.py` therefore resolved `differential_common` to the stale stub. The stub intentionally lacked the real `validate_plan`, producing the observed import error even though `Separation/Evaluation/differential_common.py` defines the real symbol.

### A40 repair

The A20 probe now:

1. snapshots every touched `sys.modules` entry and `sys.path`;
2. installs stubs only inside a context manager;
3. imports the gate under a unique probe module name;
4. registers that dynamic module before `exec_module`;
5. restores the prior module objects exactly, or removes entries that did not previously exist;
6. restores `sys.path` exactly;
7. asserts identity restoration for all tracked modules after the probe completes.

This makes the test discovery-order independent instead of relying on the A20 probe running last.

## Root cause 2 — rights gate dynamic module was executed before registration

`Separation/Tests/test_rights_gate.py` created `rights_gate` with `module_from_spec` and immediately called `exec_module` without first registering the dynamic module in `sys.modules`.

HQ's Python 3.12 runner failed while evaluating `@dataclass(frozen=True)` in `rights_gate.py`, because dataclass introspection resolves `sys.modules[cls.__module__]` during class decoration.

### A40 repair

The rights-gate test now:

1. uses the unique module name `_l1_rights_gate_test_target`;
2. verifies that name is not already occupied;
3. registers the module in `sys.modules` before `exec_module`;
4. removes the entry if execution itself fails;
5. keeps the module registered while its tests run;
6. removes the unique entry from `tearDownModule`;
7. adds an explicit regression assertion that `ApprovedCheckpoint.__module__` resolves to the registered module.

No `rights_gate.py` production semantics were weakened.

## Regression-safety reasoning

A40 intentionally changes test loading only. It does not relax:

- rights lineage/commercial checkpoint enforcement;
- Golden/differential acceptance rules;
- A20 resume/reviewer evidence semantics;
- A26 dependency contracts;
- product processing, separation or privacy behavior.

The A20 probe still executes its prior functional checks; it additionally verifies process-global cleanup. The rights-gate suite retains the prior acceptance/rejection scenarios and adds module-registration coverage.

## Execution status

The new Worker tip after the two direct test repairs was:

`6514ab8eea1570c18e75f012254db48c3a0418e6`

No GitHub Actions workflow run was associated with that commit at the time of this wave.

A local exact checkout was attempted, but the execution environment could not resolve `github.com`, so repository-native full discovery could not be repeated locally. This is an environment observation, not an A26 PASS.

The expected effect is removal of the two known discovery errors. The final count may differ from the prior 761 because A40 adds a rights-gate regression test; no exact count is claimed until CI executes the new tip.

## A26 disposition

`L1-A26` remains **OPEN**.

HQ must execute the exact final A40 implementation/evidence tip with:

`Separation/Evaluation/lane1_dependency_audit.py --expected-git-head <exact-tip>`

and require all of:

- `overall_state = PASS`
- `git_head_binding.state = PASS`
- `owned_source_snapshot.state = PASS`
- `dependency_contracts.state = PASS`
- `unittest_discovery.state = PASS`
- zero unittest failures/errors.

Only that exact-tip result may close A26.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

A40 removes a concrete engineering-gate blocker. It does not by itself prove `MOI-P003`, `MOI-P004`, `MOI-P005`, `MOI-P020`, `MOI-P021`, `MOI-P024` or `MOI-P025` on a current iPhone.
