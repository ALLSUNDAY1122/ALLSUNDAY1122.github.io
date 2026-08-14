#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BATCH_DIR = ROOT / "question-batches"

EVIDENCE = {
    "RIGAKU-R58-AM-035": ["https://pmc.ncbi.nlm.nih.gov/articles/PMC10353873/"],
    "RIGAKU-R58-AM-037": ["https://pubmed.ncbi.nlm.nih.gov/27632823/"],
    "RIGAKU-R58-AM-080": ["https://pubmed.ncbi.nlm.nih.gov/9517309/"],
    "RIGAKU-R58-PM-033": ["https://pubmed.ncbi.nlm.nih.gov/27495103/"],
    "RIGAKU-R58-PM-039": ["https://pubmed.ncbi.nlm.nih.gov/21680875/"],
    "RIGAKU-R58-PM-044": ["https://pubmed.ncbi.nlm.nih.gov/40946705/"],
    "RIGAKU-R58-PM-074": [
        "https://pubmed.ncbi.nlm.nih.gov/7886280/",
        "https://pubmed.ncbi.nlm.nih.gov/34338053/",
    ],
}


def main() -> int:
    found: set[str] = set()
    changed_files: list[str] = []

    for path in sorted(BATCH_DIR.glob("questions-*.json")):
        original = path.read_text(encoding="utf-8")
        data = json.loads(original)
        for question in data:
            sid = question.get("id")
            refs = EVIDENCE.get(sid)
            if refs is None:
                continue
            found.add(sid)
            question["sourceRefs"] = refs
            embedded = question.get("contentAudit")
            if isinstance(embedded, dict):
                embedded["evidenceRefs"] = refs
                note = str(embedded.get("note", "")).strip()
                suffix = "最終根拠を検索結果ページから特定論文・ガイドラインへ固定済み。"
                if suffix not in note:
                    embedded["note"] = (note + " " + suffix).strip()

        rendered = json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n"
        if rendered != original:
            path.write_text(rendered, encoding="utf-8")
            changed_files.append(path.name)

    missing = sorted(set(EVIDENCE) - found)
    if missing:
        raise SystemExit(f"missing question ids: {missing}")

    print(f"evidence targets found: {len(found)}")
    print(f"changed files: {len(changed_files)}")
    for name in changed_files:
        print(f"- {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
