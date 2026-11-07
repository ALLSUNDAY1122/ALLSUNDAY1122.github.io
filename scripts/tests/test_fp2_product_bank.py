import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('fp2_product_audit', ROOT / 'fp2-manabi-sprint/tools/audit_product_bank.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
contract = json.loads((gate.ROOT / 'content-expansion-contract.json').read_text(encoding='utf-8'))


def fixture():
    """Synthetic structural fixtures only; these are never product questions."""
    qs = []
    for domain, count in contract['product_bank']['target_domain_counts'].items():
        for n in range(count):
            qs.append({'id': f'fixture-{len(qs)}', 'question': f'fixture-{len(qs)}',
                       'topic': f'topic-{n}', 'point': 'fixture', 'detail': 'fixture',
                       'contentVersion': 'fixture-v1', 'auditStatus': 'approved', 'domain': domain,
                       'originType': 'original', 'rightsBasis': 'original_question_based_on_primary_public_source',
                       'sourceRefs': ['https://www.nta.go.jp/'], 'lawBaselineDate': '2026-04-01',
                       'examType': 'gakka' if n < 80 else 'jitsugi', 'answerType': 'singleChoice',
                       'choices': ['A', 'B', 'C', 'D'], 'answerIndex': n % 4})
    return {'questions': qs}


class ProductBankTests(unittest.TestCase):
    def check_fixture(self, bank):
        def read(path, **kwargs):
            return json.dumps(contract if path.name == 'content-expansion-contract.json' else bank)
        with patch.object(Path, 'is_file', return_value=True), patch.object(Path, 'read_text', read):
            return gate.audit(Path('synthetic-bank.json'))

    def test_missing_bank_fails_closed(self):
        with patch.object(Path, 'is_file', return_value=False):
            self.assertFalse(gate.audit(Path('missing.json'))['release_ready'])

    def test_complete_structural_fixture(self):
        self.assertEqual(self.check_fixture(fixture())['status'], 'PASS')

    def test_count_or_domain_padding_does_not_pass(self):
        data = fixture()
        data['questions'][-1]['domain'] = data['questions'][0]['domain']
        self.assertIn('DOMAIN_COUNTS_MUST_BE_100_EACH', self.check_fixture(data)['errors'])

    def test_official_reference_cannot_substitute_for_original_product_rights(self):
        data = fixture()
        data['questions'][0]['originType'] = 'official_past_exam'
        self.assertFalse(self.check_fixture(data)['release_ready'])

    def test_duplicate_ids_and_questions_do_not_pass(self):
        data = fixture()
        data['questions'][1] = copy.deepcopy(data['questions'][0])
        result = self.check_fixture(data)
        self.assertIn('INVALID_OR_DUPLICATE_IDS', result['errors'])
        self.assertIn('DUPLICATE_OR_NEAR_DUPLICATE_REVIEW_REQUIRED', result['errors'])

    def test_unapproved_and_invalid_answers_do_not_pass(self):
        data = fixture()
        data['questions'][0]['auditStatus'] = 'draft'
        data['questions'][1]['answerIndex'] = 4
        self.assertFalse(self.check_fixture(data)['release_ready'])


if __name__ == '__main__':
    unittest.main()
