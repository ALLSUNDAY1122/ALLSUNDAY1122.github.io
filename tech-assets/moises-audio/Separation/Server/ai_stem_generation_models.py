"""L1-A21 AI stem generation processing/credit contract (NON-PARITY)."""
from __future__ import annotations
import hashlib,json,math,os,re
from contextlib import contextmanager
from dataclasses import asdict,dataclass
from pathlib import Path
from typing import Any,Mapping

SCHEMA_VERSION=1; TOOL_VERSION="L1-A21-v1"; EVIDENCE_STATE="NON_PARITY_EVIDENCE_ONLY"
HEX64=re.compile(r"^[0-9a-f]{64}$"); ID32=re.compile(r"^[0-9a-f]{32}$"); SAFE=re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")
TIERS={"FREE","PREMIUM","PRO"}; MODES={"AUTO_MATCH","PRESET","CUSTOM_TEXT","REFERENCE_AUDIO"}
LIFECYCLE={"reserved","starting","generating","ready","cancelled","failed","unknown"}; EXECUTION={"not_attempted","in_flight","ambiguous","bound","confirmed_absent"}; CREDIT={"reserved","committed","released","refund_pending","refunded"}; CANCEL={"not_requested","requested","confirmed","unsupported","unknown_after_error"}
CONFIDENCE={"OFFICIAL_CROSS_PLATFORM_ONLY","CURRENT_IPHONE_CAPTURED"}
class GenerationContractError(RuntimeError):
 def __init__(self,code,message="AI stem generation contract violation",retryable=False): self.code=code;self.message=message;self.retryable=retryable;super().__init__(f"{code}: {message}")
def fail(code,msg="AI stem generation contract violation",retryable=False): raise GenerationContractError(code,msg,retryable)
def _sha(v,f):
 if not isinstance(v,str) or not HEX64.fullmatch((x:=v.strip().lower().removeprefix("sha256:"))): fail("GEN_SHA_INVALID",f)
 return x
def _safe(v,f):
 if not isinstance(v,str) or not SAFE.fullmatch((x:=v.strip())): fail("GEN_SAFE_ID_INVALID",f)
 return x
def _bool(v,f):
 if not isinstance(v,bool): fail("GEN_BOOL_INVALID",f)
 return v
def _num(v,f,lo=None):
 if isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(float(v)): fail("GEN_NUMBER_INVALID",f)
 x=float(v)
 if lo is not None and x<lo: fail("GEN_NUMBER_RANGE",f)
 return x
def _int(v,f,lo=0):
 if isinstance(v,bool) or not isinstance(v,int) or v<lo: fail("GEN_INTEGER_INVALID",f)
 return v
def canonical_sha(v): return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(",",":"),ensure_ascii=False,allow_nan=False).encode()).hexdigest()
def _ph(prompt):
 if prompt is None:return None
 if not isinstance(prompt,str) or not prompt.strip(): fail("GEN_PROMPT_INVALID")
 if len(prompt)>4000: fail("GEN_PROMPT_TOO_LONG")
 return hashlib.sha256(("l1-a21-prompt-v1:"+prompt.strip()).encode()).hexdigest()

@dataclass(frozen=True)
class CapabilityPolicy:
 snapshot_sha256:str; reference_confidence:str; allowed_tiers:tuple[str,...]; allowed_roles:tuple[str,...]; supported_modes:tuple[str,...]; credit_unit_seconds:int; credits_per_unit:int; per_output_role_multiplier:bool; free_before_purchased:bool; source_evidence_sha256:str; max_source_duration_seconds:int|None
 @classmethod
 def from_mapping(cls,r):
  if r.get("schema_version")!=1 or r.get("evidence_state")!=EVIDENCE_STATE: fail("GEN_CAPABILITY_SCHEMA")
  conf=_safe(r.get("reference_confidence"),"reference_confidence").upper(); tiers=tuple(sorted({_safe(x,"tier").upper() for x in r.get("allowed_tiers",[])})); roles=tuple(sorted({_safe(x,"role").lower() for x in r.get("allowed_roles",[])})); modes=tuple(sorted({_safe(x,"mode").upper() for x in r.get("supported_modes",[])}))
  if conf not in CONFIDENCE: fail("GEN_REFERENCE_CONFIDENCE_INVALID")
  if not tiers or not roles or not modes: fail("GEN_CAPABILITY_EMPTY")
  if set(tiers)-TIERS: fail("GEN_TIER_INVALID")
  if set(modes)-MODES: fail("GEN_MODE_INVALID")
  unit=_int(r.get("credit_unit_seconds"),"credit_unit_seconds",1); cpu=_int(r.get("credits_per_unit"),"credits_per_unit",1); per=_bool(r.get("per_output_role_multiplier"),"per_output_role_multiplier"); ff=_bool(r.get("free_before_purchased"),"free_before_purchased"); src=_sha(r.get("source_evidence_sha256"),"source_evidence_sha256"); mx=None if r.get("max_source_duration_seconds") is None else _int(r.get("max_source_duration_seconds"),"max_source_duration_seconds",1)
  sem={"schema_version":1,"evidence_state":EVIDENCE_STATE,"reference_confidence":conf,"allowed_tiers":list(tiers),"allowed_roles":list(roles),"supported_modes":list(modes),"credit_unit_seconds":unit,"credits_per_unit":cpu,"per_output_role_multiplier":per,"free_before_purchased":ff,"source_evidence_sha256":src,"max_source_duration_seconds":mx}; snap=_sha(r.get("snapshot_sha256"),"snapshot_sha256")
  if canonical_sha(sem)!=snap: fail("GEN_CAPABILITY_SNAPSHOT_MISMATCH")
  return cls(snap,conf,tiers,roles,modes,unit,cpu,per,ff,src,mx)
 def quote(self,duration_seconds,output_role_count=1): return math.ceil(_num(duration_seconds,"duration_seconds",0.000001)/self.credit_unit_seconds)*self.credits_per_unit*(_int(output_role_count,"output_role_count",1) if self.per_output_role_multiplier else 1)

