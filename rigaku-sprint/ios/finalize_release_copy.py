#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent

REPLACEMENTS = {
    ROOT / "Sources" / "RigakuRootViewV2.swift": [
        (
            'Text("模擬試験")',
            'Text("第58〜60回ベース模試")',
        ),
        (
            'Text("各回200問がすべて内容・正答・権利監査を通過した時点で、その回の模試を解放します。")',
            'Text("各回200枠の公式出題範囲・配点をもとに、問題文と図版を権利・内容監査した独自問題で再構成しています。")',
        ),
        (
            'Text("第\\(exam.round)回")',
            'Text("第\\(exam.round)回ベース模試")',
        ),
        (
            'Text(ready ? "本番形式を開始できます" : "全問PASS後に解放")',
            'Text(ready ? "200問のベース模試を開始" : "全問PASS後に解放")',
        ),
    ],
    ROOT / "Sources" / "RigakuStudyView.swift": [
        (
            'case .mock(let round): return "第\\(round)回 模試"',
            'case .mock(let round): return "第\\(round)回ベース模試"',
        ),
        (
            'Text("第\\(round)回の公式配点を再現：一般1点、実地3点。厚生労働省が採点対象外とした問題は0点として集計します。")',
            'Text("第\\(round)回の公式配点を再現して集計します。問題文・図版は権利と内容を監査した独自問題で再構成し、厚生労働省が採点対象外とした問題は0点として扱います。")',
        ),
    ],
}


def main() -> int:
    changed: list[str] = []
    for path, replacements in REPLACEMENTS.items():
        original = path.read_text(encoding="utf-8")
        updated = original
        for old, new in replacements:
            if old in updated:
                updated = updated.replace(old, new)
            elif new not in updated:
                raise SystemExit(f"expected copy not found in {path.name}: {old}")
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed.append(path.name)

    print(f"UI copy files changed: {len(changed)}")
    for name in changed:
        print(f"- {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
