# AppIcon canonical source

- Product: 新ITパスポート｜学びスプリント
- Canonical source: `ios/tools/ITPassport-canonical.png` (original PNG bytes, stored directly in the repository without re-encoding).
- Original provenance: Google Drive `ITパスポート.png`, file ID `1Cej-mIkRG1NVjajSK8PI1xCE4vI17cXl`; not accessed at build time.
- Source dimensions: 1254×1254; RGB / no alpha.
- Source SHA-256: `a1c5fc063d443de17c8a498c132ccaad961dfa353a372756cd4e79ce4023f288`
- Source RGB pixel SHA-256: `7ecad6e7e195da9be52b2b75f2afd3dbfd199c1134fb737207abdd808ebc0403`
- Required output RGB pixel SHA-256: `7fa04f71c4c19897a606849836d7c73f196ec06124659755e9f370c1e3be55b3`
- Reference output PNG file SHA-256 (original encoding; diagnostic only): `be4b5e7a38909ce702065c660cc18f6401b9ae2a560e71b342d8204f5067e677`
- Pillow: 12.3.0; LANCZOS resize to 1024×1024, RGB, PNG optimize=True, compress_level=9.

`ios/tools/materialize_appicon.sh` reads the repository-local canonical PNG directly, verifies both source hashes and format, then generates the output and verifies its format and exact decoded RGB pixel SHA-256 before replacing `AppIcon-1024.png`.

The source file SHA-256, source RGB pixel SHA-256 and output RGB pixel SHA-256 are mandatory on every run, even if output already exists. The actual output PNG file SHA-256 is logged for diagnostics, not compared to the reference encoding: PNG compression bytes can vary by platform or codec version without changing decoded pixels. Pixel differences remain fatal.

The canonical PNG must be stored byte-for-byte unchanged. No Base64 encoding, source re-encoding, crop, redraw, substitution, or Drive fallback is permitted.

A missing canonical source or any integrity or format failure stops the build. The existing output is not replaced unless all integrity and format checks pass.

Pillow installation may require package-index access if the pinned version is not installed.
