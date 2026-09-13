#!/usr/bin/env python3
"""Run HM1 App Review submission using the build pinned by the fresh human approval command.

The underlying submitter intentionally contains the mutable submission implementation.
This adapter removes its historical fixed-build coupling without weakening the Human Gate:
the workflow validates the approval command first, then this process uses that exact build.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import app2_005_hm1_prepare_submit as submitter

APP_ID = "6799581662"
ACTION = "prepare_metadata_screenshots_and_submit_for_review"


def load_approved_build(command_path: Path) -> str:
    cmd = json.loads(command_path.read_text(encoding="utf-8"))
    if cmd.get("approved_by_user") is not True:
        raise RuntimeError("HUMAN_GATE: approved_by_user must be true")
    if str(cmd.get("app_id")) != APP_ID:
        raise RuntimeError("HUMAN_GATE: target app mismatch")
    if cmd.get("action") != ACTION:
        raise RuntimeError("HUMAN_GATE: unexpected submit action")
    build = str(cmd.get("build") or "").strip()
    if not build.isdigit():
        raise RuntimeError("HUMAN_GATE: approved build must be a numeric App Store build version")
    return build


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--command", required=True)
    parser.add_argument("--screens", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    approved_build = load_approved_build(Path(args.command))
    submitter.BUILD_VERSION = approved_build
    sys.argv = [
        "app2_005_hm1_prepare_submit.py",
        "--screens", args.screens,
        "--output", args.output,
    ]
    submitter.main()


if __name__ == "__main__":
    main()
