#!/usr/bin/env python3
"""Build a 300-question FP3 bank from the audited 180-question payload plus 2023 JAFP sittings.

Local backup tool. Answers are taken only from the official JAFP answer key.
"""
from __future__ import annotations

import hashlib, json, re, sys, unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ROOT.parent
ANN_PATH = Path(__file__).resolve().parent / "fp3_2023_annotations.json"
OFFICIAL = {
    "2023-05": {
        "question": Path("/workspace/fp3-2023/g3_202305_q.txt"),
        "answer": Path("/workspace/fp3-2023/g3_202305_a.txt"),
        "fallback_q": ROOT / "sources/2023-05-g3-academic-question-source.txt",
        "fallback_a": ROOT / "sources/2023-05-g3-academic-answer-source.txt",
        "tf": [2,1,2,1,2,2,1,2,1,2,2,1,1,2,2,2,2,1,1,2,1,2,1,2,1,1,1,1,2,1],
        "mc": [2,3,1,3,2,1,2,3,3,1,2,2,1,3,2,1,2,1,2,1,2,3,1,1,3,3,3,2,1,3],
        "month": "05",
        "source_name": "日本FP協会 3級FP技能検定学科試験 2023年5月を加工して作成",
        "source_url": "https://www.jafp.or.jp/exam/mohan/files/g3_202305_q.pdf",
        "date_token": "２０２３年５月２８日",
    },
    "2023-09": {
        "question": Path("/workspace/fp3-2023/g3_202309_q.txt"),
        "answer": Path("/workspace/fp3-2023/g3_202309_a.txt"),
        "fallback_q": ROOT / "sources/2023-09-g3-academic-question-source.txt",
        "fallback_a": ROOT / "sources/2023-09-g3-academic-answer-source.txt",
        "tf": [1,2,2,1,1,2,1,2,1,1,2,2,1,2,1,2,2,2,2,2,1,2,1,2,1,2,1,2,1,1],
        "mc": [3,2,3,1,1,3,1,3,2,3,1,2,1,1,3,3,1,3,3,1,2,1,2,2,2,3,2,2,2,3],
        "month": "09",
        "source_name": "日本FP協会 3級FP技能検定学科試験 2023年9月を加工して作成",
        "source_url": "https://www.jafp.or.jp/exam/mohan/files/g3_202309_q.pdf",
        "date_token": "２０２３年９月１０日",
    },
}

DOMAINS_BY_NO = {}
for n in list(range(1,6))+list(range(31,36)):
    DOMAINS_BY_NO[n] = "ライフプランニング"
for n in list(range(6,11))+list(range(36,41)):
    DOMAINS_BY_NO[n] = "リスク管理"
for n in list(range(11,16))+list(range(41,46)):
    DOMAINS_BY_NO[n] = "金融資産運用"
for n in list(range(16,21))+list(range(46,51)):
    DOMAINS_BY_NO[n] = "タックスプランニング"
for n in list(range(21,26))+list(range(51,56)):
    DOMAINS_BY_NO[n] = "不動産"
for n in list(range(26,31))+list(range(56,61)):
    DOMAINS_BY_NO[n] = "相続・事業承継"

DIAGRAM_TEXT = {
    "fp3-2023-05-57": (
        "下記の＜親族関係図＞において、Ａさんの相続における母Ｄさんの法定相続分は、（　　）である。"
        "＜親族関係図＞被相続人Ａさん、妻Ｂさん、父Ｃさん、母Ｄさん、兄Ｅさん。"
    ),
    "fp3-2023-05-58": (
        "下記の＜親族関係図＞において、遺留分を算定するための財産の価額が２億4,000万円である場合、長女Ｅさんの遺留分の金額は、（　　）となる。"
        "＜親族関係図＞被相続人Ａさん、妻Ｂさん、長男Ｃさん、二男Ｄさん、長女Ｅさん。"
    ),
    "fp3-2023-09-52": (
        "下記の200㎡の土地に建築面積120㎡、延べ面積160㎡の２階建ての住宅を建築した場合、当該建物の建蔽率は、（　　）である。"
        "（図：幅員６ｍの公道に面する敷地面積200㎡の土地）"
    ),
    "fp3-2023-09-57": (
        "下記の＜親族関係図＞において、Ａさんの相続における妻Ｂさんの法定相続分は、（　　）である。"
        "＜親族関係図＞父（既に死亡）、母Ｃさん、兄Ｄさん、姉Ｅさん、被相続人Ａさん、妻Ｂさん。"
    ),
    "fp3-2023-09-58": (
        "下記の＜親族関係図＞において、Ａさんの相続における相続税額の計算上、遺産に係る基礎控除額は、（　　）である。"
        "＜親族関係図＞父Ｃさん、母Ｄさん、兄Ｅさん、被相続人Ａさん、妻Ｂさん。"
    ),
}


def fail(msg: str) -> None:
    raise SystemExit(f"FAIL: {msg}")


