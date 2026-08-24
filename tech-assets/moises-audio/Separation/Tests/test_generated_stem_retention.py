import json, tempfile, unittest
from pathlib import Path
from generated_stem_retention import *

H=lambda c:c*64
L=lambda c:c*32

def atomicish(path,payload):
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(payload,sort_keys=True,separators=(',',':'))+'\n')

def make_variant(root,*,project=H('1'),role='guitar',gen=H('2'),variant=0,data=b'audio',active=True):
    (root/'objects').mkdir(parents=True,exist_ok=True);(root/'manifests').mkdir(parents=True,exist_ok=True);(root/'active').mkdir(parents=True,exist_ok=True)
    sha=hashlib.sha256(data).hexdigest(); obj=root/'objects'/f'{sha}.wav';obj.write_bytes(data)
    m={'schema_version':1,'project_ref_hash':project,'role':role,'generation_ref_hash':gen,'variant_index':variant,'artifact_sha256':sha,'artifact_bytes':len(data),'sample_rate':48000,'channels':2,'audio_format':1,'bits_per_sample':16,'frame_count':100,'mix_ready_receipt_sha256':H('3')}
    mp=root/'manifests'/f'{gen}.v{variant}.json';atomicish(mp,m)
    if active:atomicish(root/'active'/f'{project}.{role}.json',m)
    return m,mp,obj

def make_a21(path,logical,**over):
    rec={'credit_state':'committed','logical_cancelled':False,'refund_evidence_sha256':None}
    rec.update(over);atomicish(path,{'schema_version':1,'records':{logical:rec}})

def make_binding(path,logical,execution='exec-1'):
    atomicish(path,{'schema_version':1,'records':{logical:{'logical_generation_id':logical,'request_fingerprint':H('4'),'runtime_descriptor_sha256':H('5'),'execution_id':execution,'execution_ref_hash':execution_ref_hash(execution)}}})

