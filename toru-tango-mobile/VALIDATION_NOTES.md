# Validation notes

This file records the release-candidate validation entry point for the mobile app.

Run from `toru-tango-mobile/`:

```bash
npm install --no-audit --no-fund
npm run validate
```

`npm run validate` executes TypeScript, ESLint, Expo Doctor, and Cloudflare Worker syntax checks.

The GitHub Actions workflow `.github/workflows/toru-tango-mobile-ci.yml` runs the same checks for changes under `toru-tango-mobile/**` or `toru-tango/backend/**`.

Release handoff must not proceed until the workflow completes successfully and Claude records P0/P1 findings as zero.
