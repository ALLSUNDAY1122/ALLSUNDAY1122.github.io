#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed

import import_and_audit as m


def make_job(era, meta, session, qno):
    start_id = meta["am_start"] if session == "AM" else meta["pm_start"]
    answers = meta["am_answers"] if session == "AM" else meta["pm_answers"]
    page_id = start_id + qno - 1
    qid = f"SHOSHI-R{era}-{session}-{qno:02d}"
    return era, meta, session, qno, page_id, qid, answers[qno - 1]


def build(job):
    era, meta, session, qno, page_id, qid, official = job
    extracted = m.extract_page(page_id, era, session, qno)
    subject = m.subject_for(session, qno)
    topic = m.topic_from(extracted["question"], subject)
    all_correct = era == 7 and session == "PM" and qno == 33
    short, memory = m.generic_explanation(topic, subject, extracted["choices"], official, all_correct)
    refs = extracted.pop("reference_candidates")
    return {
        "id": qid,
        "round": meta["round"],
        "source_year": meta["year"],
        "session": session,
        "source_question_no": qno,
        "subject": subject,
        "topic": topic,
        "question": extracted["question"],
        "choices": extracted["choices"],
        "answer_type": "singleChoice",
        "answer": None if all_correct else official - 1,
        "official_answer_no": official,
        "scoring_status": "all_correct" if all_correct else "normal",
        "officialCorrectionStatus": "allCorrect" if all_correct else "none",
        "officialNoticeUrl": meta.get("notice_page") if all_correct else None,
        "short_explanation": short,
        "memory_line": memory,
        "primary_basis": "法務省・当該年度司法書士試験多肢択一式問題公式正答",
        "basis_url": meta["answer_page"],
        "legal_reference_urls": list(m.SUBJECTS[subject]),
        "legal_reference_candidates": refs,
        "law_baseline": meta["baseline"],
        "current_law_status": "historical",
        "origin_type": "licensed_official",
        "source_page_url": meta["source_page"],
        "source_crosscheck_url": extracted["source_crosscheck_url"],
        "rights_basis": "法務省ウェブサイト利用条件＋公共データ利用規約1.0。出典・加工表示を行い、第三者権利素材は個別監査する。",
        "rights_checked_at": "2026-08-09",
        "is_modified": True,
        "requires_media": extracted["requires_media"],
        "crosscheck_media_urls": extracted["crosscheck_media_urls"],
        "crosscheck_sha256": extracted["crosscheck_sha256"],
        "explanation_source": "independent_summary_from_official_answer_and_primary_law_scope",
    }


def main():
    errors = []
    warnings = []
    jobs = [make_job(era, meta, session, qno)
            for era, meta in m.YEARS.items()
            for session in ("AM", "PM")
            for qno in range(1, 36)]
    questions = []
    with ThreadPoolExecutor(max_workers=16) as ex:
        futs = {ex.submit(build, job): job for job in jobs}
        for fut in as_completed(futs):
            job = futs[fut]
            try:
                q = fut.result()
                questions.append(q)
                if not q["legal_reference_candidates"]:
                    warnings.append(f"{q['id']}: exact article/case token not extracted; subject-level primary law only")
            except Exception as exc:
                errors.append(f"{job[5]}: extract {type(exc).__name__}: {exc}")
    questions.sort(key=lambda q: (q["round"], q["session"], q["source_question_no"]))

    if len(questions) != 210:
        errors.append(f"total questions {len(questions)}/210")
    ids = [q["id"] for q in questions]
    for qid, count in Counter(ids).items():
        if count != 1:
            errors.append(f"duplicate id {qid} x{count}")
    counts = defaultdict(int)
    for q in questions:
        counts[(q["round"], q["subject"])] += 1
        for fld in ("question","choices","short_explanation","memory_line","primary_basis","basis_url","law_baseline","rights_basis","source_page_url"):
            if not q.get(fld):
                errors.append(f"{q['id']}: missing {fld}")
        if len(q["choices"]) != 5 or len(set(q["choices"])) != 5:
            errors.append(f"{q['id']}: choices invalid {q['choices']}")
        if q["scoring_status"] == "all_correct":
            if q["answer"] is not None:
                errors.append(f"{q['id']}: all_correct with answer")
        elif not isinstance(q["answer"], int) or not 0 <= q["answer"] < 5:
            errors.append(f"{q['id']}: answer invalid {q['answer']}")
        if q["requires_media"]:
            errors.append(f"{q['id']}: official media/table reconstruction required before PASS")
    for rnd in range(1, 4):
        for subject, expected in m.EXPECTED_PER_ROUND.items():
            if counts[(rnd, subject)] != expected:
                errors.append(f"round {rnd}/{subject}: {counts[(rnd,subject)]}/{expected}")

    norm = defaultdict(list)
    for q in questions:
        norm[m.normalize(q["question"])].append(q["id"])
    for qids in norm.values():
        if len(qids) > 1:
            errors.append(f"exact duplicate text: {qids}")

    m.QUESTION_OUT.write_text(json.dumps(questions, ensure_ascii=False, indent=2), encoding="utf-8")
    config = {
        "qualification": "司法書士試験・択一式",
        "questions_file": "questions.generated.json",
        "rounds": 3,
        "subjects": m.EXPECTED_PER_ROUND,
        "similarity_threshold": 0.995,
        "required_fields": ["id","round","subject","topic","question","choices","short_explanation","memory_line","primary_basis","basis_url","law_baseline","origin_type","rights_basis","source_page_url","rights_checked_at"]
    }
    m.CONFIG_OUT.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
    report = {
        "cycle": 2,
        "status": "PASS" if not errors else "FAIL",
        "generated": len(questions),
        "media_dependent": [q["id"] for q in questions if q["requires_media"]],
        "warnings": warnings,
        "errors": errors,
        "rules": {
            "official_answers": "MOJ annual official answer manifest",
            "question_text": "public transcription crosscheck; third-party explanation prose not stored",
            "explanation": "independent fixed summary; no online AI generation",
            "law_status": "historical",
            "media": "must be reconstructed from official source before PASS"
        }
    }
    m.REPORT_OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"cycle":2,"status":report["status"],"generated":len(questions),"media":len(report["media_dependent"]),"errors":len(errors),"warnings":len(warnings)}, ensure_ascii=False))
    for e in errors[:100]:
        print("FAIL:", e)
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