class T(unittest.TestCase):
    def setUp(self):
        self.t=tempfile.TemporaryDirectory();self.root=Path(self.t.name)/'store';self.nowv=1000
        self.s=GeneratedStemRetentionService(store_root=self.root,now_epoch=lambda:self.nowv,orphan_grace_seconds=10,superseded_grace_seconds=10)
    def tearDown(self):self.t.cleanup()
    def code(self,c,fn):
        with self.assertRaises(GeneratedRetentionError) as cm:fn()
        self.assertEqual(cm.exception.code,c)
    def reg(self,**kw):
        m,mp,obj=make_variant(self.root,**kw);r=self.s.register_variant(generation_ref_hash_value=m['generation_ref_hash'],variant_index=m['variant_index']);return m,mp,obj,r

    def test_register_active(self):
        m,_,_,r=self.reg();self.assertEqual(r.last_active_at_epoch,1000);self.assertFalse(r.delete_requested)
    def test_register_new_active_marks_old_superseded(self):
        m1,_,_,r1=self.reg(gen=H('2'),variant=0,data=b'a')
        # move active to new variant same project/role
        m2,mp2,obj2=make_variant(self.root,gen=H('6'),variant=1,data=b'b',active=True)
        self.nowv=1010;self.s.register_variant(generation_ref_hash_value=H('6'),variant_index=1)
        st=self.s.registry.load();self.assertEqual(st['records'][r1.record_key].superseded_at_epoch,1010)
    def test_registration_idempotent(self):
        m,_,_,r=self.reg();r2=self.s.register_variant(generation_ref_hash_value=m['generation_ref_hash'],variant_index=0);self.assertEqual(r.record_key,r2.record_key)
    def test_delete_intent_survives_object_mutation_failure(self):
        m,_,obj,r=self.reg();obj.write_bytes(b'evil')
        self.code('GEN_RET_OBJECT_MUTATED',lambda:self.s.request_delete(generation_ref_hash_value=m['generation_ref_hash'],variant_index=0,reason='USER_DELETE'))
        self.assertTrue(self.s.registry.load()['records'][r.record_key].delete_requested)
    def test_superseded_cleanup_cannot_delete_active(self):
        m,_,_,_=self.reg();self.code('GEN_RET_ACTIVE_DELETE_FORBIDDEN',lambda:self.s.request_delete(generation_ref_hash_value=m['generation_ref_hash'],variant_index=0,reason='SUPERSEDED_RETENTION'))
    def test_user_delete_active_removes_association_and_object(self):
        m,mp,obj,_=self.reg();snap=self.s.request_delete(generation_ref_hash_value=m['generation_ref_hash'],variant_index=0,reason='USER_DELETE')
        self.assertTrue(snap['association_delete_confirmed']);self.assertEqual(snap['physical_artifact_state'],'confirmed_erased');self.assertFalse(mp.exists());self.assertFalse(obj.exists())
    def test_shared_object_not_erased(self):
        m,mp,obj,_=self.reg(gen=H('2'),variant=0,data=b'same')
        m2,mp2,obj2=make_variant(self.root,project=H('7'),role='bass',gen=H('8'),variant=0,data=b'same',active=True)
        self.s.register_variant(generation_ref_hash_value=H('8'),variant_index=0)
        snap=self.s.request_delete(generation_ref_hash_value=H('2'),variant_index=0,reason='USER_DELETE')
        self.assertEqual(snap['physical_artifact_state'],'retained_shared_reference');self.assertTrue(obj.exists())
    def test_missing_object_truthful_state(self):
        m,_,obj,_=self.reg();obj.unlink();snap=self.s.request_delete(generation_ref_hash_value=H('2'),variant_index=0,reason='USER_DELETE');self.assertEqual(snap['physical_artifact_state'],'missing_before_delete')
    def test_runtime_accepted_not_erasure_complete(self):
        m,_,_,_=self.reg();logical=L('a');# use matching generation hash in separate variant impossible; create binding by generation matching requires manifest gen
        # recreate service target with generation ref from logical
        gh=generation_ref_hash(logical);m,_,_,_=self.reg(gen=gh,variant=1,data=b'x')
        bp=Path(self.t.name)/'bind.json';make_binding(bp,logical)
        snap=self.s.request_delete(generation_ref_hash_value=gh,variant_index=1,reason='USER_DELETE',runtime_delete=lambda _: 'accepted',binding_store_path=bp)
        self.assertEqual(snap['runtime_delete_state'],'accepted');self.assertFalse(snap['runtime_erasure_confirmed'])
    def test_runtime_confirmed_can_complete_privacy_erasure(self):
        logical=L('b');gh=generation_ref_hash(logical);m,_,_,_=self.reg(gen=gh,variant=2,data=b'y');bp=Path(self.t.name)/'bind.json';make_binding(bp,logical)
        snap=self.s.request_delete(generation_ref_hash_value=gh,variant_index=2,reason='USER_DELETE',runtime_delete=lambda _: 'confirmed',binding_store_path=bp)
        self.assertFalse(snap['privacy_erasure_complete']);self.s.reconcile_runtime_erasure(generation_ref_hash_value=gh,variant_index=2,receipt='confirmed',authority_evidence_sha256=H('8'));snap=self.s.snapshot(generation_ref_hash_value=gh,variant_index=2);self.assertTrue(snap['privacy_erasure_complete'])
    def test_runtime_exception_unknown(self):
        logical=L('c');gh=generation_ref_hash(logical);self.reg(gen=gh,variant=3,data=b'z');bp=Path(self.t.name)/'bind.json';make_binding(bp,logical)
        def boom(_):raise RuntimeError()
        snap=self.s.request_delete(generation_ref_hash_value=gh,variant_index=3,reason='USER_DELETE',runtime_delete=boom,binding_store_path=bp);self.assertEqual(snap['runtime_delete_state'],'unknown_after_error')
    def test_binding_identity_mismatch_fails(self):
        logical=L('d');gh=generation_ref_hash(logical);self.reg(gen=gh,variant=4,data=b'q');bp=Path(self.t.name)/'bind.json';make_binding(bp,logical);raw=json.loads(bp.read_text());raw['records'][logical]['execution_ref_hash']=H('f');atomicish(bp,raw)
        self.code('GEN_RET_BINDING_IDENTITY_MISMATCH',lambda:self.s.request_delete(generation_ref_hash_value=gh,variant_index=4,reason='USER_DELETE',runtime_delete=lambda _:'confirmed',binding_store_path=bp))
    def test_refund_released(self):
        logical=L('e');gh=generation_ref_hash(logical);self.reg(gen=gh,variant=5);p=Path(self.t.name)/'a21.json';make_a21(p,logical,credit_state='released');r=self.s.sync_refund_from_a21(generation_ref_hash_value=gh,variant_index=5,a21_ledger_path=p);self.assertEqual(r.refund_state,'released_no_charge')
    def test_refund_confirmed_requires_evidence(self):
        logical=L('f');gh=generation_ref_hash(logical);self.reg(gen=gh,variant=6);p=Path(self.t.name)/'a21.json';make_a21(p,logical,credit_state='refunded',logical_cancelled=True,refund_evidence_sha256=H('9'));r=self.s.sync_refund_from_a21(generation_ref_hash_value=gh,variant_index=6,a21_ledger_path=p);self.assertEqual(r.refund_state,'confirmed');self.assertEqual(r.refund_evidence_sha256,H('9'))
    def test_refund_cancelled_committed_is_eligible_not_requested(self):
        logical=L('1');gh=generation_ref_hash(logical);self.reg(gen=gh,variant=7);p=Path(self.t.name)/'a21.json';make_a21(p,logical,credit_state='committed',logical_cancelled=True);r=self.s.sync_refund_from_a21(generation_ref_hash_value=gh,variant_index=7,a21_ledger_path=p);self.assertEqual(r.refund_state,'eligible_not_requested')
    def test_delete_does_not_create_refund(self):
        logical=L('2');gh=generation_ref_hash(logical);self.reg(gen=gh,variant=8);p=Path(self.t.name)/'a21.json';make_a21(p,logical,credit_state='committed',logical_cancelled=False);self.s.request_delete(generation_ref_hash_value=gh,variant_index=8,reason='USER_DELETE');r=self.s.sync_refund_from_a21(generation_ref_hash_value=gh,variant_index=8,a21_ledger_path=p);self.assertEqual(r.refund_state,'not_eligible')
    def test_orphan_first_sweep_observes_not_deletes(self):
        self.root.mkdir(parents=True,exist_ok=True);(self.root/'objects').mkdir(exist_ok=True);data=b'orphan';sha=hashlib.sha256(data).hexdigest();p=self.root/'objects'/f'{sha}.wav';p.write_bytes(data);out=self.s.sweep_orphan_objects();self.assertIn(sha,out['observed']);self.assertTrue(p.exists())
    def test_orphan_second_sweep_after_grace_deletes(self):
        self.root.mkdir(parents=True,exist_ok=True);(self.root/'objects').mkdir(exist_ok=True);data=b'orphan';sha=hashlib.sha256(data).hexdigest();p=self.root/'objects'/f'{sha}.wav';p.write_bytes(data);self.s.sweep_orphan_objects();self.nowv=1011;out=self.s.sweep_orphan_objects();self.assertIn(sha,out['deleted']);self.assertFalse(p.exists())
    def test_referenced_object_never_orphan(self):
        m,_,obj,_=self.reg();out=self.s.sweep_orphan_objects();self.assertNotIn(m['artifact_sha256'],out['observed']);self.assertTrue(obj.exists())
    def test_mutated_orphan_fails_closed(self):
        (self.root/'objects').mkdir(parents=True,exist_ok=True);p=self.root/'objects'/f"{H('a')}.wav";p.write_bytes(b'not matching');self.code('GEN_RET_OBJECT_MUTATED',self.s.sweep_orphan_objects)
    def test_inactive_unregistered_manifest_is_reported_not_deleted(self):
        m,mp,obj=make_variant(self.root,gen=H('a'),variant=9,active=False);out=self.s.inactive_unregistered_manifests();self.assertEqual(out[0][0],f"{H('a')}.v9");self.assertTrue(mp.exists());self.assertTrue(obj.exists())
    def test_adopt_abandoned_manifest_requires_evidence_and_deletes(self):
        m,mp,obj=make_variant(self.root,gen=H('b'),variant=10,active=False);snap=self.s.adopt_abandoned_manifest(generation_ref_hash_value=H('b'),variant_index=10,abandonment_evidence_sha256=H('c'));self.assertTrue(snap['association_delete_confirmed']);self.assertFalse(mp.exists());self.assertFalse(obj.exists())
    def test_active_manifest_cannot_be_abandoned(self):
        self.reg(gen=H('c'),variant=11);self.code('GEN_RET_ACTIVE_ABANDON_FORBIDDEN',lambda:self.s.adopt_abandoned_manifest(generation_ref_hash_value=H('c'),variant_index=11,abandonment_evidence_sha256=H('d')))
    def test_unsupported_runtime_not_false_erasure(self):
        m,_,_,_=self.reg(gen=H('d'),variant=12);self.s.observe_runtime_unsupported(generation_ref_hash_value=H('d'),variant_index=12);snap=self.s.snapshot(generation_ref_hash_value=H('d'),variant_index=12);self.assertFalse(snap['runtime_erasure_confirmed']);self.assertEqual(snap['runtime_delete_state'],'unsupported')
    def test_public_snapshot_is_privacy_safe(self):
        m,_,_,_=self.reg(gen=H('e'),variant=13);snap=self.s.snapshot(generation_ref_hash_value=H('e'),variant_index=13);txt=json.dumps(snap);self.assertFalse(snap['raw_logical_generation_id_emitted']);self.assertFalse(snap['raw_execution_id_emitted']);self.assertFalse(snap['path_emitted']);self.assertFalse(snap['raw_audio_emitted']);self.assertNotIn(str(self.root),txt);self.assertEqual(snap['parity_claim'],'NONE')

    def test_reserved_credit_is_unsettled_not_released(self):
        logical=L('3');gh=generation_ref_hash(logical);self.reg(gen=gh,variant=14);p=Path(self.t.name)/'a21.json';make_a21(p,logical,credit_state='reserved');r=self.s.sync_refund_from_a21(generation_ref_hash_value=gh,variant_index=14,a21_ledger_path=p);self.assertEqual(r.refund_state,'reserved_unsettled')
    def test_runtime_delete_accepted_is_not_resent(self):
        logical=L('4');gh=generation_ref_hash(logical);self.reg(gen=gh,variant=15,data=b'rt');bp=Path(self.t.name)/'bind.json';make_binding(bp,logical);calls=[]
        def delete(x):calls.append(x);return 'accepted'
        self.s.request_delete(generation_ref_hash_value=gh,variant_index=15,reason='USER_DELETE',runtime_delete=delete,binding_store_path=bp)
        self.s.request_delete(generation_ref_hash_value=gh,variant_index=15,reason='USER_DELETE',runtime_delete=delete,binding_store_path=bp)
        self.assertEqual(len(calls),1)
    def test_runtime_not_applicable_requires_evidence(self):
        m,_,_,_=self.reg(gen=H('f'),variant=16);self.s.mark_runtime_storage_not_applicable(generation_ref_hash_value=H('f'),variant_index=16,authority_evidence_sha256=H('7'));snap=self.s.snapshot(generation_ref_hash_value=H('f'),variant_index=16);self.assertTrue(snap['runtime_erasure_confirmed'])
    def test_missing_binding_is_identifier_unavailable_not_not_applicable(self):
        logical=L('5');gh=generation_ref_hash(logical);self.reg(gen=gh,variant=17,data=b'm');bp=Path(self.t.name)/'bind.json';atomicish(bp,{'schema_version':1,'records':{}});snap=self.s.request_delete(generation_ref_hash_value=gh,variant_index=17,reason='USER_DELETE',runtime_delete=lambda _:'confirmed',binding_store_path=bp);self.assertEqual(snap['runtime_delete_state'],'identifier_unavailable');self.assertFalse(snap['runtime_erasure_confirmed'])
    def test_superseded_sweep_after_grace(self):
        m1,_,_,r1=self.reg(gen=H('8'),variant=18,data=b'old')
        self.nowv=1001;make_variant(self.root,gen=H('9'),variant=19,data=b'new',active=True);self.s.register_variant(generation_ref_hash_value=H('9'),variant_index=19)
        self.nowv=1012;out=self.s.sweep_superseded();self.assertIn(f"{H('8')}.v18",out)
    def test_orphan_delete_intent_is_durable_before_unlink(self):
        (self.root/'objects').mkdir(parents=True,exist_ok=True);data=b'orphan2';sha=hashlib.sha256(data).hexdigest();p=self.root/'objects'/f'{sha}.wav';p.write_bytes(data);self.s.sweep_orphan_objects();self.nowv=1011
        # monkey patch unlink to observe registry intent before destructive call
        orig=Path.unlink;seen=[]
        def unlink(path,*a,**k):
            if path==p: seen.append(self.s.registry.load()['orphans'][sha].delete_intent_at_epoch is not None)
            return orig(path,*a,**k)
        Path.unlink=unlink
        try:self.s.sweep_orphan_objects()
        finally:Path.unlink=orig
        self.assertEqual(seen,[True])

    def test_active_pointer_without_manifest_still_protects_shared_object(self):
        m,mp,obj,_=self.reg(gen=H('6'),variant=20,data=b'shared-active')
        # A second active pointer references the same bytes but its manifest is missing.
        other=dict(m);other['project_ref_hash']=H('7');other['role']='bass';other['generation_ref_hash']=H('8');other['variant_index']=21
        atomicish(self.root/'active'/f"{H('7')}.bass.json",other)
        snap=self.s.request_delete(generation_ref_hash_value=H('6'),variant_index=20,reason='USER_DELETE')
        self.assertEqual(snap['physical_artifact_state'],'retained_shared_reference');self.assertTrue(obj.exists())
    def test_orphan_gc_respects_active_pointer_even_when_manifest_missing(self):
        (self.root/'objects').mkdir(parents=True,exist_ok=True);(self.root/'active').mkdir(exist_ok=True)
        data=b'active-only';sha=hashlib.sha256(data).hexdigest();obj=self.root/'objects'/f'{sha}.wav';obj.write_bytes(data)
        active={'project_ref_hash':H('1'),'role':'guitar','generation_ref_hash':H('2'),'variant_index':22,'artifact_sha256':sha,'mix_ready_receipt_sha256':H('3')}
        atomicish(self.root/'active'/f"{H('1')}.guitar.json",active)
        out=self.s.sweep_orphan_objects();self.assertNotIn(sha,out['observed']);self.assertTrue(obj.exists())

    def test_project_delete_covers_all_registered_variants(self):
        self.reg(project=H('a'),role='guitar',gen=H('1'),variant=23,data=b'p1')
        self.reg(project=H('a'),role='bass',gen=H('2'),variant=24,data=b'p2')
        out=self.s.request_project_delete(project_ref_hash_value=H('a'));self.assertEqual(len(out),2);self.assertTrue(all(x['association_delete_confirmed'] for x in out))
    def test_project_delete_fails_closed_on_unregistered_manifest(self):
        self.reg(project=H('b'),role='guitar',gen=H('3'),variant=25,data=b'p1')
        make_variant(self.root,project=H('b'),role='bass',gen=H('4'),variant=26,data=b'p2',active=False)
        self.code('GEN_RET_PROJECT_DELETE_UNREGISTERED_VARIANT',lambda:self.s.request_project_delete(project_ref_hash_value=H('b')))

    def test_retention_policy_change_on_existing_registry_fails_closed(self):
        self.reg(gen=H('f'),variant=27,data=b'policy')
        other=GeneratedStemRetentionService(store_root=self.root,now_epoch=lambda:self.nowv,orphan_grace_seconds=99,superseded_grace_seconds=10)
        self.code('GEN_RET_POLICY_MISMATCH',lambda:other.snapshot(generation_ref_hash_value=H('f'),variant_index=27))
    def test_snapshot_binds_retention_policy(self):
        self.reg(gen=H('a'),variant=28,data=b'policy2');snap=self.s.snapshot(generation_ref_hash_value=H('a'),variant_index=28);self.assertEqual(snap['retention_policy_sha256'],self.s.retention_policy_sha256)

if __name__=='__main__':unittest.main()
