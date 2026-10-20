#!/usr/bin/env python3
"""Read-only Scan Lab release-source provenance preflight.

Run at the repository root. This does NOT approve CI, codesigning, TestFlight, or App Review.
No network requests, branch writes, secrets, or external API calls are made.
"""
import argparse
import pathlib
import re
import subprocess
import sys

PRODUCT = "69f365816bb1ae61a558f40778279b507bd705d6"
RELEASE_BASE = "3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a"
CANDIDATE = "4f3a0de772df8e8d87e4d5b4932d717d596f17d8"
CONFIG = pathlib.Path("codemagic.yaml")


def git(*args):
    return subprocess.run(["git", *args], text=True, capture_output=True, check=False)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def inspect_commit(ref, expected):
    result = git("rev-parse", "--verify", f"{ref}^{{commit}}")
    require(result.returncode == 0, f"Missing commit ref: {ref}")
    sha = result.stdout.strip()
    require(sha == expected, f"{ref} HEAD changed; observed {sha}, expected {expected}")
    return sha


def is_ancestor(older, newer):
    return git("merge-base", "--is-ancestor", older, newer).returncode == 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--product", default="feature/splat-native-ios-poc")
    parser.add_argument("--release", default="release/scanlab-testflight")
    parser.add_argument("--candidate", default="attempt/scanlab-release-candidate-20261020-a1")
    args = parser.parse_args()
    inspect_commit(args.product, PRODUCT)
    inspect_commit(args.release, RELEASE_BASE)
    inspect_commit(args.candidate, CANDIDATE)
    require(is_ancestor(PRODUCT, CANDIDATE), "Candidate does not include pinned product source")
    require(is_ancestor(RELEASE_BASE, CANDIDATE), "Candidate is not fast-forward from pinned release source")

    # Inspect the CONFIG FROM THE CANDIDATE COMMIT, not whichever branch is checked out.
    result = git("show", f"{CANDIDATE}:codemagic.yaml")
    require(result.returncode == 0, "Candidate missing codemagic.yaml")
    config = result.stdout
    require(re.search(r"(?m)^  scanlab-ios:\\s*$", config) is not None, "Missing scanlab-ios workflow")
    chunk = config.split("  scanlab-ios:", 1)[1]
    # Inspect just this workflow (not unrelated app definitions).
    chunk = re.split(r"(?m)^  [a-zA-Z][\\w-]*:\\s*$", chunk, maxsplit=1)[0]
    required = (
        "jp.allsunday1122.splatlab",
        "6803778932",
        "SplatNative",
        "submit_to_testflight: true",
        "submit_to_app_store: false",
        "Verify immutable materialized reconstruction source",
        "CURRENT_PROJECT_VERSION",
        "get-latest-testflight-build-number",
    )
    for needle in required:
        require(needle in chunk, f"Missing release contract: {needle}")
    require("python3 splat-native-ios/scripts/apply_s13_depth_seed.py" not in chunk,
            "Codemagic would mutate release source while building")
    require("testFlightInternalTestingOnly" in chunk, "Internal TestFlight signing mode not found")
    print("PASS: pinned ancestry + immutable materialization + Internal TestFlight configuration")
    print("NOT VERIFIED: Native CI, signed IPA, Apple upload, internal group assignment")


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print(f"RELEASE PREFLIGHT NO-GO: {exc}", file=sys.stderr)
        sys.exit(1)