@dataclass(frozen=True)
class EntitlementSnapshot:
 snapshot_id:str; account_ref_hash:str; plan_tier:str; capability_snapshot_sha256:str; included_credits_remaining:int|None; purchased_credits_remaining:int; unlimited_included:bool; generation_enabled:bool; source_evidence_sha256:str
 @classmethod
 def from_mapping(cls,r,p):
  acct=_sha(r.get("account_ref_hash"),"account_ref_hash"); tier=_safe(r.get("plan_tier"),"plan_tier").upper(); cap=_sha(r.get("capability_snapshot_sha256"),"capability_snapshot_sha256"); un=_bool(r.get("unlimited_included"),"unlimited_included")
  if tier not in TIERS: fail("GEN_TIER_INVALID")
  if cap!=p.snapshot_sha256: fail("GEN_ENTITLEMENT_CAPABILITY_MISMATCH")
  inc=None if un else _int(r.get("included_credits_remaining"),"included_credits_remaining")
  if un and r.get("included_credits_remaining") is not None: fail("GEN_ENTITLEMENT_UNLIMITED_BALANCE_CONFLICT")
  pur=_int(r.get("purchased_credits_remaining"),"purchased_credits_remaining"); ena=_bool(r.get("generation_enabled"),"generation_enabled"); src=_sha(r.get("source_evidence_sha256"),"source_evidence_sha256")
  sem={"account_ref_hash":acct,"plan_tier":tier,"capability_snapshot_sha256":cap,"included_credits_remaining":inc,"purchased_credits_remaining":pur,"unlimited_included":un,"generation_enabled":ena,"source_evidence_sha256":src}; sid=_sha(r.get("snapshot_id"),"snapshot_id")
  if canonical_sha({"domain":"l1-a21-entitlement-v1",**sem})!=sid: fail("GEN_ENTITLEMENT_SNAPSHOT_MISMATCH")
  return cls(sid,acct,tier,cap,inc,pur,un,ena,src)

@dataclass(frozen=True)
class GenerationIntent:
 logical_generation_id:str; project_ref_hash:str; source_sha256:str; source_duration_seconds:float; target_role:str; generation_mode:str; preset_id:str|None; prompt_sha256:str|None; reference_audio_sha256:str|None; variant_index:int; parent_generation_ref_hash:str|None; request_fingerprint:str
 @classmethod
 def build(cls,*,logical_generation_id,project_ref_hash,source_sha256,source_duration_seconds,target_role,generation_mode,policy,preset_id=None,prompt=None,reference_audio_sha256=None,variant_index=0,parent_generation_id=None):
  gid=logical_generation_id.strip().lower() if isinstance(logical_generation_id,str) else ""
  if not ID32.fullmatch(gid): fail("GEN_LOGICAL_ID_INVALID")
  project=_sha(project_ref_hash,"project_ref_hash"); source=_sha(source_sha256,"source_sha256"); dur=_num(source_duration_seconds,"source_duration_seconds",0.000001); role=_safe(target_role,"target_role").lower(); mode=_safe(generation_mode,"generation_mode").upper(); variant=_int(variant_index,"variant_index")
  if role not in policy.allowed_roles: fail("GEN_ROLE_UNSUPPORTED")
  if mode not in policy.supported_modes: fail("GEN_MODE_UNSUPPORTED")
  if policy.max_source_duration_seconds is not None and dur>policy.max_source_duration_seconds: fail("GEN_SOURCE_DURATION_EXCEEDED")
  pr=None if preset_id is None else _safe(preset_id,"preset_id"); ph=_ph(prompt); ref=None if reference_audio_sha256 is None else _sha(reference_audio_sha256,"reference_audio_sha256")
  if mode=="AUTO_MATCH" and any(x is not None for x in (pr,ph,ref)): fail("GEN_AUTO_MATCH_ARGUMENTS_INVALID")
  if mode=="PRESET" and (pr is None or ph is not None or ref is not None): fail("GEN_PRESET_ARGUMENTS_INVALID")
  if mode=="CUSTOM_TEXT" and (ph is None or pr is not None or ref is not None): fail("GEN_CUSTOM_TEXT_ARGUMENTS_INVALID")
  if mode=="REFERENCE_AUDIO" and (ref is None or pr is not None or ph is not None): fail("GEN_REFERENCE_AUDIO_ARGUMENTS_INVALID")
  parent=None
  if parent_generation_id is not None:
   pg=parent_generation_id.strip().lower()
   if not ID32.fullmatch(pg): fail("GEN_PARENT_ID_INVALID")
   parent=hashlib.sha256(("l1-a21-parent-v1:"+pg).encode()).hexdigest()
  sem={"project_ref_hash":project,"source_sha256":source,"source_duration_seconds":dur,"target_role":role,"generation_mode":mode,"preset_id":pr,"prompt_sha256":ph,"reference_audio_sha256":ref,"variant_index":variant,"parent_generation_ref_hash":parent,"capability_snapshot_sha256":policy.snapshot_sha256}
  return cls(gid,project,source,dur,role,mode,pr,ph,ref,variant,parent,canonical_sha({"domain":"l1-a21-request-v1",**sem}))

