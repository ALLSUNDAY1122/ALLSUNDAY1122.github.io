import copy
import hashlib
import json
import unittest
from provider_route_decision import DecisionError, EVIDENCE_STATE, decide_routes
H = lambda value: hashlib.sha256(value.encode()).hexdigest()
SHA1, SHA2, SHA3, SHA4 = (H('one'), H('two'), H('three'), H('four'))

def csha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()).hexdigest()

def plan(**overrides):
    payload = {'schema_version': 1, 'evidence_state': EVIDENCE_STATE, 'decision_id': 'route-decision-01', 'policy': {'required_mode_classes': ['FREE_CORE', 'MAJOR'], 'allowed_service_regions': ['JP', 'US'], 'allowed_data_regions': ['JP', 'US'], 'maximum_mean_provider_total_ms': 120000, 'maximum_final_failure_fraction': 0.1, 'maximum_retry_fraction': 0.25, 'cost_currency': 'USD', 'maximum_mean_cost_per_successful_run': 2.0, 'maximum_non_cancel_degraded_fraction': 0.2, 'maximum_uploaded_asset_retention_seconds': 86400, 'require_delete_api': True, 'require_capacity_attestation': True, 'minimum_overall_usability_delta': -0.25, 'minimum_primary_score_margin': 0.02, 'ranking_weights': {'quality': 0.4, 'latency': 0.25, 'reliability': 0.2, 'cost': 0.15}, 'engineering_policy_not_reference_fact': True}}
    payload['policy'].update(overrides)
    return payload

