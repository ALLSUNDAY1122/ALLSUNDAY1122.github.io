from __future__ import annotations

import importlib.util
import sys
import types
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
TARGET = HERE / "test_differential_execute_resume.py"
_MISSING = object()
_TARGET_MODULE = "_l1_a42_execute_resume_isolation_test_target"
_PROBE_MODULE = "_l1_a42_differential_execute_probe"


def _restore(name: str, previous) -> None:
    if previous is _MISSING:
        sys.modules.pop(name, None)
    else:
        sys.modules[name] = previous


def _import_target() -> None:
    spec = importlib.util.spec_from_file_location(_TARGET_MODULE, TARGET)
    if spec is None or spec.loader is None:
        raise AssertionError("target import spec unavailable")
    module = importlib.util.module_from_spec(spec)
    sys.modules[_TARGET_MODULE] = module
    try:
        spec.loader.exec_module(module)
    finally:
        sys.modules.pop(_TARGET_MODULE, None)


class DifferentialExecuteResumeIsolationTests(unittest.TestCase):
    def test_import_restores_preexisting_common_resume_probe_and_path(self):
        sentinel_common = types.ModuleType("differential_common")
        sentinel_resume = types.ModuleType("differential_resume")
        sentinel_probe = types.ModuleType(_PROBE_MODULE)
        tracked = ("differential_common", "differential_resume", _PROBE_MODULE)
        previous = {name: sys.modules.get(name, _MISSING) for name in tracked}
        previous_path = list(sys.path)
        try:
            sys.modules["differential_common"] = sentinel_common
            sys.modules["differential_resume"] = sentinel_resume
            sys.modules[_PROBE_MODULE] = sentinel_probe
            _import_target()
            self.assertIs(sys.modules.get("differential_common"), sentinel_common)
            self.assertIs(sys.modules.get("differential_resume"), sentinel_resume)
            self.assertIs(sys.modules.get(_PROBE_MODULE), sentinel_probe)
            self.assertEqual(sys.path, previous_path)
        finally:
            sys.path[:] = previous_path
            for name, value in previous.items():
                _restore(name, value)

    def test_import_does_not_create_bare_name_modules_when_initially_absent(self):
        tracked = ("differential_common", "differential_resume", _PROBE_MODULE)
        previous = {name: sys.modules.get(name, _MISSING) for name in tracked}
        previous_path = list(sys.path)
        try:
            for name in tracked:
                sys.modules.pop(name, None)
            _import_target()
            for name in tracked:
                self.assertNotIn(name, sys.modules)
            self.assertEqual(sys.path, previous_path)
        finally:
            sys.path[:] = previous_path
            for name, value in previous.items():
                _restore(name, value)

    def test_source_contains_fail_closed_isolation_contract(self):
        text = TARGET.read_text(encoding="utf-8")
        for token in (
            "isolated_execute_import",
            "previous_modules",
            "previous_path",
            "sys.path[:] = previous_path",
            "_restore_module",
            "sys.modules[_PROBE_MODULE] = module",
            "assert sys.path == _before_path",
        ):
            self.assertIn(token, text)
        self.assertNotIn("sys.modules['differential_common']=fake", text)


if __name__ == "__main__":
    unittest.main()
