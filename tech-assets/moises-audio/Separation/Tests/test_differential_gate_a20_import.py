from __future__ import annotations

import importlib.util
import sys
import types
from contextlib import contextmanager
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent / "Evaluation"
_MISSING = object()
_TRACKED_MODULES = (
    "differential_common",
    "differential_execute",
    "differential_review",
    "differential_resume",
    "_l1_a20_gate_import_probe",
)

count = 0


def ok(value):
    global count
    assert value
    count += 1


def _restore_module(name: str, previous) -> None:
    if previous is _MISSING:
        sys.modules.pop(name, None)
    else:
        sys.modules[name] = previous


def _stub_common() -> types.ModuleType:
    common = types.ModuleType("differential_common")
    common.EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
    common.SCHEMA_VERSION = 1
    common.EXIT_CANDIDATE_FAIL = 4
    common.EXIT_EXTERNAL_INPUT_REQUIRED = 3

    class GateError(ValueError):
        def __init__(self, code, message="", exit_code=2):
            super().__init__(message)
            self.code = code
            self.message = message
            self.exit_code = exit_code

    common.GateError = GateError
    for name in (
        "dump_json",
        "load_json",
        "req_map",
        "validate_fixture_for_batch",
        "validate_plan",
        "validate_run",
        "validate_system_identity",
    ):
        setattr(common, name, lambda *args, **kwargs: None)
    return common


def _stub_execute() -> types.ModuleType:
    execute = types.ModuleType("differential_execute")
    for name in ("build_comparison_inputs", "evaluate_all_runs", "execute_project_cases"):
        setattr(execute, name, lambda *args, **kwargs: None)
    return execute


def _stub_review() -> types.ModuleType:
    review = types.ModuleType("differential_review")
    for name in ("build_blind_review", "calculate_acceptance", "parse_reviews"):
        setattr(review, name, lambda *args, **kwargs: None)
    return review


@contextmanager
def isolated_gate_import():
    """Import the A20 gate with stubs without contaminating unittest discovery globals."""
    previous_modules = {name: sys.modules.get(name, _MISSING) for name in _TRACKED_MODULES}
    previous_path = list(sys.path)
    gate_name = "_l1_a20_gate_import_probe"
    try:
        sys.path.insert(0, str(EVAL))
        sys.modules["differential_common"] = _stub_common()
        sys.modules["differential_execute"] = _stub_execute()
        sys.modules["differential_review"] = _stub_review()
        # differential_resume must be the real implementation. Remove a prior import only for the
        # duration of this probe so the gate import is deterministic, then restore it exactly.
        sys.modules.pop("differential_resume", None)

        spec = importlib.util.spec_from_file_location(gate_name, EVAL / "differential_gate.py")
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        # Register before exec_module. This is the Python 3.12-safe dynamic import order and also
        # makes module identity deterministic for decorators/introspection used by dependencies.
        sys.modules[gate_name] = module
        spec.loader.exec_module(module)
        yield module, sys.modules["differential_common"].GateError
    finally:
        sys.path[:] = previous_path
        for name, previous in previous_modules.items():
            _restore_module(name, previous)


_before = {name: sys.modules.get(name, _MISSING) for name in _TRACKED_MODULES}
with isolated_gate_import() as (m, GateError):
    ok(m._normalize_golden_lock({"golden_corpus_lock_sha256": "a" * 64}, "PARITY_CANDIDATE") == "a" * 64)
    ok(m._normalize_golden_lock({}, "REGRESSION") is None)
    try:
        m._normalize_golden_lock({}, "PARITY_CANDIDATE")
    except GateError as error:
        ok(error.code == "L1A20_GOLDEN_LOCK_REQUIRED" and error.exit_code == 3)
    else:
        raise AssertionError

    try:
        m._normalize_golden_lock({"golden_corpus_lock_sha256": "bad"}, "REGRESSION")
    except GateError as error:
        ok(error.code == "L1A20_GOLDEN_LOCK_INVALID")
    else:
        raise AssertionError

    ok(m.build_parser().prog is not None)

    class R:
        def __init__(self):
            self.batch_identity_sha256 = "b" * 64
            self.state = None
            self.hashes = None

        def bind_global_artifact(self, *args, **kwargs):
            pass

        def set_state(self, state):
            self.state = state

        def set_review_hashes(self, **kwargs):
            self.hashes = kwargs

    resume = R()
    m.build_blind_review = lambda *args, **kwargs: (Path("/tmp/w.json"), Path("/tmp/r.json"), Path("/tmp/s.json"))
    m.load_reviewer_roster = lambda *args, **kwargs: ["R1"]
    m.build_reviewer_assignments = lambda *args, **kwargs: [
        {
            "assignment_id": "A1",
            "case_id": "C",
            "stem": "vocals",
            "system_blind_id": "A",
            "reviewer_id": "R1",
            "replaces_assignment_id": None,
        }
    ]
    m.load_replacements = lambda *args, **kwargs: []
    m.apply_replacements = lambda base, replacements, batch: (base, [])
    m.reviewer_assignment_document = lambda *args, **kwargs: {}
    m.dump_json = lambda *args, **kwargs: None

    def no_reviews(*args, **kwargs):
        raise GateError("L1M04_BLIND_REVIEW_REQUIRED", "none", exit_code=3)

    m.parse_reviews = no_reviews
    m.filter_reviews_for_active_assignments = lambda reviews, base, active, history: (
        [],
        ["A1"],
        {"missing_assignment_count": 1},
    )
    m.sha256_json = lambda value: "c" * 64
    try:
        m._review_stage({"batch_id": "B", "min_reviewers": 1}, Path("/tmp"), Path("/tmp"), resume)
    except m.ResumeError as error:
        ok(error.code == "L1A20_REVIEW_ASSIGNMENTS_INCOMPLETE" and error.exit_code == 3)
        ok(resume.state == "WAITING_REVIEW")
        ok(resume.hashes["missing_assignment_ids"] == ["A1"])
    else:
        raise AssertionError

# The original A20 probe used global bare-name stubs and left them in sys.modules, so whichever
# unittest module loaded next could import a fake differential_common. Verify exact restoration.
for _name, _previous in _before.items():
    _current = sys.modules.get(_name, _MISSING)
    ok(_current is _previous)

print(f"L1_A20_GATE_IMPORT_PASS assertions={count}")