def evidence(route='a', latency=30000, cost=0.5, fail=0.0, retry=0.0, usability=0.1, e04_state='READY_FOR_HQ_E04_LIVE_REVIEW', degraded_states=None, service_region='JP', data_region='JP', retention=3600, delete_api=True, mode_classes=('FREE_CORE', 'MAJOR'), e03_state='READY_FOR_HQ_E03_LIVE_REVIEW', e05_state='READY_FOR_HQ_E05_LIVE_REVIEW', e05_checks=True, quota_status='ADEQUATE', credit_status='ADEQUATE', rate_limit_capacity_status='ADEQUATE'):
    approval = H('approval-' + route)
    e01 = {'schema_version': 1, 'evidence_kind': 'COMMERCIAL_ROUTE_APPROVAL', 'evidence_state': EVIDENCE_STATE, 'result': 'READY_FOR_LIVE_PROVIDER_GATE', 'parity_claim': 'NONE', 'provider': {'provider_id': 'provider-' + route, 'provider_kind': 'HOSTED_API', 'account_tier': 'prod', 'service_region': service_region, 'capability_snapshot_sha256': SHA1, 'models': [{'model_name': 'model', 'model_version': '1', 'quality_profile': 'standard', 'canonical_roles': ['vocals', 'drums', 'bass', 'other']}]}, 'credential_preflight': {'environment_names': ['KEY'], 'all_present': True, 'values_persisted': False, 'server_side_only': True, 'client_distribution_prohibited': True, 'repository_exact_secret_scan': 'PASS'}, 'terms': {}, 'operational_policy': {'data_region': data_region, 'uploaded_asset_retention_seconds': retention, 'output_url_ttl_seconds': 3600, 'delete_api_available': delete_api, 'delete_confirmation_semantics': 'confirmed', 'provider_training_on_user_content_allowed': False, 'commercial_route_flags': {'consumer_app_commercial_use_allowed': True, 'input_confidential': True, 'output_commercial_use_allowed': True, 'output_export_to_end_user_allowed': True}, 'pricing_values_persisted': False, 'pricing_config_sha256': SHA2, 'operational_policy_sha256': SHA3}, 'approval_manifest_identity_sha256': approval, 'generated_at': '2026-08-24T00:00:00Z'}
    h1 = csha(e01)
    modes, runs = ({}, [])
    for index, mode_class in enumerate(mode_classes):
        mode_id = f'm{index}'
        modes[mode_id] = {'mode_class': mode_class, 'required': True, 'planned_runs': 1, 'successful_runs': 1, 'failed_runs': 0, 'mean_provider_total_ms': latency, 'mean_orchestrator_attempt_wall_ms': latency}
        runs.append({'logical_run_id': f'{route}-{index}', 'case_id': f'c{index}', 'fixture_id': f'f{index}', 'fixture_group': 'G1', 'mode_id': mode_id, 'mode_class': mode_class, 'repeat': 1, 'success': True, 'attempt_count': 1, 'retry_count': 0, 'stable_error_code': None, 'run_manifest_sha256': SHA1, 'provider': {'provider_id': 'provider-' + route, 'model_name': 'model', 'model_version': '1', 'quality_profile': 'standard'}, 'timing_ms': {'upload': 1, 'queue': 1, 'inference': latency - 3, 'download': 1, 'total': latency}, 'orchestrator_attempt_wall_time_ms': latency, 'cost': {'currency': 'USD', 'total': cost, 'credits': None, 'basis_sha256': SHA2}, 'artifacts': [{'role': 'vocals', 'sha256': SHA3, 'byte_count': 10}], 'objective_metrics': {'per_stem': {'vocals': {'snr_db': 10}}}})
    e03 = {'schema_version': 1, 'tool_version': 'L1-E03-v1', 'evidence_kind': 'LIVE_SEPARATION_BENCHMARK', 'evidence_state': EVIDENCE_STATE, 'benchmark_state': e03_state, 'parity_claim': 'NONE', 'benchmark_id': 'b-' + route, 'source_evidence': {'plan_sha256': SHA1, 'e01_evidence_sha256': h1, 'e02_evidence_sha256': SHA2, 'e01_approval_identity_sha256': approval, 'a19_corpus_lock_sha256': SHA3, 'e02_rights_intake_lock_sha256': SHA4}, 'requirements': {}, 'summary': {'logical_run_count': len(runs), 'successful_runs': len(runs), 'failed_runs': 0, 'runs_with_retry': 0, 'final_failure_fraction': fail, 'retry_fraction': retry, 'g1_objective_run_count': len(runs), 'modes': modes}, 'acceptance_checks': {'required_mode_repetition': e03_state == 'READY_FOR_HQ_E03_LIVE_REVIEW', 'g1_objective_floor': True, 'final_failure_fraction': fail <= 0.1, 'retry_fraction': retry <= 0.25, 'all_success_artifacts_local_and_hashed': True}, 'runs': runs, 'privacy': {'raw_audio_emitted': False, 'media_paths_emitted': False, 'media_titles_emitted': False, 'raw_rights_ids_emitted': False, 'credential_values_emitted': False, 'signed_urls_emitted': False, 'cost_basis_text_emitted': False}, 'e03_live_benchmark_lock_sha256': H('e03-lock-' + route), 'parity_reason': 'none'}
    h3 = csha(e03)
    e04 = {'schema_version': 1, 'tool_version': 'L1-E04-v1', 'evidence_kind': 'CURRENT_IPHONE_DIFFERENTIAL_LISTENING', 'evidence_state': EVIDENCE_STATE, 'comparison_state': e04_state, 'parity_claim': 'NONE', 'comparison_id': 'c-' + route, 'source_evidence': {'e03_evidence_sha256': h3, 'e03_live_benchmark_lock_sha256': e03['e03_live_benchmark_lock_sha256']}, 'policy': {'minimum_reviewers_per_case_role': 2, 'material_inferiority_vote_fraction': 0.5, 'min_mean_overall_usability_delta': -0.25, 'engineering_policy_not_reference_fact': True, 'exact_input_bytes_required': True}, 'summary': {'review_state': e04_state, 'missing_assignment_count': 1 if e04_state == 'WAITING_REVIEW' else 0, 'mean_dimension_delta_project_minus_reference': {'overall_practice_usability': usability}, 'material_inferiority_case_roles': ['case:vocals'] if e04_state == 'DIFFERENTIAL_FAIL' else [], 'overall_usability_threshold_pass': e04_state != 'DIFFERENTIAL_FAIL' and usability >= -0.25, 'material_inferiority_vote_pass': e04_state != 'DIFFERENTIAL_FAIL', 'role_results': []}, 'reviews': [], 'privacy': {'reference_assets_copied_to_repository': False, 'reference_locator_paths_emitted': False, 'project_locator_paths_emitted': False, 'raw_reviewer_ids_emitted': False, 'blinding_seed_emitted': False, 'raw_audio_emitted': False}, 'e04_differential_lock_sha256': H('e04-lock-' + route), 'parity_reason': 'none'}
    degraded_states = list(degraded_states or [])
    kinds = ['NETWORK_INTERRUPTION', 'CANCEL_UPLOAD', 'CANCEL_SEPARATING', 'CANCEL_FINALIZING', 'AMBIGUOUS_CREATE_RETRY', 'RELAUNCH', 'OUTPUT_EXPIRY', 'RATE_LIMIT', 'LONG_TRACK', 'STORAGE_PRESSURE']
    scenarios = []
    for kind in kinds:
        cancel = kind.startswith('CANCEL_')
        project_state = 'cancelled' if cancel else 'ready'
        if not cancel and degraded_states:
            project_state = degraded_states.pop(0)
        scenarios.append({'scenario_id': kind.lower(), 'scenario_kind': kind, 'project_state_after': project_state, 'stable_error_codes': ['X'], 'provider_create_request_count': 0 if kind == 'CANCEL_UPLOAD' else 1, 'provider_distinct_task_count': 0 if kind == 'CANCEL_UPLOAD' else 1, 'provider_cancel_request_count': 1 if cancel and kind != 'CANCEL_UPLOAD' else 0, 'provider_billable_task_count': 0 if kind == 'CANCEL_UPLOAD' else 1, 'automatic_create_repost_count': 0, 'reconciliation_performed': kind == 'AMBIGUOUS_CREATE_RETRY', 'logical_cancelled': cancel, 'logical_job_identity_sha256': SHA1, 'idempotency_key_sha256': SHA2, 'logical_identity_preserved': True, 'upstream_cancel_state': 'requested' if cancel else 'not_applicable', 'claimed_upstream_cancelled': False, 'outputs_published_after_cancel': False, 'relaunch_observed': kind == 'RELAUNCH', 'rate_limit_observed': kind == 'RATE_LIMIT', 'bounded_streaming_observed': kind == 'LONG_TRACK', 'storage_preflight_observed': kind == 'STORAGE_PRESSURE', 'output_expiry_resolution': 'verified_local_copy' if kind == 'OUTPUT_EXPIRY' else 'not_applicable', 'committed_result_sha256_before': None, 'committed_result_sha256_after': None, 'fault_injection_provenance_sha256': SHA3, 'provider_account_provenance_sha256': SHA4})
    checks = {'all_required_scenarios_present': True, 'no_project_corruption_or_partial_publish': True, 'no_duplicate_billable_task': True, 'logical_identity_preserved': True, 'no_automatic_ambiguous_create_repost': True, 'cancel_claims_truthful': True, 'external_provenance_bound': True}
    if not e05_checks:
        checks['no_duplicate_billable_task'] = False
    e05 = {'schema_version': 1, 'tool_version': 'L1-E05-v1', 'evidence_kind': 'LIVE_PROCESSING_RECOVERY', 'evidence_state': EVIDENCE_STATE, 'recovery_state': e05_state, 'parity_claim': 'NONE', 'recovery_campaign_id': 'r-' + route, 'source_evidence': {'plan_sha256': SHA1, 'e01_evidence_sha256': h1, 'e03_evidence_sha256': h3, 'e01_approval_identity_sha256': approval, 'e03_live_benchmark_lock_sha256': e03['e03_live_benchmark_lock_sha256']}, 'checks': checks, 'scenarios': scenarios, 'privacy': {'credential_values_emitted': False, 'provider_task_ids_emitted': False, 'provider_asset_ids_emitted': False, 'private_paths_emitted': False, 'raw_account_evidence_emitted': False, 'raw_audio_emitted': False}, 'e05_live_recovery_lock_sha256': H('e05-lock-' + route), 'parity_reason': 'none'}
    capacity = {'schema_version': 1, 'evidence_kind': 'PROVIDER_CAPACITY_SNAPSHOT', 'evidence_state': EVIDENCE_STATE, 'parity_claim': 'NONE', 'provider_id': 'provider-' + route, 'e01_approval_identity_sha256': approval, 'captured_at': '2026-08-24T00:00:00Z', 'capacity': {'quota_status': quota_status, 'credit_status': credit_status, 'rate_limit_capacity_status': rate_limit_capacity_status, 'provider_account_provenance_sha256': SHA4}, 'privacy': {'provider_account_id_emitted': False, 'raw_quota_values_emitted': False, 'raw_credit_values_emitted': False, 'raw_billing_records_emitted': False}}
    docs = {'e01': e01, 'e03': e03, 'e04': e04, 'e05': e05, 'capacity': capacity}
    hashes = {'e01': h1, 'e03': h3, 'e04': csha(e04), 'e05': csha(e05), 'capacity': csha(capacity)}
    return (docs, hashes)

