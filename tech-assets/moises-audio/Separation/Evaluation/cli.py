from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from evaluation_core import (
    EvaluationError,
    dump_json,
    evaluate_run,
    load_json,
    validate_fixture_manifest,
    validate_listening_records,
    validate_run_manifest,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Rights-aware separation evaluation gate")
    sub = parser.add_subparsers(dest="command", required=True)

    fixture = sub.add_parser("validate-fixture", help="validate fixture rights/provenance and hashes")
    fixture.add_argument("--fixture", required=True)
    fixture.add_argument("--root", required=True)
    fixture.add_argument("--purpose", default="REGRESSION", choices=["REGRESSION", "PARITY_CANDIDATE"])

    run = sub.add_parser("validate-run", help="validate provider/model/cost/timing/result manifest")
    run.add_argument("--fixture", required=True)
    run.add_argument("--run", required=True)
    run.add_argument("--root", required=True)

    listening = sub.add_parser("validate-listening", help="validate blinded listening capture")
    listening.add_argument("--fixture", required=True)
    listening.add_argument("--listening", required=True)
    listening.add_argument("--purpose", default="REGRESSION", choices=["REGRESSION", "PARITY_CANDIDATE"])

    evaluate = sub.add_parser("evaluate", help="produce machine-readable objective/listening evidence")
    evaluate.add_argument("--fixture", required=True)
    evaluate.add_argument("--run", required=True)
    evaluate.add_argument("--root", required=True)
    evaluate.add_argument("--listening")
    evaluate.add_argument("--purpose", default="REGRESSION", choices=["REGRESSION", "PARITY_CANDIDATE"])
    evaluate.add_argument("--output", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "validate-fixture":
            summary = validate_fixture_manifest(load_json(args.fixture), Path(args.root), purpose=args.purpose)
        elif args.command == "validate-run":
            fixture = load_json(args.fixture)
            summary = validate_run_manifest(load_json(args.run), fixture, Path(args.root))
        elif args.command == "validate-listening":
            summary = validate_listening_records(load_json(args.listening), load_json(args.fixture), purpose=args.purpose)
        else:
            fixture = load_json(args.fixture)
            run = load_json(args.run)
            listening = load_json(args.listening) if args.listening else None
            summary = evaluate_run(fixture, run, Path(args.root), purpose=args.purpose, listening_records=listening)
            dump_json(args.output, summary)
        print(json.dumps({"status": "PASS", "result": summary}, sort_keys=True, allow_nan=False))
        return 0
    except EvaluationError as exc:
        print(json.dumps({"status": "FAIL", "code": exc.code, "message": exc.message}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
