import json
import tempfile
import unittest
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))

from cost_quota_guard import CostGuardError, CostQuotaGuard, PricingPolicy
from budgeted_production_orchestrator import BudgetedProductionSeparationOrchestrator, BudgetedProviderProxy
from production_orchestrator import OrchestratorError

class ProviderFailure(RuntimeError):
    def __init__(self, code, status=None):
        self.code=code; self.status=status; self.retryable=True; super().__init__(code)

class FakeProvider:
    def __init__(self):
        self.create_calls=0; self.upload_calls=0; self.create_error=None
    def upload_asset(self, path):
        self.upload_calls+=1; return 'asset-1'
    def create_separation_task(self, asset_id, models, metadata=None):
        self.create_calls+=1
        if self.create_error: raise self.create_error
        return 'task-1'
    def get_task_state(self, task_id): return None

class BudgetedAdapterTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); root=Path(self.tmp.name)
        self.source_root=root/'src'; self.source_root.mkdir(); self.source=self.source_root/'song.wav'; self.source.write_bytes(b'audio')
        policy=PricingPolicy('USD','0.10','2.00','5.00','20.00')
        self.guard=CostQuotaGuard(policy=policy, ledger_path=root/'ledger.json')
        self.provider=FakeProvider()
        self.orch=BudgetedProductionSeparationOrchestrator(provider=self.provider,cost_guard=self.guard,source_root=self.source_root,artifact_root=root/'art',registry_path=root/'jobs.json',duration_resolver=lambda _:120.0)
    def tearDown(self): self.tmp.cleanup()

    def test_start_reserves_then_confirms_provider_task(self):
        record=self.orch.start(source_path=self.source,project_id='p1',asset_id='a1',models=['vocals','drums'],idempotency_key='idem')
        cost=self.guard.get(record.logical_job_id)
        self.assertEqual(cost.provider_create_state,'confirmed')
        self.assertEqual(cost.estimated_cost,'0.400000')
        self.assertEqual(self.provider.create_calls,1)

    def test_create_rate_limit_becomes_ambiguous_and_keeps_reservation(self):
        self.provider.create_error=ProviderFailure('AUDIOSHAKE_HTTP_429',429)
        with self.assertRaises(OrchestratorError):
            self.orch.start(source_path=self.source,project_id='p1',asset_id='a1',models=['vocals'],idempotency_key='idem')
        raw=json.loads(self.guard.ledger.path.read_text())
        record=next(iter(raw['records'].values()))
        self.assertEqual(record['provider_create_state'],'ambiguous')
        self.assertEqual(record['stable_limit_code'],'SEP_PROVIDER_RATE_LIMITED')
        self.assertNotEqual(record['reserved_cost'],'0.000000')

    def test_proxy_blocks_second_provider_create(self):
        lid='a'*32; fp='1'*64
        self.guard.reserve(logical_job_id=lid,request_fingerprint=fp,duration_seconds=60,target_count=1)
        proxy=BudgetedProviderProxy(self.provider,self.guard)
        md={'logical_job_id':lid,'request_fingerprint':fp}
        proxy.create_separation_task('asset',['vocals'],metadata=md)
        with self.assertRaises(CostGuardError):
            proxy.create_separation_task('asset',['vocals'],metadata=md)
        self.assertEqual(self.provider.create_calls,1)

    def test_duration_is_server_resolved_not_caller_supplied(self):
        record=self.orch.start(source_path=self.source,project_id='p1',asset_id='a1',models=['vocals'],idempotency_key='idem')
        self.assertEqual(self.guard.get(record.logical_job_id).duration_seconds,120.0)

    def test_duration_resolver_failure_fails_before_provider_calls(self):
        root=Path(self.tmp.name)
        broken=BudgetedProductionSeparationOrchestrator(provider=self.provider,cost_guard=self.guard,source_root=self.source_root,artifact_root=root/'art2',registry_path=root/'jobs2.json',duration_resolver=lambda _: (_ for _ in ()).throw(RuntimeError('ffprobe failed')))
        with self.assertRaisesRegex(CostGuardError,'SEP_COST_DURATION_RESOLUTION_FAILED'):
            broken.start(source_path=self.source,project_id='p1',asset_id='a1',models=['vocals'],idempotency_key='idem2')
        self.assertEqual(self.provider.upload_calls,0)
        self.assertEqual(self.provider.create_calls,0)

if __name__=='__main__': unittest.main()
