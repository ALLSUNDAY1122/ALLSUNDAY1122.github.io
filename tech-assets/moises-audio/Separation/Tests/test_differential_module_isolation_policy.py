from __future__ import annotations

import ast
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _subscript_key(node: ast.Subscript) -> str | None:
    value = node.value
    if not (
        isinstance(value, ast.Attribute)
        and value.attr == "modules"
        and isinstance(value.value, ast.Name)
        and value.value.id == "sys"
    ):
        return None
    slice_node = node.slice
    if isinstance(slice_node, ast.Constant) and isinstance(slice_node.value, str):
        return slice_node.value
    return None


def _top_level_differential_module_writes(path: Path) -> list[tuple[int, str]]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    writes: list[tuple[int, str]] = []
    for statement in tree.body:
        targets: list[ast.expr] = []
        if isinstance(statement, ast.Assign):
            targets.extend(statement.targets)
        elif isinstance(statement, ast.AnnAssign):
            targets.append(statement.target)
        elif isinstance(statement, ast.AugAssign):
            targets.append(statement.target)
        for target in targets:
            if isinstance(target, ast.Subscript):
                key = _subscript_key(target)
                if key is not None and key.startswith("differential_"):
                    writes.append((statement.lineno, key))
    return writes


class DifferentialModuleIsolationPolicyTests(unittest.TestCase):
    def test_differential_tests_do_not_mutate_bare_modules_at_import_scope(self):
        violations: list[str] = []
        for path in sorted(HERE.glob("test_differential*.py")):
            if path.name == Path(__file__).name:
                continue
            for line, module_name in _top_level_differential_module_writes(path):
                violations.append(f"{path.name}:{line}:{module_name}")
        self.assertEqual([], violations)

    def test_execute_resume_has_explicit_exact_restore_contract(self):
        path = HERE / "test_differential_execute_resume.py"
        text = path.read_text(encoding="utf-8")
        required = (
            "isolated_execute_import",
            "previous_modules",
            "previous_path",
            "sys.path[:] = previous_path",
            "_restore_module",
            "_before_modules",
            "_before_path",
        )
        for token in required:
            self.assertIn(token, text)

    def test_gate_probe_keeps_existing_a40_restore_contract(self):
        path = HERE / "test_differential_gate_a20_import.py"
        text = path.read_text(encoding="utf-8")
        for token in (
            "isolated_gate_import",
            "previous_modules",
            "previous_path",
            "sys.path[:] = previous_path",
            "_restore_module",
        ):
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
