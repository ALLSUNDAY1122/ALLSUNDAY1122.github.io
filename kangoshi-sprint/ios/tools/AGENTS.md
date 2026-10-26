# Safety rules for iOS content-generation tools

These instructions apply to files in this directory. They do not change the app's runtime behavior.

- `prepare_native_content.py` currently calls `shutil.rmtree(OUT)` for `ios/GeneratedResources` **before** validating `product-content/scoring-runtime-audit.json`. Do not assume that an invalid input prevents deletion. Inspect the exact target and preserve existing outputs before any test or modification that may trigger cleanup.
- Do not run deletion, path-traversal, or cleanup-failure tests against the real repository checkout, shared scratch directories, or untracked build artifacts. Use a disposable test workspace and, for pytest, a per-test `tmp_path`. Never point `--basetemp` at a project or shared directory.
- Before assigning any path to a field later consumed by `__exit__`, `finally`, or another cleanup handler, validate the canonical path and its ownership. Reject `..`, a repository root, an unexpected symlink, or a target outside the explicitly disposable output root.
- Mock or intercept destructive calls for the **entire** resource lifecycle, including context-manager exit, exception paths, and finalizers; a mock scoped only to the test body is insufficient.
- Do not change production deletion semantics, remove existing generated assets, or run destructive recovery merely to prove the guard works. Escalate such changes as `HUMAN_REQUIRED` and use non-destructive static checks first.

Sources: [Claude Code issue #105298](https://github.com/anthropics/claude-code/issues/105298), [pytest temporary-directory guidance](https://docs.pytest.org/en/stable/how-to/tmp_path.html), [Python shutil.rmtree documentation](https://docs.python.org/3/library/shutil.html).
