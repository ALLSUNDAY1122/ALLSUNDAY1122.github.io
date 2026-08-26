import hashlib
import unittest
from unittest.mock import patch

import mutation_topology
from mutation_topology import (
    BUILTIN_STORE_PROFILES,
    EXPECTED_BUILTIN_STORE_IDS,
    RECONCILIATION_STORE_IDS,
    DeploymentTopology,
    MutationTopologyError,
    SharedMutationAuthority,
    StoreSafetyProfile,
    assess_store_topology,
    assert_reconciliation_topology_safe,
    assert_store_topology_safe,
    lane1_topology_snapshot,
    reconciliation_topology_snapshot,
    required_shared_capabilities,
)


def authority(*caps):
    return SharedMutationAuthority(
        authority_ref_hash=hashlib.sha256(b"shared-authority").hexdigest(),
        capabilities=tuple(sorted(caps)),
    )


class MutationTopologyTests(unittest.TestCase):
    def test_flock_backed_stores_pass_single_host(self):
        for store_id in BUILTIN_STORE_PROFILES:
            with self.subTest(store_id=store_id):
                self.assertEqual(assert_store_topology_safe(store_id, DeploymentTopology.SINGLE_HOST).state, "PASS")

    def test_privacy_registry_is_single_host_safe_after_a28_rmw_serialization(self):
        d = assess_store_topology("a09_privacy_registry", "single_host")
        self.assertEqual(d.state, "PASS")
        self.assertIsNone(d.stable_error_code)
        self.assertEqual(BUILTIN_STORE_PROFILES["a09_privacy_registry"].local_serialization, "posix_flock")

    def test_reconciliation_ledger_is_explicitly_in_deployment_inventory(self):
        store_id = "a29_provider_delete_reconciliation_ledger"
        self.assertIn(store_id, EXPECTED_BUILTIN_STORE_IDS)
        self.assertIn(store_id, BUILTIN_STORE_PROFILES)
        profile = BUILTIN_STORE_PROFILES[store_id]
        self.assertEqual(profile.local_serialization, "posix_flock")
        self.assertTrue(profile.single_host_safe)
        self.assertFalse(profile.shared_authority_adapter)
        self.assertEqual(profile.risk, "reconciliation_watermark_race")

    def test_conflict_decision_store_is_explicitly_in_deployment_inventory(self):
        store_id = "a37_conflict_decision_store"
        self.assertIn(store_id, EXPECTED_BUILTIN_STORE_IDS)
        self.assertIn(store_id, BUILTIN_STORE_PROFILES)
        self.assertIn(store_id, RECONCILIATION_STORE_IDS)
        profile = BUILTIN_STORE_PROFILES[store_id]
        self.assertEqual(profile.local_serialization, "posix_flock")
        self.assertTrue(profile.single_host_safe)
        self.assertFalse(profile.shared_authority_adapter)
        self.assertEqual(profile.risk, "adjudication_decision_race")

    def test_reconciliation_ledger_passes_single_host_and_fails_multi_host_without_authority(self):
        store_id = "a29_provider_delete_reconciliation_ledger"
        self.assertEqual(assess_store_topology(store_id, "single_host").state, "PASS")
        d = assess_store_topology(store_id, "multi_host")
        self.assertEqual(d.state, "FAIL_CLOSED")
        self.assertEqual(d.stable_error_code, "L1A27_SHARED_AUTHORITY_REQUIRED")

    def test_conflict_decision_store_fails_multi_host_without_authority_or_adapter(self):
        store_id = "a37_conflict_decision_store"
        self.assertEqual(assess_store_topology(store_id, "single_host").state, "PASS")
        d = assess_store_topology(store_id, "multi_host")
        self.assertEqual(d.state, "FAIL_CLOSED")
        self.assertEqual(d.stable_error_code, "L1A27_SHARED_AUTHORITY_REQUIRED")
        a = authority(*required_shared_capabilities())
        d = assess_store_topology(store_id, "multi_host", authority=a)
        self.assertEqual(d.state, "FAIL_CLOSED")
        self.assertEqual(d.stable_error_code, "L1A27_SHARED_AUTHORITY_ADAPTER_NOT_IMPLEMENTED")

    def test_reconciliation_ledger_still_fails_with_capabilities_but_no_adapter(self):
        store_id = "a29_provider_delete_reconciliation_ledger"
        a = authority(*required_shared_capabilities())
        d = assess_store_topology(store_id, "multi_host", authority=a)
        self.assertEqual(d.state, "FAIL_CLOSED")
        self.assertEqual(d.stable_error_code, "L1A27_SHARED_AUTHORITY_ADAPTER_NOT_IMPLEMENTED")
        self.assertEqual(d.authority_ref_hash, a.authority_ref_hash)

    def test_multi_host_without_authority_fails_closed(self):
        for store_id in BUILTIN_STORE_PROFILES:
            with self.subTest(store_id=store_id):
                d = assess_store_topology(store_id, "multi_host")
                self.assertEqual(d.state, "FAIL_CLOSED")
                self.assertEqual(d.stable_error_code, "L1A27_SHARED_AUTHORITY_REQUIRED")

    def test_incomplete_authority_is_rejected(self):
        with self.assertRaises(MutationTopologyError) as cm:
            assess_store_topology(
                "a16_reconnect_registry",
                "multi_host",
                authority=authority("atomic_compare_and_swap", "durable_commit"),
            )
        self.assertEqual(cm.exception.code, "L1A27_SHARED_AUTHORITY_CAPABILITY_MISSING")

    def test_complete_authority_still_fails_without_store_adapter(self):
        a = authority(*required_shared_capabilities())
        d = assess_store_topology("a24_retention_store", "multi_host", authority=a)
        self.assertEqual(d.state, "FAIL_CLOSED")
        self.assertEqual(d.stable_error_code, "L1A27_SHARED_AUTHORITY_ADAPTER_NOT_IMPLEMENTED")
        self.assertEqual(d.authority_ref_hash, a.authority_ref_hash)

    def test_future_adapter_can_pass_only_with_full_authority_contract(self):
        profile = StoreSafetyProfile(
            store_id="future_shared_store",
            local_serialization="posix_flock",
            single_host_safe=True,
            shared_authority_adapter=True,
            risk="cross_host_race",
        )
        a = authority(*required_shared_capabilities())
        d = assert_store_topology_safe("future_shared_store", "multi_host", authority=a, profile=profile)
        self.assertEqual(d.state, "PASS")

    def test_reconciliation_composite_preflight_passes_single_host(self):
        snapshot = assert_reconciliation_topology_safe("single_host")
        self.assertTrue(snapshot["all_safe"])
        self.assertEqual(tuple(snapshot["store_inventory"]), RECONCILIATION_STORE_IDS)
        self.assertEqual(
            {row["store_id"] for row in snapshot["stores"]},
            set(RECONCILIATION_STORE_IDS),
        )
        self.assertEqual(snapshot["parity_claim"], "NONE")

    def test_reconciliation_composite_preflight_fails_multi_host_without_authority(self):
        snapshot = reconciliation_topology_snapshot("multi_host")
        self.assertFalse(snapshot["all_safe"])
        self.assertTrue(all(row["state"] == "FAIL_CLOSED" for row in snapshot["stores"]))
        self.assertTrue(
            all(row["stable_error_code"] == "L1A27_SHARED_AUTHORITY_REQUIRED" for row in snapshot["stores"])
        )
        with self.assertRaises(MutationTopologyError) as cm:
            assert_reconciliation_topology_safe("multi_host")
        self.assertEqual(cm.exception.code, "L1A27_SHARED_AUTHORITY_REQUIRED")

    def test_reconciliation_composite_preflight_rejects_capability_labels_without_adapters(self):
        shared = authority(*required_shared_capabilities())
        authorities = {store_id: shared for store_id in RECONCILIATION_STORE_IDS}
        snapshot = reconciliation_topology_snapshot("multi_host", authorities=authorities)
        self.assertFalse(snapshot["all_safe"])
        self.assertTrue(
            all(
                row["stable_error_code"] == "L1A27_SHARED_AUTHORITY_ADAPTER_NOT_IMPLEMENTED"
                for row in snapshot["stores"]
            )
        )

    def test_reconciliation_composite_preflight_rejects_unknown_authority_store(self):
        shared = authority(*required_shared_capabilities())
        with self.assertRaises(MutationTopologyError) as cm:
            reconciliation_topology_snapshot(
                "multi_host",
                authorities={"not-a-reconciliation-store": shared},
            )
        self.assertEqual(cm.exception.code, "L1A38_RECONCILIATION_AUTHORITY_STORE_UNKNOWN")

    def test_snapshot_truthfully_passes_single_host_but_rejects_multi_host(self):
        one = lane1_topology_snapshot("single_host")
        self.assertTrue(one["all_safe"])
        self.assertEqual(one["parity_claim"], "NONE")
        self.assertEqual(set(one["store_inventory"]), EXPECTED_BUILTIN_STORE_IDS)
        many = lane1_topology_snapshot("multi_host")
        self.assertFalse(many["all_safe"])
        self.assertTrue(all(row["state"] == "FAIL_CLOSED" for row in many["stores"]))
        self.assertIn(
            "a29_provider_delete_reconciliation_ledger",
            {row["store_id"] for row in many["stores"]},
        )
        self.assertIn(
            "a37_conflict_decision_store",
            {row["store_id"] for row in many["stores"]},
        )

    def test_inventory_mismatch_fails_closed(self):
        reduced = dict(BUILTIN_STORE_PROFILES)
        reduced.pop("a29_provider_delete_reconciliation_ledger")
        with patch.object(mutation_topology, "BUILTIN_STORE_PROFILES", reduced):
            with self.assertRaises(MutationTopologyError) as cm:
                mutation_topology.lane1_topology_snapshot("single_host")
        self.assertEqual(cm.exception.code, "L1A35_BUILTIN_STORE_INVENTORY_MISMATCH")

    def test_conflict_decision_store_inventory_removal_fails_closed(self):
        reduced = dict(BUILTIN_STORE_PROFILES)
        reduced.pop("a37_conflict_decision_store")
        with patch.object(mutation_topology, "BUILTIN_STORE_PROFILES", reduced):
            with self.assertRaises(MutationTopologyError) as cm:
                mutation_topology.reconciliation_topology_snapshot("single_host")
        self.assertEqual(cm.exception.code, "L1A35_BUILTIN_STORE_INVENTORY_MISMATCH")

    def test_reconciliation_store_contract_mismatch_fails_closed(self):
        with patch.object(mutation_topology, "RECONCILIATION_STORE_IDS", ("a09_privacy_registry",)):
            with self.assertRaises(MutationTopologyError) as cm:
                mutation_topology.reconciliation_topology_snapshot("single_host")
        self.assertEqual(cm.exception.code, "L1A38_RECONCILIATION_STORE_INVENTORY_INVALID")

    def test_unknown_store_and_bad_topology_rejected(self):
        with self.assertRaises(MutationTopologyError) as cm:
            assess_store_topology("missing", "single_host")
        self.assertEqual(cm.exception.code, "L1A27_STORE_UNKNOWN")
        with self.assertRaises(MutationTopologyError) as cm:
            assess_store_topology("a16_reconnect_registry", "cluster-ish")
        self.assertEqual(cm.exception.code, "L1A27_TOPOLOGY_INVALID")


if __name__ == "__main__":
    unittest.main()