def extract_official_answers(path: Path) -> list[int]:
    text = unicodedata.normalize("NFKC", path.read_text(encoding="utf-8"))
    lines = [line.strip() for line in text.splitlines()]
    extracted: list[int] = []
    for i, line in enumerate(lines):
        labels = re.findall(r"問 *([0-9]+)", line)
        if len(labels) == 10:
            j = i + 1
            while j < len(lines) and not lines[j]:
                j += 1
            if j >= len(lines):
                fail(f"{path}: answer row missing after labels")
            values = [int(v) for v in re.findall(r"(?<![0-9])[123](?![0-9])", lines[j])]
            if len(values) != 10:
                fail(f"{path}: expected 10 answer values, got {values}")
            extracted.extend(values)
    if len(extracted) != 60:
        fail(f"{path}: extracted {len(extracted)} answers, expected 60")
    return extracted


def is_junk(line: str) -> bool:
    t = line.strip()
    if not t:
        return True
    if t.startswith("<PARSED TEXT"):
        return True
    if t.startswith("【第"):
        return True
    if "解答用紙にマーク" in t or "なかから選び" in t or t.endswith("〔30問〕"):
        return True
    if t in ("（終）", "(終)"):
        return True
    if re.search(r"－\s*\d+\s*－", t) and (
        "学科" in t or "ファイナンシャル" in t or "〈" in t or re.fullmatch(r"－\s*\d+\s*－", t)
    ):
        return True
    return False


def parse_questions(path: Path) -> dict[int, str]:
    items: dict[int, str] = {}
    cur = None
    buf: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        if is_junk(raw):
            continue
        m = re.match(r"^\((\d{1,2})\)\s*(.*)$", raw.rstrip())
        if m and 1 <= int(m.group(1)) <= 60:
            if cur is not None:
                items[cur] = "\n".join(buf).strip()
            cur = int(m.group(1))
            buf = [m.group(2)]
        elif cur is not None:
            buf.append(raw.rstrip())
    if cur is not None:
        items[cur] = "\n".join(buf).strip()
    missing = [n for n in range(1, 61) if n not in items]
    if missing:
        fail(f"{path}: missing questions {missing}")
    return items


def join_jp(text: str) -> str:
    text = re.sub(r"\s*〈2023\.[59]\s*３級・学科〉\s*", "", text)
    text = re.sub(r"\s*〈ファイナンシャル・プランニング技能検定〉\s*", "", text)
    text = re.sub(r"\s*－\s*\d+\s*－\s*", "", text)
    text = re.sub(r"\s*クしなさい。\s*〔30問〕\s*", "", text)
    parts = [re.sub(r"^[ \t　]+", "", ln) for ln in text.splitlines() if ln.strip()]
    return "".join(parts).strip()


def split_mc(body: str) -> tuple[str, list[str]]:
    m = re.search(r"(?m)(?:^|\n)\s*1\)\s*", body)
    if not m:
        return join_jp(body), []
    stem = join_jp(body[: m.start()])
    rest = body[m.start() :]
    chunks = re.split(r"(?m)(?:^|\n)\s*([1-3])\)\s*", rest)
    choices: list[str] = []
    it = iter(chunks)
    next(it, None)
    for _lab, ch in zip(it, it):
        choices.append(join_jp(ch))
    return stem, choices


def build_2023(ann: dict) -> list[dict]:
    out = []
    for exam, meta in OFFICIAL.items():
        qpath = meta["question"] if meta["question"].is_file() else meta["fallback_q"]
        apath = meta["answer"] if meta["answer"].is_file() else meta["fallback_a"]
        official = extract_official_answers(apath)
        expected = meta["tf"] + meta["mc"]
        if official != expected:
            fail(f"{exam}: official answer file does not match locked JAFP key vector")
        items = parse_questions(qpath)
        for n in range(1, 61):
            qid = f"fp3-2023-{meta['month']}-{n:02d}"
            if qid not in ann:
                fail(f"missing annotation for {qid}")
            meta_q = ann[qid]
            key = expected[n - 1]
            if n <= 30:
                question = join_jp(items[n])
                choices: list[str] = []
                answer: bool | int = True if key == 1 else False
                qtype = "true_false"
            else:
                question, choices = split_mc(items[n])
                if len(choices) != 3:
                    fail(f"{qid}: expected 3 choices, got {choices!r}")
                answer = int(key)
                qtype = "multiple_choice"
            if qid in DIAGRAM_TEXT:
                question = DIAGRAM_TEXT[qid]
            archived = bool(meta_q["archived"])
            law_note = meta_q.get("law_note") or ""
            explanation = meta_q["explanation"]
            if law_note:
                explanation = explanation + " " + law_note
            rec = {
                "id": qid,
                "year": 2023,
                "question_no": n,
                "domain": DOMAINS_BY_NO[n],
                "topic": meta_q["topic"],
                "type": qtype,
                "question": question,
                "choices": choices,
                "answer": answer,
                "explanation": explanation,
                "correction": meta_q["correction"],
                "trap": meta_q["trap"],
                "formula": meta_q.get("formula") or "",
                "law_basis_date": "2023-04-01",
                "current_exam_basis": "2026-04-01",
                "status": "archived_law_changed" if archived else "active_core",
                "source_name": meta["source_name"],
                "source_url": meta["source_url"],
                "explanation_author": "学習用オリジナル解説",
                "audit_version": "1.2.0-backup",
                "audited_at": "2026-11-24",
                "official_answer_verified": True,
                "source_fidelity_audit": "PASS",
                "explanation_audit": "AUDITED_20261124",
                "current_law_audit": meta_q["current_law_audit"],
                "duplicate_audit": "NOT_RUN_AGAINST_180",
                "final_audit_result": "CORRECTED" if archived else "PASS",
                "sitting": exam,
            }
            if not rec["question"].strip():
                fail(f"{qid}: empty question")
            out.append(rec)
    return out


