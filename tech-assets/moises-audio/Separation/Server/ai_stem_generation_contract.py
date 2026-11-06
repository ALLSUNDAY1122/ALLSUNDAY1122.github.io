"""Durable AI stem generation lifecycle/credit ledger (L1-A21)."""
from __future__ import annotations
import hashlib,json,os
from contextlib import contextmanager
from dataclasses import asdict
from pathlib import Path
from ai_stem_generation_models import *
from ai_stem_generation_models import _validate,_req,_sha,_safe,_bool,_int,fail

class AtomicGenerationLedger:
 def __init__(self,path): self.path=Path(path);self.path.parent.mkdir(parents=True,exist_ok=True);self.lock=self.path.with_suffix(self.path.suffix+".lock")
 @contextmanager
 def locked(self):
  with self.lock.open("a+b") as h:
   try: import fcntl; fcntl.flock(h.fileno(),fcntl.LOCK_EX)
   except ImportError as e: fail("GEN_LEDGER_LOCK_UNAVAILABLE",retryable=True)
   try: yield self._load()
   finally: fcntl.flock(h.fileno(),fcntl.LOCK_UN)
 def _load(self):
  if not self.path.exists(): return {}
  try:r=json.loads(self.path.read_text())
  except Exception as e: raise GenerationContractError("GEN_LEDGER_CORRUPT") from e
  if r.get("schema_version")!=1 or not isinstance(r.get("records"),dict): fail("GEN_LEDGER_SCHEMA_INVALID")
  try:
   out={k:GenerationRecord(**v) for k,v in r["records"].items()}
   for k,v in out.items(): _validate(v); assert k==v.logical_generation_id
   return out
  except Exception as e: raise GenerationContractError("GEN_LEDGER_RECORD_INVALID") from e
 def save(self,rs):
  for v in rs.values(): _validate(v)
  t=self.path.with_suffix(self.path.suffix+".tmp")
  try:
   with t.open("w") as h: json.dump({"schema_version":1,"records":{k:asdict(v) for k,v in sorted(rs.items())}},h,indent=2,sort_keys=True);h.write("\n");h.flush();os.fsync(h.fileno())
   os.replace(t,self.path)
  except OSError as e: t.unlink(missing_ok=True); raise GenerationContractError("GEN_LEDGER_WRITE_FAILED",retryable=True) from e

