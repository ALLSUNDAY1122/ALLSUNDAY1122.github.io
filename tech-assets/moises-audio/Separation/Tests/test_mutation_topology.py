import hashlib
import unittest

from mutation_topology import (
    BUILTIN_STORE_PROFILES,
    DeploymentTopology,
    MutationTopologyError,
    SharedMutationAuthority,
    StoreSafetyProfile,
    assess_store_topology,
    assert_store_topology_safe,
    lane1_topology_snapshot,
    required_shared_capabilities,
)


def authority(*caps):
    return SharedMutationAuthority(
        authority_ref_hash=hashlib.sha256(b"shared-authority").hexdigest(),
        capabilities=tuple(sorted(caps)),
    )


class MutationTopologyTests(unittest.TestCase):
    def test_flock_backed_stores_pass_only_single_host(self):
        for store_id in ("a16_reconnect_registry", "a23_variant_store", "a24_retention_store"):
            with self.subTest(store_id=store_id):
                self.assertEqual(assert_store_topology_safe(store_id, DeploymentTopology.SINGLE_HOST).state, "PASS")

    def test_privacy_registry_fails_even_single_host_until_rmw_serialized(self):
        d = assess_store_topology("a09_privacy_registry", "single_host")
        self.assertEqual(d.state, "FAIL_CLOSED")
        self.assertEqual(d.stable_error_code, "L1A27_SINGLE_HOST_SERIALIZATION_INSUFFICIENT")

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

    def test_snapshot_is_truthful_non_parity_and_exposes_unsafe_topology(self):
        one = lane1_topology_snapshot("single_host")
        self.assertFalse(one["all_safe"])
        self.assertEqual(one["parity_claim"], "NONE")
        many = lane1_topology_snapshot("multi_host")
        self.assertFalse(many["all_safe"])
        self.assertTrue(all(row["state"] == "FAIL_CLOSED" for row in many["stores"]))

    def test_unknown_store_and_bad_topology_rejected(self):
        with self.assertRaises(MutationTopologyError) as cm:
            assess_store_topology("missing", "single_host")
        self.assertEqual(cm.exception.code, "L1A27_STORE_UNKNOWN")
        with self.assertRaises(MutationTopologyError) as cm:
            assess_store_topology("a16_reconnect_registry", "cluster-ish")
        self.assertEqual(cm.exception.code, "L1A27_TOPOLOGY_INVALID")


if __name__ == "__main__":
    unittest.main()
