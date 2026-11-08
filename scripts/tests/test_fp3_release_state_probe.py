import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import fp3_release_state_probe as probe


class TerritoryPaginationTests(unittest.TestCase):
    def test_reads_every_page_and_deduplicates(self):
        base = '/v1/inAppPurchaseAvailabilities/123/availableTerritories'
        pages = [
            (200, {'data': [{'type': 'territories', 'id': 'JPN'}],
                   'links': {'next': 'https://api.appstoreconnect.apple.com' + base + '?cursor=two'}}),
            (200, {'data': [{'type': 'territories', 'id': 'USA'}, {'type': 'territories', 'id': 'JPN'}]}),
        ]
        with patch.object(probe, 'api_get', side_effect=pages) as get:
            self.assertEqual(probe.list_territories('fake-token', '123'), ['JPN', 'USA'])
            self.assertEqual(get.call_args_list[0].args[1], base + '?limit=50')
            self.assertEqual(get.call_args_list[1].args[1], base + '?cursor=two')

    def test_rejects_external_or_other_resource_pagination(self):
        for url in ('https://example.org/v1/apps', '//example.org/v1/apps',
                    'https://api.appstoreconnect.apple.com/v1/apps', 'http://api.appstoreconnect.apple.com/v1/apps'):
            with self.subTest(url=url), patch.object(probe, 'api_get', return_value=(200, {'links': {'next': url}})) as get:
                with self.assertRaises(RuntimeError):
                    probe.list_territories('fake-token', '123')
                self.assertEqual(get.call_count, 1)

    def test_rejects_repeated_page(self):
        url = '/v1/inAppPurchaseAvailabilities/123/availableTerritories?limit=50'
        with patch.object(probe, 'api_get', return_value=(200, {'links': {'next': url}})):
            with self.assertRaisesRegex(RuntimeError, 'pagination'):
                probe.list_territories('fake-token', '123')

    def test_propagates_authorization_errors(self):
        with patch.object(probe, 'api_get', side_effect=RuntimeError('HTTP 403')):
            with self.assertRaisesRegex(RuntimeError, '403'):
                probe.safe_get('fake-token', '/v1/apps/123')

    def test_missing_optional_resource_is_not_authorization_failure(self):
        with patch.object(probe, 'api_get', side_effect=RuntimeError('HTTP 404')):
            self.assertEqual(probe.safe_get('fake-token', '/v1/apps/123')['status'], 404)


if __name__ == '__main__':
    unittest.main()
