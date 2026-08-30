#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

INTEGRATION_BRANCH = "scanner-parity/integration"
WORKFLOW_ID = "scanner-parity-golden-video-probe"
MARKER = f"  {WORKFLOW_ID}:"
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
WORKFLOW_BLOCK = r'''

  scanner-parity-golden-video-probe:
    name: Scanner Parity - Golden Video Equivalence Probe
    max_build_duration: 45
    instance_type: mac_mini_m2
    environment:
      xcode: latest
    scripts:
      - name: Probe Golden video equivalence
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR"
          bash scanner-parity/HQGoldenRunner/probe-golden-video-equivalence-codemagic.sh
'''


def run(*args: str, cwd: Path | None = None, capture: bool = False) -> str:
    r = subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=capture)
    return r.stdout.strip() if capture else ""


def main() -> int:
    command_path = Path(sys.argv[1] if len(sys.argv) > 1 else "automation/scanner-parity-golden-video-probe-command.json")
    command = json.loads(command_path.read_text(encoding="utf-8"))
    expected = str(command.get("expected_integration_sha") or "")
    if not SHA_RE.fullmatch(expected):
        raise SystemExit("Invalid expected_integration_sha")
    run_id = str(command.get("run_id") or "")
    if not re.fullmatch(r"[0-9a-fA-F-]{36}", run_id):
        raise SystemExit("Invalid run_id")

    run("git", "fetch", "origin", INTEGRATION_BRANCH)
    current = run("git", "rev-parse", f"origin/{INTEGRATION_BRANCH}", capture=True)
    if current != expected:
        raise SystemExit(f"Integration moved: expected {expected}, observed {current}")

    with tempfile.TemporaryDirectory(prefix="scanner-video-probe-prep-") as temp:
        work = Path(temp) / "repo"
        run("git", "worktree", "add", "--detach", str(work), f"origin/{INTEGRATION_BRANCH}")
        try:
            helper = work / "scanner-parity/HQGoldenRunner/probe-golden-video-equivalence-codemagic.sh"
            if not helper.is_file():
                raise SystemExit("Golden video probe helper is not integrated")
            run("bash", "-n", str(helper), cwd=work)
            yaml_path = work / "codemagic.yaml"
            text = yaml_path.read_text(encoding="utf-8")
            if MARKER not in text:
                if not text.endswith("\n"):
                    text += "\n"
                text += WORKFLOW_BLOCK.lstrip("\n")
                yaml_path.write_text(text, encoding="utf-8")
                run("git", "config", "user.name", "github-actions[bot]", cwd=work)
                run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com", cwd=work)
                run("git", "add", "codemagic.yaml", cwd=work)
                run("git", "commit", "-m", "scanner-parity: prepare Golden video probe workflow", cwd=work)
                run("git", "push", "origin", f"HEAD:{INTEGRATION_BRANCH}", cwd=work)
            prepared = run("git", "rev-parse", "HEAD", cwd=work, capture=True)
            if MARKER not in yaml_path.read_text(encoding="utf-8"):
                raise SystemExit("Codemagic probe workflow preparation failed")
            Path("/tmp/scanner-video-probe-prepared-sha.txt").write_text(prepared + "\n", encoding="utf-8")
            print(f"Prepared Golden video probe at {prepared}")
        finally:
            run("git", "worktree", "remove", "--force", str(work))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