@dataclass
class GenerationRecord:
 logical_generation_id:str; request_fingerprint:str; project_ref_hash:str; account_ref_hash:str; entitlement_snapshot_id:str; plan_tier:str; capability_snapshot_sha256:str; source_sha256:str; source_duration_seconds:float; target_role:str; generation_mode:str; preset_id:str|None; prompt_sha256:str|None; reference_audio_sha256:str|None; variant_index:int; parent_generation_ref_hash:str|None; quoted_credits:int; reserved_included_credits:int; reserved_purchased_credits:int; credit_state:str="reserved"; lifecycle_state:str="reserved"; execution_state:str="not_attempted"; execution_ref_hash:str|None=None; progress_percent:int=0; logical_cancelled:bool=False; upstream_cancel_state:str="not_requested"; output_role:str|None=None; output_sha256:str|None=None; output_bytes:int|None=None; stable_error_code:str|None=None; refund_evidence_sha256:str|None=None

def capability_template_digest(r):
 x=dict(r);x.pop("snapshot_sha256",None);x["schema_version"]=1;x["evidence_state"]=EVIDENCE_STATE;x["reference_confidence"]=_safe(x.get("reference_confidence"),"reference_confidence").upper();x["allowed_tiers"]=sorted({_safe(v,"tier").upper() for v in x.get("allowed_tiers",[])});x["allowed_roles"]=sorted({_safe(v,"role").lower() for v in x.get("allowed_roles",[])});x["supported_modes"]=sorted({_safe(v,"mode").upper() for v in x.get("supported_modes",[])});x["source_evidence_sha256"]=_sha(x.get("source_evidence_sha256"),"source_evidence_sha256");return canonical_sha(x)
def entitlement_template_digest(r):
 x=dict(r);x.pop("snapshot_id",None);x["account_ref_hash"]=_sha(x.get("account_ref_hash"),"account_ref_hash");x["plan_tier"]=_safe(x.get("plan_tier"),"plan_tier").upper();x["capability_snapshot_sha256"]=_sha(x.get("capability_snapshot_sha256"),"capability_snapshot_sha256");x["source_evidence_sha256"]=_sha(x.get("source_evidence_sha256"),"source_evidence_sha256");return canonical_sha({"domain":"l1-a21-entitlement-v1",**x})
def _req(rs,g):
 gid=g.strip().lower() if isinstance(g,str) else ""
 if not ID32.fullmatch(gid): fail("GEN_LOGICAL_ID_INVALID")
 if gid not in rs: fail("GEN_RECORD_NOT_FOUND")
 return rs[gid]
def _validate(r):
 if not ID32.fullmatch(r.logical_generation_id): raise ValueError("id")
 for x in (r.request_fingerprint,r.project_ref_hash,r.account_ref_hash,r.entitlement_snapshot_id,r.capability_snapshot_sha256,r.source_sha256):
  if not HEX64.fullmatch(x): raise ValueError("sha")
 if r.plan_tier not in TIERS or r.generation_mode not in MODES or r.credit_state not in CREDIT or r.lifecycle_state not in LIFECYCLE or r.execution_state not in EXECUTION or r.upstream_cancel_state not in CANCEL: raise ValueError("state")
 if r.quoted_credits<=0 or r.reserved_included_credits<0 or r.reserved_purchased_credits<0 or r.reserved_included_credits+r.reserved_purchased_credits!=r.quoted_credits: raise ValueError("credit")
 if not 0<=r.progress_percent<=100: raise ValueError("progress")
 if r.output_sha256 is not None and not HEX64.fullmatch(r.output_sha256): raise ValueError("output")
 if r.output_bytes is not None and r.output_bytes<=0: raise ValueError("bytes")
