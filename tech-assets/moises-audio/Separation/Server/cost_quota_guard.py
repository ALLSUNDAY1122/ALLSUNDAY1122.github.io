"""Lane 1 durable spend guard. NON-PARITY infrastructure; live pricing is injected."""
from __future__ import annotations

import hashlib, json, math, os, re
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_UP
from pathlib import Path
from zoneinfo import ZoneInfo

_Q=Decimal('0.000001'); _JOB=re.compile(r'^[0-9a-f]{32}$'); _FP=re.compile(r'^[0-9a-f]{64}$')

class CostGuardError(RuntimeError):
    def __init__(self, code:str, *, retryable:bool=False): self.code=code; self.retryable=retryable; super().__init__(code)

def _money(v, code='SEP_COST_AMOUNT_INVALID'):
    try: d=Decimal(str(v)).quantize(_Q, rounding=ROUND_UP)
    except (InvalidOperation,ValueError) as e: raise CostGuardError(code) from e
    if not d.is_finite(): raise CostGuardError(code)
    return d

def _ms(v): return format(_money(v),'f')
def _safe(v): return isinstance(v,str) and re.fullmatch(r'[A-Za-z0-9_.:-]{1,160}',v) is not None

@dataclass(frozen=True)
class PricingPolicy:
    currency:str; per_target_minute_cost:str; per_job_ceiling:str; daily_budget:str; monthly_budget:str
    billing_increment_seconds:int=60; minimum_billable_seconds:int=60; budget_timezone:str='UTC'
    def validate(self):
        if not re.fullmatch(r'[A-Z]{3}',self.currency): raise CostGuardError('SEP_COST_CURRENCY_INVALID')
        vals=[_money(self.per_target_minute_cost),_money(self.per_job_ceiling),_money(self.daily_budget),_money(self.monthly_budget)]
        if vals[0]<0 or any(x<=0 for x in vals[1:]): raise CostGuardError('SEP_COST_POLICY_NONPOSITIVE')
        if vals[2]>vals[3]: raise CostGuardError('SEP_COST_DAILY_EXCEEDS_MONTHLY')
        if self.billing_increment_seconds<=0 or self.minimum_billable_seconds<0: raise CostGuardError('SEP_COST_BILLING_WINDOW_INVALID')
        try: ZoneInfo(self.budget_timezone)
        except Exception as e: raise CostGuardError('SEP_COST_TIMEZONE_INVALID') from e
    def estimate(self,duration_seconds:float,target_count:int)->Decimal:
        self.validate()
        if not isinstance(duration_seconds,(int,float)) or not math.isfinite(float(duration_seconds)) or duration_seconds<=0: raise CostGuardError('SEP_COST_DURATION_INVALID')
        if not isinstance(target_count,int) or target_count<=0: raise CostGuardError('SEP_COST_TARGET_COUNT_INVALID')
        secs=max(self.minimum_billable_seconds,math.ceil(duration_seconds/self.billing_increment_seconds)*self.billing_increment_seconds)
        return _money(Decimal(secs)/Decimal(60)*Decimal(target_count)*_money(self.per_target_minute_cost))

@dataclass
class CostRecord:
    logical_job_id:str; request_fingerprint:str; currency:str; duration_seconds:float; target_count:int
    estimated_cost:str; reserved_cost:str; actual_cost:str|None; accounting_state:str; provider_create_state:str
    budget_day:str; budget_month:str; provider_task_id_hash:str|None=None; stable_limit_code:str|None=None; reconciliation_note:str|None=None

@dataclass(frozen=True)
class LimitSemantics:
    kind:str; stable_error_code:str; retryable_non_create_operation:bool; automatic_provider_create_retry_allowed:bool=False

