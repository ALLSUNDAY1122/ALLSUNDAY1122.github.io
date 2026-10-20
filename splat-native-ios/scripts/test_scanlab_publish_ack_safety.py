#!/usr/bin/env python3
"""Source-level safety sentinel. Not a substitute for PostgreSQL/Edge concurrency tests."""
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "SplatNative" / "ScanLabBackend+TrustedPublish.swift"

def test_publish_must_not_call_owner_delete_on_ambiguous_ack() -> None:
    body = SOURCE.read_text(encoding="utf-8")
    assert 'client.functions.invoke(\n            "scanlab-publish"' in body
    assert 'cleanupFailedDraft(' not in body
    assert '"scanlab-delete-scan"' not in body
    assert "A network error or lost ACK cannot authorize deletion" in body
    assert "await loadOwnerScans()" in body

if __name__ == "__main__":
    test_publish_must_not_call_owner_delete_on_ambiguous_ack()
    print("PASS: publish ambiguous ACK cannot invoke generic owner-delete via this Swift source")
