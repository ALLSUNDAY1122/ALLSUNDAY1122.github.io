import json, tempfile, unittest
from pathlib import Path

from ai_stem_generation_contract import (
    AIStemGenerationContract, CapabilityPolicy, EntitlementSnapshot, GenerationContractError,
    GenerationIntent, canonical_sha, capability_template_digest, entitlement_template_digest, EVIDENCE_STATE,
)

H=lambda c: c*64
G=lambda c: c*32


def cap_raw(**over):
    raw={
      'schema_version':1,'evidence_state':EVIDENCE_STATE,
      'reference_confidence':'OFFICIAL_CROSS_PLATFORM_ONLY',
      'allowed_tiers':['FREE','PREMIUM','PRO'],
      'allowed_roles':['drums','bass','guitar','other'],
      'supported_modes':['AUTO_MATCH','PRESET','CUSTOM_TEXT','REFERENCE_AUDIO'],
      'credit_unit_seconds':30,'credits_per_unit':1,'per_output_role_multiplier':True,
      'free_before_purchased':True,'source_evidence_sha256':H('a'),'max_source_duration_seconds':600,
    }
    raw.update(over)
    raw['snapshot_sha256']=capability_template_digest(raw)
    return raw


def ent_raw(policy, **over):
    raw={
      'account_ref_hash':H('b'),'plan_tier':'FREE','capability_snapshot_sha256':policy.snapshot_sha256,
      'included_credits_remaining':10,'purchased_credits_remaining':5,'unlimited_included':False,
      'generation_enabled':True,'source_evidence_sha256':H('c'),
    }
    raw.update(over)
    raw['snapshot_id']=entitlement_template_digest(raw)
    return raw


def intent(policy, gid=G('1'), **over):
    args=dict(logical_generation_id=gid,project_ref_hash=H('d'),source_sha256=H('e'),source_duration_seconds=35,
              target_role='drums',generation_mode='AUTO_MATCH',policy=policy)
    args.update(over)
    return GenerationIntent.build(**args)