class AtomicLedger:
    def __init__(self,path): self.path=Path(path); self.path.parent.mkdir(parents=True,exist_ok=True); self.lock_path=self.path.with_suffix(self.path.suffix+'.lock')
    @contextmanager
    def locked(self):
        with self.lock_path.open('a+b') as h:
            try:
                import fcntl; fcntl.flock(h.fileno(),fcntl.LOCK_EX)
            except ImportError as e: raise CostGuardError('SEP_COST_LEDGER_LOCK_UNAVAILABLE',retryable=True) from e
            try: yield self._load()
            finally: fcntl.flock(h.fileno(),fcntl.LOCK_UN)
    def _load(self):
        if not self.path.exists(): return {}
        try: raw=json.loads(self.path.read_text())
        except Exception as e: raise CostGuardError('SEP_COST_LEDGER_CORRUPT') from e
        if raw.get('schema_version')!=1 or not isinstance(raw.get('records'),dict): raise CostGuardError('SEP_COST_LEDGER_SCHEMA_INVALID')
        out={}
        try:
            for k,v in raw['records'].items(): out[k]=CostRecord(**v); _validate_record(out[k]); assert k==out[k].logical_job_id
        except Exception as e: raise CostGuardError('SEP_COST_LEDGER_RECORD_INVALID') from e
        return out
    def save(self,records):
        for r in records.values(): _validate_record(r)
        tmp=self.path.with_suffix(self.path.suffix+'.tmp'); payload={'schema_version':1,'records':{k:asdict(v) for k,v in sorted(records.items())}}
        try:
            with tmp.open('w') as h: h.write(json.dumps(payload,indent=2,sort_keys=True)+'\n'); h.flush(); os.fsync(h.fileno())
            os.replace(tmp,self.path)
        except OSError as e: tmp.unlink(missing_ok=True); raise CostGuardError('SEP_COST_LEDGER_WRITE_FAILED',retryable=True) from e

