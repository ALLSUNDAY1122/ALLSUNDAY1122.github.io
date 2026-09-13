#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
gm1 = (ROOT / "apps/sanitary-manager-2/gm1.js").read_text(encoding="utf-8")
gm2 = (ROOT / "apps/sanitary-manager-2/gm2.js").read_text(encoding="utf-8")
gm3 = (ROOT / "apps/sanitary-manager-2/gm3.js").read_text(encoding="utf-8")
gm4 = (ROOT / "apps/sanitary-manager-2/gm4.js").read_text(encoding="utf-8")

errors=[]
def require(ok,msg):
    if not ok: errors.append(msg)

# Start / understand / progress / review / retry learning loop.
require("function startDaily()" in gm2, "daily learning start is missing")
require("ここだけ覚える" in gm3 and "もう少し詳しく" in gm3, "answer understanding surfaces are missing")
require("function historyScreen()" in gm4 and "苦手一覧" in gm4, "progress/review surfaces are missing")
require("間違えた問題をすぐ復習" in gm3 and "もう一度${total}問" in gm3, "immediate review/retry actions are missing")
require("function resumeSession()" in gm2 and "続きから再開" in gm2, "interruption recovery is missing")

# 30-question mock contract and official threshold logic.
require("function startFullMock(set)" in gm2, "30-question mock entry is missing")
require("qs.length!==30" in gm2, "30-question mock must fail closed when a set is incomplete")
require("mode:'fullmock'" in gm2, "30-question mock session mode is missing")
require("function fullMockAssessment()" in gm3, "mock assessment is missing")
require("total===30" in gm3 and "totalRate>=60" in gm3 and "rate>=40" in gm3,
        "mock assessment must require 30 questions, 60% total, and 40% per subject")
for subject in ("関係法令","労働衛生","労働生理"):
    require(subject in gm1, f"required subject missing: {subject}")
require("SUBJECTS.every(s=>subjects[s].passed)" in gm3, "all subjects must pass the 40% floor")
require("fullMockKey(session.examSet)" in gm3, "full mock result persistence is missing")

# Entitlement boundary must also protect resume and review/retry paths.
require("qs.some(q=>q.examSet!==FREE_SET)" in gm2, "resume premium boundary is missing")
require("qs.some(q=>q.examSet!==FREE_SET)" in gm3, "review/retry premium boundary is missing")
require("set!==FREE_SET" in gm2, "premium mock boundary is missing")

if errors:
    print("FAIL: HM2 learning Acceptance Contract")
    for e in errors: print(f"- {e}")
    raise SystemExit(1)

print("PASS: start -> understand -> progress -> review -> retry loop is statically represented")
print("PASS: 30-question mock enforces total 60% and every-subject 40% thresholds")
print("PASS: premium boundary covers mock, resume, and review/retry paths")
