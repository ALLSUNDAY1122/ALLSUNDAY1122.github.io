# Canonical AppIcon upload gate

This is the only remaining binary-transfer step that cannot be completed through the connected GitHub tool.

## Canonical source
- Google Drive: `03_看護師国家試験.png`
- Drive file ID: `1VDnbT0s9gEPde4baCfw9kXYfnEHLQrp3`
- Expected dimensions: `1024 × 1024`
- Expected size: `683,924 bytes`
- Expected SHA-256: `6afe16483852c98e0e030874ce7829f0e1a42fe017bb2f854eee1d9410f8ee80`

## Destination
Upload the exact source PNG bytes as:

`kangoshi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

Changing only the filename from `03_看護師国家試験.png` to `AppIcon-1024.png` is allowed. Do not open-and-resave, crop, resize, recompress, recolor, or generate a replacement image.

## Automatic processing after upload
`.github/workflows/kangoshi-appicon-gate.yml` will:
1. verify SHA-256, file size, and PNG dimensions;
2. bind `Assets.xcassets` in `project.yml`;
3. set `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`;
4. commit the deterministic XcodeGen binding.

A SHA mismatch fails closed; an incorrect image cannot be accepted as the release icon.
