#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CANONICAL_ROOT = ROOT / "questions"

OVERRIDES = {
    "K114-AM002": {
        "dynamicEvidenceStatus": "verified",
        "evidenceCheckedDate": "2026-08-14",
        "additionalEvidenceRefs": [
            "https://www.mhlw.go.jp/toukei/saikin/hw/seimei/list54-57-01.html"
        ],
        "verificationNote": "厚生労働省の生命表定義で、0歳の平均余命を平均寿命とする定義を現行確認。"
    },
    "K113-PM004": {
        "dynamicEvidenceStatus": "verified",
        "evidenceCheckedDate": "2026-08-14",
        "additionalEvidenceRefs": [
            "https://www.mhlw.go.jp/topics/kaigo/kentou/tp0814-1.html",
            "https://www.mhlw.go.jp/web/t_doc?dataId=00ta4435&dataType=1&pageNo=1"
        ],
        "verificationNote": "厚生労働省の身体拘束ゼロ関連資料で、自分で降りられないようベッドを柵で囲む行為を身体拘束の具体例として確認。"
    }
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def dump(path: Path, data) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    index = {}
    docs = {}
    for exam in (115, 114, 113):
        path = CANONICAL_ROOT / f"exam-{exam}" / "required.json"
        doc = load(path)
        docs[path] = doc
        for q in doc.get("questions", []):
            index[q["id"]] = q

    missing = sorted(set(OVERRIDES) - set(index))
    if missing:
        raise SystemExit(f"canonical override IDs missing: {missing}")

    for qid, override in OVERRIDES.items():
        q = index[qid]
        q["dynamicEvidenceStatus"] = override["dynamicEvidenceStatus"]
        q["evidenceCheckedDate"] = override["evidenceCheckedDate"]
        refs = list(q.get("explanationEvidenceRefs") or [])
        for ref in override["additionalEvidenceRefs"]:
            if ref not in refs:
                refs.append(ref)
        q["explanationEvidenceRefs"] = refs
        q["dynamicEvidenceVerification"] = {
            "status": override["dynamicEvidenceStatus"],
            "checkedDate": override["evidenceCheckedDate"],
            "evidenceRefs": override["additionalEvidenceRefs"],
            "note": override["verificationNote"]
        }

    for path, doc in docs.items():
        dump(path, doc)

    print(json.dumps({"status": "PASS", "applied": sorted(OVERRIDES)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