class AIStemGenerationContract:
 def __init__(self,*,policy,ledger_path): self.policy=policy;self.ledger=AtomicGenerationLedger(ledger_path)
 def reserve(self,*,intent,entitlement):
  if not entitlement.generation_enabled or entitlement.plan_tier not in self.policy.allowed_tiers: fail("GEN_ENTITLEMENT_REQUIRED")
  if entitlement.capability_snapshot_sha256!=self.policy.snapshot_sha256: fail("GEN_ENTITLEMENT_CAPABILITY_MISMATCH")
  quote=self.policy.quote(intent.source_duration_seconds)
  with self.ledger.locked() as rs:
   old=rs.get(intent.logical_generation_id)
   if old:
    if old.request_fingerprint!=intent.request_fingerprint or old.account_ref_hash!=entitlement.account_ref_hash: fail("GEN_IDEMPOTENCY_CONFLICT")
    return old
   used_i=used_p=0
   for x in rs.values():
    if x.entitlement_snapshot_id==entitlement.snapshot_id and x.credit_state in {"reserved","committed","refund_pending"}: used_i+=x.reserved_included_credits; used_p+=x.reserved_purchased_credits
   if entitlement.unlimited_included: inc,pur=quote,0
   else:
    ai=max(0,(entitlement.included_credits_remaining or 0)-used_i); ap=max(0,entitlement.purchased_credits_remaining-used_p)
    if self.policy.free_before_purchased: inc=min(quote,ai);pur=quote-inc
    else: pur=min(quote,ap);inc=quote-pur
    if inc>ai or pur>ap: fail("GEN_CREDIT_EXHAUSTED")
   r=GenerationRecord(intent.logical_generation_id,intent.request_fingerprint,intent.project_ref_hash,entitlement.account_ref_hash,entitlement.snapshot_id,entitlement.plan_tier,self.policy.snapshot_sha256,intent.source_sha256,intent.source_duration_seconds,intent.target_role,intent.generation_mode,intent.preset_id,intent.prompt_sha256,intent.reference_audio_sha256,intent.variant_index,intent.parent_generation_ref_hash,quote,inc,pur)
   rs[r.logical_generation_id]=r;self.ledger.save(rs);return r
 def authorize_start(self,g):
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.credit_state!="reserved" or r.execution_state!="not_attempted": fail("GEN_DUPLICATE_START_BLOCKED")
   if r.logical_cancelled: fail("GEN_START_AFTER_CANCEL_FORBIDDEN")
   r.execution_state="in_flight";r.lifecycle_state="starting";self.ledger.save(rs);return r
 def mark_start_ambiguous(self,g,*,stable_error_code):
  code=_safe(stable_error_code,"stable_error_code")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.execution_state not in {"in_flight","ambiguous"}: fail("GEN_AMBIGUOUS_STATE_INVALID")
   r.execution_state="ambiguous";r.lifecycle_state="unknown";r.stable_error_code=code;self.ledger.save(rs);return r
 def bind_execution(self,g,*,execution_id):
  if not isinstance(execution_id,str) or not execution_id: fail("GEN_EXECUTION_ID_INVALID")
  h=hashlib.sha256(("l1-a21-execution-v1:"+execution_id).encode()).hexdigest()
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.execution_state not in {"in_flight","ambiguous","bound"}: fail("GEN_EXECUTION_BIND_STATE_INVALID")
   if r.execution_ref_hash not in {None,h}: fail("GEN_DUPLICATE_EXECUTION_DETECTED")
   r.execution_ref_hash=h;r.execution_state="bound";r.lifecycle_state="generating";r.stable_error_code=None;self.ledger.save(rs);return r
 def confirm_no_execution(self,g,*,reconciliation_evidence_sha256):
  _sha(reconciliation_evidence_sha256,"reconciliation_evidence_sha256")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.execution_state not in {"in_flight","ambiguous","confirmed_absent"}: fail("GEN_NO_EXECUTION_STATE_INVALID")
   r.execution_state="confirmed_absent";self.ledger.save(rs);return r
 def release_credit_if_no_execution(self,g,*,release_reason):
  _safe(release_reason,"release_reason")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.credit_state=="released": return r
   if r.credit_state!="reserved": fail("GEN_CREDIT_RELEASE_STATE_INVALID")
   if r.execution_state not in {"not_attempted","confirmed_absent"}: fail("GEN_CREDIT_RELEASE_AFTER_POSSIBLE_EXECUTION_FORBIDDEN")
   r.credit_state="released";self.ledger.save(rs);return r
 def commit_credit_usage(self,g,*,authority_evidence_sha256):
  _sha(authority_evidence_sha256,"authority_evidence_sha256")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.execution_state!="bound": fail("GEN_CREDIT_COMMIT_WITHOUT_EXECUTION")
   if r.credit_state=="committed": return r
   if r.credit_state!="reserved": fail("GEN_CREDIT_COMMIT_STATE_INVALID")
   r.credit_state="committed";self.ledger.save(rs);return r
 def update_progress(self,g,*,progress_percent):
  p=_int(progress_percent,"progress_percent")
  if p>100: fail("GEN_PROGRESS_RANGE")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.logical_cancelled or r.lifecycle_state not in {"starting","generating","unknown"}: fail("GEN_PROGRESS_STATE_INVALID")
   if p<r.progress_percent: fail("GEN_PROGRESS_REGRESSION")
   r.progress_percent=p
   if r.execution_state=="bound": r.lifecycle_state="generating"
   self.ledger.save(rs);return r
 def request_cancel(self,g,*,upstream_cancel_supported):
  supported=_bool(upstream_cancel_supported,"upstream_cancel_supported")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.lifecycle_state=="ready": fail("GEN_CANCEL_AFTER_READY_FORBIDDEN")
   r.logical_cancelled=True;r.lifecycle_state="cancelled"
   if r.execution_state in {"not_attempted","confirmed_absent"}: r.upstream_cancel_state="not_requested"
   else: r.upstream_cancel_state="requested" if supported else "unsupported"
   self.ledger.save(rs);return r
 def confirm_upstream_cancelled(self,g,*,authority_evidence_sha256):
  _sha(authority_evidence_sha256,"authority_evidence_sha256")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if not r.logical_cancelled or r.upstream_cancel_state not in {"requested","unknown_after_error","confirmed"}: fail("GEN_CANCEL_CONFIRM_STATE_INVALID")
   r.upstream_cancel_state="confirmed";self.ledger.save(rs);return r
 def request_refund(self,g):
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.credit_state!="committed" or not r.logical_cancelled: fail("GEN_REFUND_REQUEST_STATE_INVALID")
   r.credit_state="refund_pending";self.ledger.save(rs);return r
 def confirm_refund(self,g,*,authority_evidence_sha256):
  ev=_sha(authority_evidence_sha256,"authority_evidence_sha256")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.credit_state!="refund_pending": fail("GEN_REFUND_CONFIRM_STATE_INVALID")
   r.credit_state="refunded";r.refund_evidence_sha256=ev;self.ledger.save(rs);return r
 def publish_output(self,g,*,role,artifact_sha256,artifact_bytes,project_controlled,integrity_verified):
  role=_safe(role,"role").lower(); digest=_sha(artifact_sha256,"artifact_sha256"); size=_int(artifact_bytes,"artifact_bytes",1)
  if not _bool(project_controlled,"project_controlled") or not _bool(integrity_verified,"integrity_verified"): fail("GEN_OUTPUT_NOT_VERIFIED")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.logical_cancelled: fail("GEN_OUTPUT_AFTER_CANCEL_FORBIDDEN")
   if r.execution_state!="bound": fail("GEN_OUTPUT_WITHOUT_EXECUTION")
   if r.credit_state!="committed": fail("GEN_OUTPUT_BEFORE_CREDIT_COMMIT")
   if role!=r.target_role: fail("GEN_OUTPUT_ROLE_MISMATCH")
   if r.output_sha256 is not None and (r.output_sha256!=digest or r.output_bytes!=size): fail("GEN_OUTPUT_REPLACEMENT_FORBIDDEN")
   r.output_role=role;r.output_sha256=digest;r.output_bytes=size;r.progress_percent=100;r.lifecycle_state="ready";r.stable_error_code=None;self.ledger.save(rs);return r
 def mark_failed(self,g,*,stable_error_code,execution_definitely_absent=False):
  code=_safe(stable_error_code,"stable_error_code"); absent=_bool(execution_definitely_absent,"execution_definitely_absent")
  with self.ledger.locked() as rs:
   r=_req(rs,g)
   if r.lifecycle_state=="ready": fail("GEN_FAILURE_AFTER_READY_FORBIDDEN")
   if absent:
    if r.execution_state not in {"not_attempted","in_flight","ambiguous","confirmed_absent"}: fail("GEN_FAILURE_ABSENCE_CONFLICT")
    r.execution_state="confirmed_absent"
   r.lifecycle_state="cancelled" if r.logical_cancelled else "failed";r.stable_error_code=code;self.ledger.save(rs);return r
 def get(self,g):
  with self.ledger.locked() as rs:return _req(rs,g)
 def privacy_safe_evidence(self,g):
  r=self.get(g); d=asdict(r); d.pop("logical_generation_id"); d["generation_ref_hash"]=hashlib.sha256(("l1-a21-generation-ref-v1:"+r.logical_generation_id).encode()).hexdigest(); d.update(schema_version=1,tool_version=TOOL_VERSION,evidence_state=EVIDENCE_STATE,parity_claim="NONE",privacy={"raw_prompt_emitted":False,"raw_account_id_emitted":False,"raw_project_id_emitted":False,"raw_execution_id_emitted":False,"signed_output_url_emitted":False,"raw_audio_emitted":False}); return d