class T(unittest.TestCase):
    def setUp(self):
        self.td=tempfile.TemporaryDirectory(); self.root=Path(self.td.name)
        self.policy=CapabilityPolicy.from_mapping(cap_raw())
        self.ent=EntitlementSnapshot.from_mapping(ent_raw(self.policy),self.policy)
        self.c=AIStemGenerationContract(policy=self.policy,ledger_path=self.root/'ledger.json')
    def tearDown(self): self.td.cleanup()

    def reserve(self, **kw): return self.c.reserve(intent=intent(self.policy,**kw),entitlement=self.ent)
    def err(self,code,fn):
        with self.assertRaises(GenerationContractError) as cm: fn()
        self.assertEqual(cm.exception.code,code)

    def test_credit_quote_rounds_up(self):
        self.assertEqual(self.policy.quote(1),1); self.assertEqual(self.policy.quote(30),1); self.assertEqual(self.policy.quote(30.01),2)
    def test_capability_digest_tamper(self):
        r=cap_raw(); r['credit_unit_seconds']=60; self.err('GEN_CAPABILITY_SNAPSHOT_MISMATCH',lambda:CapabilityPolicy.from_mapping(r))
    def test_entitlement_digest_tamper(self):
        r=ent_raw(self.policy); r['plan_tier']='PRO'; self.err('GEN_ENTITLEMENT_SNAPSHOT_MISMATCH',lambda:EntitlementSnapshot.from_mapping(r,self.policy))
    def test_disabled_entitlement(self):
        e=EntitlementSnapshot.from_mapping(ent_raw(self.policy,generation_enabled=False),self.policy)
        self.err('GEN_ENTITLEMENT_REQUIRED',lambda:self.c.reserve(intent=intent(self.policy),entitlement=e))
    def test_credit_exhausted(self):
        e=EntitlementSnapshot.from_mapping(ent_raw(self.policy,included_credits_remaining=1,purchased_credits_remaining=0),self.policy)
        self.err('GEN_CREDIT_EXHAUSTED',lambda:self.c.reserve(intent=intent(self.policy),entitlement=e))
    def test_free_before_paid_split_and_snapshot_concurrency(self):
        e=EntitlementSnapshot.from_mapping(ent_raw(self.policy,included_credits_remaining=3,purchased_credits_remaining=3),self.policy)
        a=self.c.reserve(intent=intent(self.policy,gid=G('1')),entitlement=e)
        b=self.c.reserve(intent=intent(self.policy,gid=G('2')),entitlement=e)
        self.assertEqual((a.reserved_included_credits,a.reserved_purchased_credits),(2,0))
        self.assertEqual((b.reserved_included_credits,b.reserved_purchased_credits),(1,1))
    def test_unlimited(self):
        e=EntitlementSnapshot.from_mapping(ent_raw(self.policy,included_credits_remaining=None,purchased_credits_remaining=0,unlimited_included=True,plan_tier='PRO'),self.policy)
        r=self.c.reserve(intent=intent(self.policy),entitlement=e); self.assertEqual(r.reserved_included_credits,2)
    def test_idempotent_reserve(self):
        a=self.reserve(); b=self.reserve(); self.assertEqual(a.request_fingerprint,b.request_fingerprint)
    def test_idempotency_conflict(self):
        self.reserve(); self.err('GEN_IDEMPOTENCY_CONFLICT',lambda:self.reserve(target_role='bass'))
    def test_mode_argument_validation(self):
        self.err('GEN_PRESET_ARGUMENTS_INVALID',lambda:intent(self.policy,generation_mode='PRESET'))
        x=intent(self.policy,generation_mode='CUSTOM_TEXT',prompt='make it sparse'); self.assertIsNotNone(x.prompt_sha256)
        self.assertNotIn('sparse',x.prompt_sha256)
    def test_unsupported_role_and_duration(self):
        self.err('GEN_ROLE_UNSUPPORTED',lambda:intent(self.policy,target_role='piano'))
        self.err('GEN_SOURCE_DURATION_EXCEEDED',lambda:intent(self.policy,source_duration_seconds=601))
    def test_start_duplicate_blocked(self):
        self.reserve(); self.c.authorize_start(G('1')); self.err('GEN_DUPLICATE_START_BLOCKED',lambda:self.c.authorize_start(G('1')))
    def test_ambiguous_holds_credit_and_requires_reconcile(self):
        self.reserve(); self.c.authorize_start(G('1')); r=self.c.mark_start_ambiguous(G('1'),stable_error_code='GEN_NETWORK_TIMEOUT')
        self.assertEqual(r.credit_state,'reserved'); self.err('GEN_CREDIT_RELEASE_AFTER_POSSIBLE_EXECUTION_FORBIDDEN',lambda:self.c.release_credit_if_no_execution(G('1'),release_reason='NO_CHARGE'))
        self.c.confirm_no_execution(G('1'),reconciliation_evidence_sha256=H('f')); r=self.c.release_credit_if_no_execution(G('1'),release_reason='NO_EXECUTION_CONFIRMED'); self.assertEqual(r.credit_state,'released')
    def test_bind_execution_hashes_raw_id(self):
        self.reserve(); self.c.authorize_start(G('1')); r=self.c.bind_execution(G('1'),execution_id='provider-task-123')
        self.assertNotEqual(r.execution_ref_hash,'provider-task-123'); self.assertEqual(len(r.execution_ref_hash),64)
    def test_progress_monotonic(self):
        self.reserve(); self.c.authorize_start(G('1')); self.c.bind_execution(G('1'),execution_id='x'); self.c.update_progress(G('1'),progress_percent=50)
        self.err('GEN_PROGRESS_REGRESSION',lambda:self.c.update_progress(G('1'),progress_percent=49))
    def test_credit_commit_requires_bound_execution(self):
        self.reserve(); self.err('GEN_CREDIT_COMMIT_WITHOUT_EXECUTION',lambda:self.c.commit_credit_usage(G('1'),authority_evidence_sha256=H('1')))
    def test_publish_requires_credit_integrity_and_role(self):
        self.reserve(); self.c.authorize_start(G('1')); self.c.bind_execution(G('1'),execution_id='x')
        self.err('GEN_OUTPUT_BEFORE_CREDIT_COMMIT',lambda:self.c.publish_output(G('1'),role='drums',artifact_sha256=H('2'),artifact_bytes=10,project_controlled=True,integrity_verified=True))
        self.c.commit_credit_usage(G('1'),authority_evidence_sha256=H('1'))
        self.err('GEN_OUTPUT_ROLE_MISMATCH',lambda:self.c.publish_output(G('1'),role='bass',artifact_sha256=H('2'),artifact_bytes=10,project_controlled=True,integrity_verified=True))
        self.err('GEN_OUTPUT_NOT_VERIFIED',lambda:self.c.publish_output(G('1'),role='drums',artifact_sha256=H('2'),artifact_bytes=10,project_controlled=False,integrity_verified=True))
        r=self.c.publish_output(G('1'),role='drums',artifact_sha256=H('2'),artifact_bytes=10,project_controlled=True,integrity_verified=True); self.assertEqual(r.lifecycle_state,'ready')
    def test_output_replacement_forbidden(self):
        self.reserve(); self.c.authorize_start(G('1')); self.c.bind_execution(G('1'),execution_id='x'); self.c.commit_credit_usage(G('1'),authority_evidence_sha256=H('1'))
        self.c.publish_output(G('1'),role='drums',artifact_sha256=H('2'),artifact_bytes=10,project_controlled=True,integrity_verified=True)
        self.err('GEN_OUTPUT_REPLACEMENT_FORBIDDEN',lambda:self.c.publish_output(G('1'),role='drums',artifact_sha256=H('3'),artifact_bytes=11,project_controlled=True,integrity_verified=True))
    def test_cancel_before_start_can_release(self):
        self.reserve(); r=self.c.request_cancel(G('1'),upstream_cancel_supported=True); self.assertEqual(r.upstream_cancel_state,'not_requested')
        r=self.c.release_credit_if_no_execution(G('1'),release_reason='CANCELLED_PRESTART'); self.assertEqual(r.credit_state,'released')
    def test_cancel_after_bound_no_automatic_refund(self):
        self.reserve(); self.c.authorize_start(G('1')); self.c.bind_execution(G('1'),execution_id='x'); self.c.commit_credit_usage(G('1'),authority_evidence_sha256=H('1'))
        r=self.c.request_cancel(G('1'),upstream_cancel_supported=True); self.assertEqual(r.credit_state,'committed'); self.assertEqual(r.upstream_cancel_state,'requested')
        self.err('GEN_OUTPUT_AFTER_CANCEL_FORBIDDEN',lambda:self.c.publish_output(G('1'),role='drums',artifact_sha256=H('2'),artifact_bytes=10,project_controlled=True,integrity_verified=True))
    def test_truthful_cancel_confirmation(self):
        self.reserve(); self.c.authorize_start(G('1')); self.c.bind_execution(G('1'),execution_id='x'); self.c.request_cancel(G('1'),upstream_cancel_supported=True)
        r=self.c.confirm_upstream_cancelled(G('1'),authority_evidence_sha256=H('4')); self.assertEqual(r.upstream_cancel_state,'confirmed')
    def test_refund_requires_explicit_authority(self):
        self.reserve(); self.c.authorize_start(G('1')); self.c.bind_execution(G('1'),execution_id='x'); self.c.commit_credit_usage(G('1'),authority_evidence_sha256=H('1')); self.c.request_cancel(G('1'),upstream_cancel_supported=False)
        r=self.c.request_refund(G('1')); self.assertEqual(r.credit_state,'refund_pending'); r=self.c.confirm_refund(G('1'),authority_evidence_sha256=H('5')); self.assertEqual(r.credit_state,'refunded')
    def test_regeneration_new_variant_new_credit(self):
        a=self.reserve(); b=self.c.reserve(intent=intent(self.policy,gid=G('2'),variant_index=1,parent_generation_id=G('1')),entitlement=self.ent)
        self.assertNotEqual(a.request_fingerprint,b.request_fingerprint); self.assertIsNotNone(b.parent_generation_ref_hash)
    def test_privacy_evidence(self):
        i=intent(self.policy,generation_mode='CUSTOM_TEXT',prompt='private prompt'); self.c.reserve(intent=i,entitlement=self.ent)
        ev=self.c.privacy_safe_evidence(G('1')); blob=json.dumps(ev)
        self.assertNotIn('private prompt',blob); self.assertNotIn(G('1'),blob); self.assertFalse(ev['privacy']['raw_execution_id_emitted'])

    def test_tier_not_in_capability_rejected(self):
        p=CapabilityPolicy.from_mapping(cap_raw(allowed_tiers=['PREMIUM','PRO']))
        e=EntitlementSnapshot.from_mapping(ent_raw(p),p)
        c=AIStemGenerationContract(policy=p,ledger_path=self.root/'tier.json')
        self.err('GEN_ENTITLEMENT_REQUIRED',lambda:c.reserve(intent=intent(p),entitlement=e))
    def test_purchased_credit_fallback(self):
        e=EntitlementSnapshot.from_mapping(ent_raw(self.policy,included_credits_remaining=0,purchased_credits_remaining=2),self.policy)
        r=self.c.reserve(intent=intent(self.policy),entitlement=e); self.assertEqual((r.reserved_included_credits,r.reserved_purchased_credits),(0,2))
    def test_paid_first_policy(self):
        p=CapabilityPolicy.from_mapping(cap_raw(free_before_purchased=False))
        e=EntitlementSnapshot.from_mapping(ent_raw(p,included_credits_remaining=10,purchased_credits_remaining=2),p)
        c=AIStemGenerationContract(policy=p,ledger_path=self.root/'paid-first.json')
        r=c.reserve(intent=intent(p),entitlement=e); self.assertEqual((r.reserved_included_credits,r.reserved_purchased_credits),(0,2))
    def test_reference_audio_mode(self):
        x=intent(self.policy,generation_mode='REFERENCE_AUDIO',reference_audio_sha256=H('8')); self.assertEqual(x.reference_audio_sha256,H('8'))
        self.err('GEN_REFERENCE_AUDIO_ARGUMENTS_INVALID',lambda:intent(self.policy,generation_mode='REFERENCE_AUDIO',reference_audio_sha256=H('8'),prompt='no'))
    def test_progress_after_cancel_forbidden(self):
        self.reserve(); self.c.authorize_start(G('1')); self.c.bind_execution(G('1'),execution_id='x'); self.c.request_cancel(G('1'),upstream_cancel_supported=True)
        self.err('GEN_PROGRESS_STATE_INVALID',lambda:self.c.update_progress(G('1'),progress_percent=20))
    def test_same_output_republication_idempotent(self):
        self.reserve(); self.c.authorize_start(G('1')); self.c.bind_execution(G('1'),execution_id='x'); self.c.commit_credit_usage(G('1'),authority_evidence_sha256=H('1'))
        a=self.c.publish_output(G('1'),role='drums',artifact_sha256=H('2'),artifact_bytes=10,project_controlled=True,integrity_verified=True)
        b=self.c.publish_output(G('1'),role='drums',artifact_sha256=H('2'),artifact_bytes=10,project_controlled=True,integrity_verified=True); self.assertEqual(a.output_sha256,b.output_sha256)
    def test_definitely_absent_failure_can_release(self):
        self.reserve(); self.c.authorize_start(G('1')); r=self.c.mark_failed(G('1'),stable_error_code='GEN_PRECREATE_REJECTED',execution_definitely_absent=True); self.assertEqual(r.execution_state,'confirmed_absent')
        r=self.c.release_credit_if_no_execution(G('1'),release_reason='PRECREATE_REJECTED'); self.assertEqual(r.credit_state,'released')
    def test_refund_without_cancel_rejected(self):
        self.reserve(); self.c.authorize_start(G('1')); self.c.bind_execution(G('1'),execution_id='x'); self.c.commit_credit_usage(G('1'),authority_evidence_sha256=H('1'))
        self.err('GEN_REFUND_REQUEST_STATE_INVALID',lambda:self.c.request_refund(G('1')))

    def test_corrupt_ledger_fails_closed(self):
        (self.root/'ledger.json').write_text('{oops')
        self.err('GEN_LEDGER_CORRUPT',lambda:self.c.get(G('1')))

if __name__=='__main__': unittest.main()
