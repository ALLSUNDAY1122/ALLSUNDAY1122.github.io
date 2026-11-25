#!/usr/bin/env python3
"""Mac-less proof that the kangoshi paywall has Guideline 3.1.2 legal links."""
from __future__ import annotations
import json, sys
from pathlib import Path

PRIVACY = "https://allsunday1122.github.io/kangoshi-sprint/privacy.html"
EULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

def repo_candidates() -> list[Path]:
    here = Path(__file__).resolve()
    return [
        here.parents[1] / "kangoshi-sprint/ios/Sources/PaywallView.swift",  # this free-fix copy
        Path("/workspace/kangoshi-work/kangoshi-sprint/ios/Sources/PaywallView.swift"),
        Path.cwd() / "kangoshi-sprint/ios/Sources/PaywallView.swift",
    ]

def main() -> int:
    # Prefer the replacement file beside this script's package, then cwd/repo.
    paths = [p for p in repo_candidates() if p.exists()]
    if not paths:
        print(json.dumps({"pass": False, "errors": ["PaywallView.swift not found"]}, ensure_ascii=False, indent=2))
        return 1
    path = paths[0]
    text = path.read_text(encoding="utf-8")
    errors = []
    if PRIVACY not in text:
        errors.append(f"missing privacy URL {PRIVACY}")
    if EULA not in text:
        errors.append(f"missing Apple Standard EULA URL {EULA}")
    if 'Link("プライバシーポリシー"' not in text and "Link(\"プライバシーポリシー\"" not in text:
        errors.append("missing tappable Link プライバシーポリシー")
    if 'Link("利用規約"' not in text and "Link(\"利用規約\"" not in text:
        errors.append("missing tappable Link 利用規約")
    if "1か月ごとの自動更新" not in text:
        errors.append("missing explicit 1-month auto-renewal disclosure")
    if "サブスクリプション" not in text:
        errors.append("missing cancellation path (サブスクリプション)")
    report = {"pass": not errors, "paywall": str(path), "privacy": PRIVACY, "eula": EULA, "errors": errors}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1

if __name__ == "__main__":
    sys.exit(main())
