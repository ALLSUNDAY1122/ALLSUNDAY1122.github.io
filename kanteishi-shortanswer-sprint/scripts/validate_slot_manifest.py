#!/usr/bin/env python3
import json
import sys
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else "data/production-slot-manifest.json")
data = json.loads(path.read_text(encoding="utf-8"))
errors = []
expected_subjects = {
    "不動産に関する行政法規": 40,
    "不動産の鑑定評価に関する理論": 40,
}
expected_dates = {1: "2025-09-01", 2: "2024-09-01", 3: "2023-09-01"}
rounds = data.get("rounds", [])
if data.get("status") != "production_target_only": errors.append("status must remain production_target_only until content audit passes")
if len(rounds) != 3: errors.append(f"round count {len(rounds)} != 3")
calculated = 0
for row in rounds:
    number = row.get("round")
    if row.get("reference_date") != expected_dates.get(number): errors.append(f"R{number} reference_date mismatch")
    if row.get("subjects") != expected_subjects: errors.append(f"R{number} subjects/count mismatch")
    calculated += sum(row.get("subjects", {}).values())
if data.get("total") != 240: errors.append("manifest total must be 240")
if calculated != 240: errors.append(f"calculated total {calculated} != 240")
if errors:
    print("FAIL production slot manifest")
    for error in errors: print("-", error)
    sys.exit(1)
print("PASS production slot manifest: 3 rounds x (40 administrative law + 40 valuation theory) = 240")