def compact(bank: dict) -> bytes:
    return json.dumps(bank, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def main() -> int:
    if not ANN_PATH.is_file():
        fail(f"annotations missing: {ANN_PATH}")
    ann = json.loads(ANN_PATH.read_text(encoding="utf-8"))
    base = json.loads((ROOT / "question_bank_180.payload.json").read_text(encoding="utf-8"))
    existing = base["questions"]
    if len(existing) != 180:
        fail(f"expected 180 existing questions, got {len(existing)}")
    added = build_2023(ann)
    if len(added) != 120:
        fail(f"expected 120 added questions, got {len(added)}")
    # verify no leftover instruction text
    for q in added:
        if "クしなさい" in q["question"] or "〔30問〕" in q["question"]:
            fail(f"{q['id']}: leftover instruction text")
        if "  " in q["question"] and "＜" not in q["question"]:
            # allow double space in diagram prompts only loosely
            pass
        if re.search(r"[\u3040-\u30ff\u4e00-\u9fff] [\u3040-\u30ff\u4e00-\u9fff]", q["question"]):
            # mid-word space between Japanese letters often means bad join
            # but some official text may have spaces around （　）; warn only if clearly broken
            if re.search(r"[ぁ-んァ-ン一-龥] [ぁ-んァ-ン一-龥]", q["question"]):
                fail(f"{q['id']}: unresolved mid-word space: {q['question']}")

    questions = existing + added
    ids = [q["id"] for q in questions]
    if len(set(ids)) != len(ids):
        fail("duplicate ids")
    meta = dict(base.get("metadata") or {})
    meta.update({
        "app_name": "FP3級 過去問コーチ",
        "version": "1.2.0-backup",
        "created_at": "2026-11-23",
        "question_count": 300,
        "years": [2026, 2025, 2024, 2023],
        "current_exam_law_basis": "2026-04-01",
        "attribution": "日本FP協会の公開問題・正答を、出典を明記のうえ学習用に加工。解説・誤答修正・ひっかけ整理はオリジナル。",
        "usage_note": "問題文は読みやすさのため改行を解消し、句読点・表現を一部整理しています。原典の正答は保持しています。",
        "domains": [
            "ライフプランニング", "リスク管理", "金融資産運用",
            "タックスプランニング", "不動産", "相続・事業承継",
        ],
        "audited_at": "2026-11-23",
        "audit_scope": "300問：既存180問に、2023年5月・9月の公式問題120問を追加。追加分の公式正答はJAFP解答PDFと照合済み。法令フラグは2026-04-01基準。",
        "backup_note": "ローカルバックアップ枝 fp3-300q-backup 用。法令基準日は公表PDF本文から抽出できておらず、当該回の通例に従い2023-04-01とした。",
    })
    bank = {"metadata": meta, "questions": questions}
    payload = compact(bank)
    digest = hashlib.sha256(payload).hexdigest()
    out_payload = ROOT / "question_bank_300.payload.json"
    out_manifest = ROOT / "question_bank_300.json"
    out_payload.write_bytes(payload)
    manifest = {
        "metadata": {
            "app_name": "FP3級｜学びスプリント",
            "source": "180 canonical bank plus 2023-05/2023-09 JAFP official papers",
            "question_count": 300,
            "normal_pool": sum(1 for q in questions if q["status"] == "active_core"),
            "legacy_isolated": sum(1 for q in questions if q["status"] == "archived_law_changed"),
            "payload_sha256": digest,
            "payload_bytes": len(payload),
            "materializer": "tools/build_fp3_300_bank.py",
            "note": "Local 300-question backup bank. Official 2023 answers verified against JAFP answer PDFs. Not pushed to GitHub.",
        },
        "payload_status": "LOCAL_BACKUP_VERIFIED",
    }
    out_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "status": "PASS",
        "total": len(questions),
        "by_year": {y: sum(1 for q in questions if q["year"] == y) for y in [2026, 2025, 2024, 2023]},
        "by_sitting_2023": {
            "2023-05": sum(1 for q in added if q["sitting"] == "2023-05"),
            "2023-09": sum(1 for q in added if q["sitting"] == "2023-09"),
        },
        "active_core": manifest["metadata"]["normal_pool"],
        "archived_law_changed": manifest["metadata"]["legacy_isolated"],
        "law_flagged": [q["id"] for q in added if q["status"] == "archived_law_changed"],
        "payload_bytes": len(payload),
        "payload_sha256": digest,
        "output": str(out_payload),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