class CostQuotaGuard:
    def __init__(self,*,policy:PricingPolicy,ledger_path): policy.validate(); self.policy=policy; self.ledger=AtomicLedger(ledger_path)
    def reserve(self,*,logical_job_id,request_fingerprint,duration_seconds,target_count,now=None):
        _identity(logical_job_id,request_fingerprint); est=self.policy.estimate(duration_seconds,target_count)
        if est>_money(self.policy.per_job_ceiling): raise CostGuardError('SEP_COST_PER_JOB_CEILING_EXCEEDED')
        day,month=_keys(now,self.policy.budget_timezone)
        with self.ledger.locked() as rs:
            old=rs.get(logical_job_id)
            if old:
                if old.request_fingerprint!=request_fingerprint or old.currency!=self.policy.currency or old.target_count!=target_count or abs(old.duration_seconds-float(duration_seconds))>1e-6 or _money(old.estimated_cost)!=est: raise CostGuardError('SEP_COST_IDEMPOTENCY_CONFLICT')
                if old.accounting_state!='released': return old
                if old.provider_create_state!='not_attempted': raise CostGuardError('SEP_COST_RELEASED_CREATE_STATE_INVALID')
                self._budget_check(rs,day,month,est); old.accounting_state='reserved'; old.reserved_cost=_ms(est); old.actual_cost=None; old.budget_day=day; old.budget_month=month; old.reconciliation_note='reactivated_after_precreate_release'; self.ledger.save(rs); return old
            self._budget_check(rs,day,month,est)
            r=CostRecord(logical_job_id,request_fingerprint,self.policy.currency,float(duration_seconds),target_count,_ms(est),_ms(est),None,'reserved','not_attempted',day,month)
            rs[logical_job_id]=r; self.ledger.save(rs); return r
    def _budget_check(self,rs,day,month,est):
        d=m=Decimal('0')
        for r in rs.values():
            amt=Decimal('0') if r.accounting_state=='released' else _money(r.actual_cost if r.accounting_state=='actual_reconciled' and r.actual_cost is not None else r.reserved_cost)
            if r.budget_day==day: d+=amt
            if r.budget_month==month: m+=amt
        if d+est>_money(self.policy.daily_budget): raise CostGuardError('SEP_COST_DAILY_BUDGET_EXCEEDED')
        if m+est>_money(self.policy.monthly_budget): raise CostGuardError('SEP_COST_MONTHLY_BUDGET_EXCEEDED')
    def authorize_provider_create(self,job):
        with self.ledger.locked() as rs:
            r=_require(rs,job)
            if r.accounting_state!='reserved': raise CostGuardError('SEP_COST_PROVIDER_CREATE_NOT_RESERVED')
            if r.provider_create_state!='not_attempted': raise CostGuardError('SEP_COST_DUPLICATE_PROVIDER_CREATE_BLOCKED')
            r.provider_create_state='in_flight'; self.ledger.save(rs); return r
    def mark_create_ambiguous(self,job,error):
        sem=classify_provider_limit(error)
        with self.ledger.locked() as rs:
            r=_require(rs,job)
            if r.provider_create_state not in {'in_flight','ambiguous'}: raise CostGuardError('SEP_COST_AMBIGUOUS_STATE_INVALID')
            r.provider_create_state='ambiguous'; r.stable_limit_code=sem.stable_error_code if sem else _error_code(error); self.ledger.save(rs); return r
    def confirm_provider_task(self,job,provider_task_id):
        if not isinstance(provider_task_id,str) or not provider_task_id: raise CostGuardError('SEP_COST_PROVIDER_TASK_ID_INVALID')
        h=hashlib.sha256(provider_task_id.encode()).hexdigest()
        with self.ledger.locked() as rs:
            r=_require(rs,job)
            if r.provider_create_state not in {'in_flight','ambiguous','confirmed'}: raise CostGuardError('SEP_COST_PROVIDER_CONFIRM_STATE_INVALID')
            if r.provider_task_id_hash not in {None,h}: r.provider_create_state='billing_incident'; self.ledger.save(rs); raise CostGuardError('SEP_COST_PROVIDER_TASK_CONFLICT')
            r.provider_task_id_hash=h; r.provider_create_state='confirmed'; r.stable_limit_code=None; self.ledger.save(rs); return r
    def mark_duplicate_billing_incident(self,job):
        with self.ledger.locked() as rs: r=_require(rs,job); r.provider_create_state='billing_incident'; r.stable_limit_code='SEP_COST_DUPLICATE_PROVIDER_TASKS'; self.ledger.save(rs); return r
    def release_before_provider_create(self,job,*,reason_code):
        if not _safe(reason_code): raise CostGuardError('SEP_COST_RELEASE_REASON_INVALID')
        with self.ledger.locked() as rs:
            r=_require(rs,job)
            if r.provider_create_state!='not_attempted': raise CostGuardError('SEP_COST_RELEASE_AFTER_CREATE_FORBIDDEN')
            r.accounting_state='released'; r.reserved_cost=_ms(0); r.reconciliation_note=reason_code; self.ledger.save(rs); return r
    def reconcile_actual(self,job,*,actual_cost,reconciliation_note='provider_actual'):
        a=_money(actual_cost)
        if a<0 or not _safe(reconciliation_note): raise CostGuardError('SEP_COST_ACTUAL_INVALID')
        with self.ledger.locked() as rs:
            r=_require(rs,job)
            if r.accounting_state=='released': raise CostGuardError('SEP_COST_ACTUAL_AFTER_RELEASE_INVALID')
            r.actual_cost=_ms(a); r.reserved_cost=_ms(0); r.accounting_state='actual_reconciled'; r.reconciliation_note=reconciliation_note
            r.stable_limit_code=None
            if a>_money(self.policy.per_job_ceiling): r.stable_limit_code='SEP_COST_ACTUAL_JOB_CEILING_OVERRUN'
            day_total=month_total=Decimal('0')
            for item in rs.values():
                amount=Decimal('0') if item.accounting_state=='released' else _money(item.actual_cost if item.accounting_state=='actual_reconciled' and item.actual_cost is not None else item.reserved_cost)
                if item.budget_day==r.budget_day: day_total+=amount
                if item.budget_month==r.budget_month: month_total+=amount
            if month_total>_money(self.policy.monthly_budget): r.stable_limit_code='SEP_COST_ACTUAL_MONTHLY_BUDGET_OVERRUN'
            elif day_total>_money(self.policy.daily_budget): r.stable_limit_code='SEP_COST_ACTUAL_DAILY_BUDGET_OVERRUN'
            self.ledger.save(rs); return r
    def record_limit_signal(self,job,error):
        sem=classify_provider_limit(error)
        if not sem: raise CostGuardError('SEP_PROVIDER_LIMIT_SIGNAL_UNKNOWN')
        with self.ledger.locked() as rs: r=_require(rs,job); r.stable_limit_code=sem.stable_error_code; self.ledger.save(rs); return r
    def get(self,job):
        with self.ledger.locked() as rs: return _require(rs,job)
    def privacy_safe_evidence(self,job):
        r=self.get(job); return {'schema_version':1,'job_ref_hash':hashlib.sha256(r.logical_job_id.encode()).hexdigest(),'request_fingerprint':r.request_fingerprint,'currency':r.currency,'duration_seconds':r.duration_seconds,'target_count':r.target_count,'estimated_cost':r.estimated_cost,'actual_cost':r.actual_cost,'accounting_state':r.accounting_state,'provider_create_state':r.provider_create_state,'provider_task_id_hash':r.provider_task_id_hash,'stable_limit_code':r.stable_limit_code,'budget_day':r.budget_day,'budget_month':r.budget_month,'parity_state':'NON_PARITY_EVIDENCE_ONLY'}

