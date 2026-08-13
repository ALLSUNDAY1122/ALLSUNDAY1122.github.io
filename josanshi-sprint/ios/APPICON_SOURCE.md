# #14 AppIcon canonical source

The production AppIcon must be copied from the individual Learning Sprint icon asset in Google Drive. Do not crop the overview sheet and do not synthesize a replacement.

- Qualification: 助産師国家試験｜学びスプリント
- Canonical file: `14_助産師国家試験.png`
- Google Drive file ID: `134DG19Lknp2p1AFvDAkLPA2zocyj2nOP`
- MIME type: `image/png`
- Verified size: `590870` bytes
- SHA-256: `07668a08a0703b76ecbeca38bbc5b396a248f822de594947ddccd383f0898579`
- Verified at: `2026-08-13`

## Release rule

1. Fetch the exact Drive file above when the signed iOS App target is created.
2. Verify byte size and SHA-256 before producing the AppIcon asset catalog.
3. Do not commit a text placeholder with `.png` extension and do not substitute another Learning Sprint icon.
4. App Store Connect must use the same canonical artwork.

The current GitHub connector used by the ChatGPT development session supports UTF-8 repository writes but not binary PNG uploads, so the binary asset remains in the canonical Drive location until the signed App target/release workflow can ingest it without altering the bytes.
