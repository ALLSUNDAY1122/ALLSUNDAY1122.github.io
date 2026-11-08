"""Keep global FP regression aligned with the official-source fail-closed gate.

The former test fixture expected 600 original questions and must not silently
reintroduce the superseded product contract.
"""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEST_MODULE = ROOT / "fp2-manabi-sprint" / "tools" / "test_audit_product_bank.py"
spec = importlib.util.spec_from_file_location("fp2_official_gate_tests", TEST_MODULE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def load_tests(loader, standard_tests, pattern):
    return loader.loadTestsFromModule(module)
