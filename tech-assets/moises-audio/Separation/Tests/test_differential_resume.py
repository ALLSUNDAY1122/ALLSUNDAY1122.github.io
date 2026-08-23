from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent / "Evaluation"
sys.path.insert(0, str(EVAL))

from differential_resume import (
    DifferentialResumeLedger, ResumeError, apply_replacements, build_reviewer_assignments,
    canonical_json_bytes, filter_reviews_for_active_assignments, load_replacements,
    load_reviewer_roster, reviewer_assignment_document, semantic_batch_payload, sha256_file,
    sha256_json,
)

PASS = 0


def ok(cond, name):
    global PASS
    if not cond:
        raise AssertionError(name)
    PASS += 1


def expect(code, fn, name):
    global PASS
    try:
        fn()
    except ResumeError as exc:
        if exc.code != code:
            raise AssertionError(f"{name}: expected {code}, got {exc.code}")
        PASS += 1
        return
    raise AssertionError(f"{name}: expected {code}")


def write(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def config(root: Path, case_count=2):
    cases=[]
    for i in range(case_count):
        fixture=root/f"fixtures/c{i}.json"
        fixture.parent.mkdir(parents=True,exist_ok=True)
        fixture.write_text(json.dumps({"fixture_id":f"C{i}","requested_roles":["vocals","other"]}),encoding="utf-8")
        cases.append({
            "case_id":f"C{i}","genre":"rock" if i==0 else "jazz","duration_bucket":"short" if i==0 else "long",
            "target_roles":["vocals","other"],"fixture_path":fixture,
            "project_run_path":root/f"runs/c{i}.project.json","reference_run_path":root/f"runs/c{i}.reference.json",
        })
    return {
        "batch_id":"BATCH-1","purpose":"REGRESSION","max_attempts":3,"timeout_seconds":30.0,
        "command":["driver","--key","{idempotency_key}"],"credential_env_names":["API_KEY"],
        "legal_gate":{"commercial_approval_basis_id":"A","privacy_retention_approval_id":"B","reference_comparison_rights_id":"C","provider_idempotency_contract_id":"D"},
        "policy":{"policy_id":"P1","max_case_failure_rate":0.1,"max_retry_fraction":0.2,"min_reviewers_per_system_per_role":1},
        "cases":cases,
    }


def review(a,score=3):
    return {"case_id":a["case_id"],"stem":a["stem"],"system_blind_id":a["system_blind_id"],"listener_id":a["reviewer_id"],"scores":{"x":score}}


def main():
    with tempfile.TemporaryDirectory() as td:
        root=Path(td); out=root/"out"; cfg=config(root)
        ok(canonical_json_bytes({"b":1,"a":2}) == canonical_json_bytes({"a":2,"b":1}),"canonical-json")
        p1=semantic_batch_payload(cfg,root)
        cfg_reordered=dict(cfg); cfg_reordered["cases"]=list(reversed(cfg["cases"]))
        p2=semantic_batch_payload(cfg_reordered,root)
        ok(sha256_json(p1)==sha256_json(p2),"case-order-independent-semantic")

        ledger=DifferentialResumeLedger(root,out,cfg)
        first=ledger.batch_identity_sha256
        ledger2=DifferentialResumeLedger(root,out,cfg_reordered)
        ok(ledger2.batch_identity_sha256==first,"resume-same-semantic")
        ok(ledger.data["acceptance_policy_sha256"]==sha256_json(cfg["policy"]),"policy-hash")
        ok(len(ledger.data["cases"])==2,"case-count")
        ok(all(len(v["case_identity_sha256"])==64 for v in ledger.data["cases"].values()),"case-identity")
        ok(all(len(v["idempotency_key_sha256"])==64 for v in ledger.data["cases"].values()),"idempotency-hash-only")
        raw=ledger.path.read_text()
        ok("l1m04-" not in raw,"no-raw-idempotency")

        mutated=dict(cfg); mutated["policy"]=dict(cfg["policy"]); mutated["policy"]["max_retry_fraction"]=0.3
        expect("L1A20_BATCH_IDENTITY_MISMATCH",lambda:DifferentialResumeLedger(root,out,mutated),"policy-drift")

        n=ledger.begin_attempt("C0")
        ok(n==1,"attempt-number")
        ledger_reload=DifferentialResumeLedger(root,out,cfg)
        ok(ledger_reload.data["cases"]["C0"]["attempts"][-1]["status"]=="STARTED","started-durable")
        ledger_reload.recover_started_attempt("C0",output_recovered=False)
        ok(ledger_reload.data["cases"]["C0"]["attempts"][-1]["status"]=="INTERRUPTED","interrupted-recovery")
        n2=ledger_reload.begin_attempt("C0"); ok(n2==2,"attempt-monotonic-after-relaunch")
        ledger_reload.finish_attempt("C0",n2,status="FAIL",exit_code=5,wall_time_ms=12.3456,stable_error_code="DRIVER_EXIT_5")
        ok(ledger_reload.attempt_count("C0")==2,"attempt-history-retained")
        expect("L1A20_ATTEMPT_SEQUENCE_INVALID",lambda:ledger_reload.finish_attempt("C0",99,status="PASS",exit_code=0,wall_time_ms=1,stable_error_code=None),"attempt-sequence")

        proj=cfg["cases"][0]["project_run_path"]; write(proj,b'{"ok":1}')
        ledger_reload.mark_project_ready("C0",proj,source="EXECUTED")
        ok(ledger_reload.trusted_case_artifact("C0","project_run_manifest",proj),"trusted-project")
        write(proj,b'{"ok":2}')
        expect("L1A20_EVIDENCE_MUTATED",lambda:ledger_reload.trusted_case_artifact("C0","project_run_manifest",proj),"project-mutation")
        write(proj,b'{"ok":1}')
        ok(ledger_reload.trusted_case_artifact("C0","project_run_manifest",proj),"project-restored")

        n3=ledger_reload.begin_attempt("C1"); ok(n3==1,"case1-attempt-start")
        p1run=cfg["cases"][1]["project_run_path"]; write(p1run,b'run')
        ledger_reload.recover_started_attempt("C1",output_recovered=True)
        ledger_reload.mark_project_ready("C1",p1run,source="RECOVERED_AFTER_TERMINATION")
        ok(ledger_reload.data["cases"]["C1"]["attempts"][-1]["status"]=="RECOVERED_OUTPUT","recovered-output-state")

        doc=ledger_reload.execution_document()
        ok(len(doc["cases"])==2 and len(doc["attempts"])==3,"execution-history-document")
        ok(doc["schema_version"]==2,"execution-schema-v2")

        g=root/"out/global.json"; write(g,b'global')
        ledger_reload.bind_global_artifact("comparison_input",g)
        ok(ledger_reload.trusted_global_artifact("comparison_input",g),"trusted-global")
        write(g,b'changed')
        expect("L1A20_EVIDENCE_MUTATED",lambda:ledger_reload.trusted_global_artifact("comparison_input",g),"global-mutation")
        write(g,b'global')

        roster=root/"out/reviewer-roster.json"
        expect("L1A20_REVIEWER_ROSTER_REQUIRED",lambda:load_reviewer_roster(roster,min_reviewers=2),"missing-roster")
        roster.write_text(json.dumps({"schema_version":1,"reviewer_ids":["R2","R1"]}))
        ids=load_reviewer_roster(roster,min_reviewers=2)
        ok(ids==["R1","R2"],"roster-sorted")
        roster.write_text(json.dumps({"schema_version":1,"reviewer_ids":["R1","R1"]}))
        expect("L1A20_REVIEWER_ROSTER_DUPLICATE",lambda:load_reviewer_roster(roster,min_reviewers=1),"duplicate-roster")
        roster.write_text(json.dumps({"schema_version":1,"reviewer_ids":["R1","R2","R3"]}))
        ids=load_reviewer_roster(roster,min_reviewers=2)

        a1=build_reviewer_assignments(cfg,first,ids,min_reviewers=2)
        a2=build_reviewer_assignments(cfg,first,list(reversed(ids)),min_reviewers=2)
        ok(a1==a2,"assignment-stable-roster-order")
        ok(len(a1)==2*2*2*2,"assignment-count")
        ok(len({a["assignment_id"] for a in a1})==len(a1),"assignment-id-unique")
        ok(all(a["replaces_assignment_id"] is None for a in a1),"base-assignment-not-replacement")
        doca=reviewer_assignment_document("BATCH-1",first,a1,[])
        ok(doca["blind_only"] is True,"assignment-blind-only")
        ok("revealed_system" not in json.dumps(doca),"no-reveal-in-assignment")

        repl_path=root/"out/reviewer-replacements.json"
        repl_path.write_text(json.dumps({"schema_version":1,"replacements":[]}))
        ok(load_replacements(repl_path)==[],"empty-replacements")
        source=a1[0]
        active_same,hist=apply_replacements(a1,[],first)
        ok(active_same==a1 and hist==[],"no-replacement-stable")
        existing_slot_reviewers={a["reviewer_id"] for a in a1 if a["case_id"]==source["case_id"] and a["stem"]==source["stem"] and a["system_blind_id"]==source["system_blind_id"]}
        candidate=next(r for r in ids if r not in existing_slot_reviewers)
        repl=[{"from_assignment_id":source["assignment_id"],"to_reviewer_id":candidate,"reason_code":"UNAVAILABLE"}]
        active,hist=apply_replacements(a1,repl,first)
        ok(len(active)==len(a1) and len(hist)==1,"replacement-preserves-slot-count")
        ok(hist[0]["replacement"]["replaces_assignment_id"]==source["assignment_id"],"replacement-links-source")
        ok(source["assignment_id"] not in {a["assignment_id"] for a in active},"source-superseded")
        conflict_reviewer=next(a["reviewer_id"] for a in a1 if a["case_id"]==source["case_id"] and a["stem"]==source["stem"] and a["system_blind_id"]==source["system_blind_id"] and a["assignment_id"]!=source["assignment_id"])
        expect("L1A20_REPLACEMENT_REVIEWER_CONFLICT",lambda:apply_replacements(a1,[{"from_assignment_id":source["assignment_id"],"to_reviewer_id":conflict_reviewer,"reason_code":"UNAVAILABLE"}],first),"replacement-conflict")

        repl_path.write_text(json.dumps({"schema_version":1,"replacements":[{"from_assignment_id":source["assignment_id"],"to_reviewer_id":candidate,"reason_code":"BAD_REASON"}]}))
        expect("L1A20_REPLACEMENT_REASON_INVALID",lambda:load_replacements(repl_path),"replacement-reason")

        reviews=[review(a) for a in active]
        filtered,missing,audit=filter_reviews_for_active_assignments(reviews,a1,active,hist)
        ok(len(filtered)==len(active) and not missing,"active-review-complete")
        ok(audit["superseded_review_count"]==0,"no-superseded-review-yet")
        reviews2=reviews+[review(source)]
        filtered2,missing2,audit2=filter_reviews_for_active_assignments(reviews2,a1,active,hist)
        ok(len(filtered2)==len(active) and audit2["superseded_review_count"]==1,"superseded-review-excluded")
        missing_reviews=reviews[:-1]
        _,missing3,audit3=filter_reviews_for_active_assignments(missing_reviews,a1,active,hist)
        ok(len(missing3)==1 and audit3["missing_assignment_count"]==1,"missing-review-explicit")
        bogus=dict(reviews[0]); bogus["listener_id"]="UNASSIGNED"
        expect("L1A20_UNASSIGNED_REVIEW",lambda:filter_reviews_for_active_assignments([bogus],a1,active,hist),"unassigned-review")

        roster.write_text(json.dumps({"schema_version":1,"reviewer_ids":ids},sort_keys=True))
        assignments_file=root/"out/reviewer-assignments.json"; assignments_file.write_text(json.dumps(reviewer_assignment_document("BATCH-1",first,active,hist),sort_keys=True))
        replacements_file=root/"out/reviewer-replacements.json"; replacements_file.write_text(json.dumps({"schema_version":1,"replacements":repl},sort_keys=True))
        scores_file=root/"out/reviewer-scores.json"; scores_file.write_text(json.dumps({"schema_version":1,"reviews":reviews},sort_keys=True))
        active_hash=sha256_json(active)
        ledger_reload.set_review_hashes(roster_sha256=sha256_file(roster),assignments_sha256=sha256_file(assignments_file),replacements_sha256=sha256_file(replacements_file),scores_sha256=sha256_file(scores_file),active_assignment_sha256=active_hash,missing_assignment_ids=[])
        ok(ledger_reload.data["review"]["active_assignment_sha256"]==active_hash,"review-hashes-bound")

        acceptance=root/"out/acceptance.json"; acceptance.write_text(json.dumps({"result":"LANE_GATE_CANDIDATE_PASS"},sort_keys=True))
        audit_final=ledger_reload.finalize(acceptance)
        ok(ledger_reload.data["state"]=="COMPLETE","final-state")
        ok(len(audit_final["evidence_chain_sha256"])==64,"evidence-chain")
        chain=ledger_reload.data["evidence_chain_sha256"]
        ledger_complete=DifferentialResumeLedger(root,out,cfg)
        ok(ledger_complete.data["evidence_chain_sha256"]==chain,"complete-rerun-stable")
        ledger_complete.set_state("COMPLETE"); ok(True,"complete-idempotent-state")
        expect("L1A20_COMPLETE_STATE_IMMUTABLE",lambda:ledger_complete.set_state("ACTIVE"),"complete-cannot-reopen")

        acceptance.write_text(json.dumps({"result":"changed"}))
        expect("L1A20_ACCEPTANCE_MUTATED",lambda:ledger_complete.finalize(acceptance),"acceptance-immutable")

    print(f"L1_A20_RESUME_SELF_TEST_PASS assertions={PASS}")

if __name__=="__main__":
    main()