def classify_provider_limit(error):
    code=_error_code(error); u=code.upper(); status=getattr(error,'status',None) if not isinstance(error,str) else None
    if status==429 or 'HTTP_429' in u or 'RATE_LIMIT' in u: return LimitSemantics('rate_limited','SEP_PROVIDER_RATE_LIMITED',True)
    if 'CREDIT_EXHAUST' in u or 'INSUFFICIENT_CREDIT' in u or 'OUT_OF_CREDIT' in u: return LimitSemantics('credit_exhausted','SEP_PROVIDER_CREDIT_EXHAUSTED',False)
    if 'QUOTA_EXHAUST' in u or 'QUOTA_EXCEEDED' in u or 'LIMIT_EXHAUST' in u: return LimitSemantics('quota_exhausted','SEP_PROVIDER_QUOTA_EXHAUSTED',False)
    if status==402 or 'HTTP_402' in u or 'PAYMENT_REQUIRED' in u: return LimitSemantics('billing_rejected','SEP_PROVIDER_BILLING_REJECTED',False)
    return None

def _error_code(e):
    v=e if isinstance(e,str) else getattr(e,'code',None); return v if _safe(v) else 'SEP_PROVIDER_LIMIT_UNKNOWN'
def _identity(j,f):
    if not isinstance(j,str) or not _JOB.fullmatch(j): raise CostGuardError('SEP_COST_LOGICAL_JOB_ID_INVALID')
    if not isinstance(f,str) or not _FP.fullmatch(f): raise CostGuardError('SEP_COST_REQUEST_FINGERPRINT_INVALID')
def _require(rs,j): _identity(j,'0'*64); return rs[j] if j in rs else (_ for _ in ()).throw(CostGuardError('SEP_COST_RECORD_NOT_FOUND'))
def _keys(now,tz):
    d=now or datetime.now(timezone.utc)
    if d.tzinfo is None: raise CostGuardError('SEP_COST_NOW_NAIVE')
    x=d.astimezone(ZoneInfo(tz)); return x.strftime('%Y-%m-%d'),x.strftime('%Y-%m')
def _validate_record(r):
    _identity(r.logical_job_id,r.request_fingerprint)
    if r.accounting_state not in {'reserved','actual_reconciled','released'} or r.provider_create_state not in {'not_attempted','in_flight','confirmed','ambiguous','billing_incident'}: raise ValueError('state')
    _money(r.estimated_cost); _money(r.reserved_cost); _money(r.actual_cost) if r.actual_cost is not None else None
