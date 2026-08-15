# Scan Lab Browser Share Asset Contract v1

## Scope

S6 prepares a deterministic local package for browser sharing. It does **not** upload the package, create a public URL, or change network/privacy policy. Those actions belong to S7 and require the explicit upload flow defined by the parity plan.

## Package layout

```text
scanlab-share-<uuid>/
├── manifest.json
├── scene.spz
└── preview.jpg        # optional
```

`scene.spz` is generated from the actual Gaussian Splat result through `SplatIO.SPZSceneWriter`. It is not a renamed `.splat` file.

## manifest.json schemaVersion 1

```json
{
  "schemaVersion": 1,
  "representation": "gaussian-splat",
  "primaryAsset": {
    "fileName": "scene.spz",
    "mediaType": "application/octet-stream",
    "byteLength": 123456,
    "sha256": "<64 lowercase hex characters>"
  },
  "previewFileName": "preview.jpg",
  "createdAt": "2026-08-15T01:00:00Z",
  "containsLocation": false
}
```

### Required invariants

- `schemaVersion` is `1`.
- `representation` is `gaussian-splat`.
- `primaryAsset.fileName` is relative to the package root and currently `scene.spz`.
- `byteLength` must exactly match the packaged SPZ bytes.
- `sha256` must exactly match SHA-256 of the packaged SPZ bytes.
- `containsLocation` is always `false` in S6. S6 neither infers nor embeds geolocation.
- `preview.jpg` is optional and must only be referenced when present.

## S7 handoff requirements

S7 may consume this package only after validating the manifest and checksum. S7 owns all network behavior, including:

1. explicit user confirmation before upload;
2. upload transport and retry policy;
3. server-side object identity and access control;
4. creation of a browser-view URL / embed URL;
5. deletion, expiry, revocation, and abuse handling;
6. Privacy Manifest and privacy-policy changes required by networking;
7. confirmation that no package becomes public before the user explicitly chooses the upload/share action.

S7 must not silently convert local S6 exports into network uploads.

## Compatibility policy

A future incompatible manifest change increments `schemaVersion`. New optional fields may be added without changing the version only when v1 consumers can safely ignore them. S7 should reject unknown higher schema versions rather than guessing.