class E06(unittest.TestCase):

    def runone(self, docs=None, hashes=None, policy=None):
        if docs is None:
            docs, hashes = evidence()
        return decide_routes(plan=policy or plan(), route_docs={'a': docs}, source_hashes={'a': hashes})

    def test_single_fully_evaluated_route_becomes_primary_and_never_parity(self):
        report = self.runone()
        self.assertEqual(report['decision_state'], 'PRIMARY_SELECTED')
        self.assertEqual(report['routes'][0]['decision'], 'ACCEPT_PRIMARY')
        self.assertEqual(report['parity_claim'], 'NONE')

    def test_missing_live_e04_is_pending_not_reject(self):
        docs, hashes = evidence(); docs['e04'] = None; hashes['e04'] = None
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'PENDING_EXTERNAL_EVIDENCE')

    def test_waiting_human_review_is_pending(self):
        docs, hashes = evidence(e04_state='WAITING_REVIEW')
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'PENDING_EXTERNAL_EVIDENCE')

    def test_missing_capacity_attestation_is_pending(self):
        docs, hashes = evidence(); docs['capacity'] = None; hashes['capacity'] = None
        report = self.runone(docs, hashes)
        self.assertEqual(report['decision_state'], 'PENDING_EXTERNAL_EVIDENCE')
        self.assertIn('E06_CAPACITY_ATTESTATION', report['routes'][0]['reasons'][0])

    def test_capacity_insufficient_rejects_capability(self):
        docs, hashes = evidence(quota_status='INSUFFICIENT')
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'REJECT_CAPABILITY')

    def test_capacity_must_bind_physically_verified_e05_rate_limit_provenance(self):
        docs, hashes = evidence(); docs['capacity']['capacity']['provider_account_provenance_sha256'] = SHA3; hashes['capacity'] = csha(docs['capacity'])
        with self.assertRaises(DecisionError) as caught: self.runone(docs, hashes)
        self.assertEqual(caught.exception.code, 'L1E06_CAPACITY_E05_PROVENANCE_MISMATCH')

    def test_quality_reject(self):
        docs, hashes = evidence(e04_state='DIFFERENTIAL_FAIL', usability=-1.0)
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'REJECT_QUALITY')

    def test_cost_reject(self):
        docs, hashes = evidence(cost=3.0)
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'REJECT_COST')

    def test_latency_reject(self):
        docs, hashes = evidence(latency=130000)
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'REJECT_LATENCY')

    def test_privacy_reject_retention(self):
        docs, hashes = evidence(retention=999999)
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'REJECT_PRIVACY')

    def test_privacy_reject_data_region(self):
        docs, hashes = evidence(data_region='EU')
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'REJECT_PRIVACY')

    def test_capability_reject_mode_coverage(self):
        docs, hashes = evidence(mode_classes=('FREE_CORE',))
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'REJECT_CAPABILITY')

    def test_reliability_reject_degraded_safe_fail_closed(self):
        docs, hashes = evidence(degraded_states=['failed_closed', 'failed_closed'])
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'REJECT_RELIABILITY')

    def test_cancellation_reject_precedes_reliability(self):
        docs, hashes = evidence(); docs['e05']['scenarios'][1]['outputs_published_after_cancel'] = True; hashes['e05'] = csha(docs['e05'])
        self.assertEqual(self.runone(docs, hashes)['routes'][0]['decision'], 'REJECT_CANCELLATION')

    def test_e05_missing_scenario_fails_closed(self):
        docs, hashes = evidence(); docs['e05']['scenarios'].pop(); hashes['e05'] = csha(docs['e05'])
        with self.assertRaises(DecisionError) as caught: self.runone(docs, hashes)
        self.assertEqual(caught.exception.code, 'L1E06_E05_SCENARIO_SET_INVALID')

    def test_chain_mismatch_fails_closed(self):
        docs, hashes = evidence(); docs['e04']['source_evidence']['e03_live_benchmark_lock_sha256'] = SHA1; hashes['e04'] = csha(docs['e04'])
        with self.assertRaises(DecisionError) as caught: self.runone(docs, hashes)
        self.assertEqual(caught.exception.code, 'L1E06_E04_E03_LOCK_MISMATCH')

    def test_evidence_replacement_changes_identity_and_lock(self):
        docs1, hashes1 = evidence(); report1 = self.runone(docs1, hashes1); docs2, hashes2 = evidence(cost=0.6); report2 = self.runone(docs2, hashes2)
        self.assertNotEqual(report1['decision_identity_sha256'], report2['decision_identity_sha256'])
        self.assertNotEqual(report1['decision_lock_sha256'], report2['decision_lock_sha256'])

    def test_two_routes_score_selects_stronger_primary(self):
        docs_a, hashes_a = evidence(route='a', latency=30000, cost=0.4, usability=0.3); docs_b, hashes_b = evidence(route='b', latency=90000, cost=1.5, usability=0.0)
        report = decide_routes(plan=plan(), route_docs={'a': docs_a, 'b': docs_b}, source_hashes={'a': hashes_a, 'b': hashes_b}); by_id = {row['route_id']: row for row in report['routes']}
        self.assertEqual(by_id['a']['decision'], 'ACCEPT_PRIMARY'); self.assertEqual(by_id['b']['decision'], 'ACCEPT_WITH_LIMITS')

    def test_pending_candidate_prevents_premature_primary(self):
        docs_a, hashes_a = evidence(route='a'); docs_b, hashes_b = evidence(route='b'); docs_b['e04'] = None; hashes_b['e04'] = None
        report = decide_routes(plan=plan(), route_docs={'a': docs_a, 'b': docs_b}, source_hashes={'a': hashes_a, 'b': hashes_b}); by_id = {row['route_id']: row for row in report['routes']}
        self.assertEqual(report['decision_state'], 'PENDING_EXTERNAL_EVIDENCE'); self.assertEqual(by_id['a']['decision'], 'ACCEPT_WITH_LIMITS'); self.assertEqual(by_id['b']['decision'], 'PENDING_EXTERNAL_EVIDENCE')

    def test_close_scores_require_hq_selection(self):
        docs_a, hashes_a = evidence(route='a'); docs_b, hashes_b = evidence(route='b')
        report = decide_routes(plan=plan(minimum_primary_score_margin=0.5), route_docs={'a': docs_a, 'b': docs_b}, source_hashes={'a': hashes_a, 'b': hashes_b})
        self.assertEqual(report['decision_state'], 'MULTIPLE_ACCEPTABLE_ROUTES'); self.assertTrue(all((row['decision'] == 'ACCEPT_WITH_LIMITS' for row in report['routes'])))

    def test_public_report_privacy_contract(self):
        report = self.runone(); self.assertTrue(all((value is False for value in report['privacy'].values()))); text = json.dumps(report, sort_keys=True)
        self.assertNotIn('provider_account_path', text); self.assertNotIn('private_contract_text":', text)
if __name__ == '__main__':
    unittest.main()
