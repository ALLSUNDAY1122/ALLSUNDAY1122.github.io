# Repository-wide agent safety rules

Applies to work in this repository, including parallel agents and Git worktrees. More specific project instructions remain in force.

- A Git worktree separates checkouts; it is **not** an operating-system filesystem sandbox. Do not assume it prevents access to the user's home directory, sibling projects, credentials, or other worktrees. On native Windows, Claude Code's Bash/PowerShell commands run without its OS sandbox (the documented sandbox requires WSL2).
- Before running **agent-generated** tests, shell scripts, package lifecycle scripts, or cleanup jobs, inspect the commands and fixtures for shell evaluation/interpolation (`sh -c`, `bash -c`, `cmd /c`, PowerShell evaluation), recursive deletion, absolute/home paths, and symlink/junction traversal. A test runner can execute a destructive payload indirectly.
- Injection and cleanup tests must use harmless marker files in a dedicated disposable test directory, not real destructive commands as test input. Keep destructive mocks active through `finally`, teardown, and finalizers. Never run an unreviewed destructive test against the real checkout or home directory.
- Before any actual cleanup, resolve the target's canonical path and verify that it is strictly inside an explicitly disposable directory. Refuse the home directory, repository root, `.git`, other worktrees, shared directories, unexpected symlinks/junctions, and paths that cannot be proven safe. If uncertain, stop with `HUMAN_REQUIRED`.
- Do not disable sandboxing, weaken OS permissions, expose secrets, or change production deletion behavior to make a test pass. Prefer static review and non-destructive checks; a genuine destructive integration test requires a separately approved isolated environment.
- These instructions guide agents but are **not an enforcement boundary**. Retain OS-level restrictions, independent verification, and the existing human-approval gates for high-impact operations.

References (checked 2026-10-27):
- https://github.com/anthropics/claude-code/issues/105342 (single-user incident report; not an officially confirmed root cause)
- https://code.claude.com/docs/en/sandboxing
- https://code.claude.com/docs/en/memory
- https://github.com/anthropics/claude-code/issues/105298 (previous, narrower repository-deletion report)
