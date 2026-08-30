#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="${GOLDEN_RUN_ID:-}"
TOKEN="${GOLDEN_DOWNLOAD_TOKEN:-}"
RELAY="${GOLDEN_RELAY_URL:-}"
EXPECTED_SOURCE_SHA="${GOLDEN_EXPECTED_SOURCE_SHA:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Golden video equivalence probe requires macOS." >&2
  exit 2
fi
if [[ -z "$RUN_ID" || -z "$TOKEN" || -z "$RELAY" || -z "$EXPECTED_SOURCE_SHA" ]]; then
  echo "Missing required probe environment." >&2
  exit 2
fi
cd "$ROOT"
actual_source_sha="$(git rev-parse HEAD)"
if [[ "$actual_source_sha" != "$EXPECTED_SOURCE_SHA" ]]; then
  echo "Source SHA mismatch; refusing probe." >&2
  exit 3
fi

WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/scanner-golden-video-probe.XXXXXX")"
chmod 700 "$WORK_ROOT"
trap 'rm -rf "$WORK_ROOT"' EXIT
MANIFEST="$WORK_ROOT/manifest.json"
VIDEO="$WORK_ROOT/candidate.mp4"
PROBE_SWIFT="$WORK_ROOT/probe.swift"
PROBE_JSON="$WORK_ROOT/probe.json"

python3 - "$RELAY" "$RUN_ID" "$TOKEN" "$MANIFEST" <<'PY'
import json,sys,urllib.request
relay,run_id,token,out=sys.argv[1:]
req=urllib.request.Request(
    f"{relay.rstrip('/')}/manifest?run_id={run_id}",
    headers={"Authorization":f"Bearer {token}","Accept":"application/json"},
)
with urllib.request.urlopen(req,timeout=60) as r:
    obj=json.loads(r.read())
source=((obj.get("source_urls") or {}).get("video") or "").strip()
if not source:
    raise SystemExit("Probe manifest has no video source URL")
open(out,"w",encoding="utf-8").write(json.dumps(obj,ensure_ascii=False,indent=2))
PY

python3 - "$MANIFEST" "$VIDEO" <<'PY'
import json,sys,urllib.request
manifest_path,out=sys.argv[1:]
m=json.load(open(manifest_path,encoding="utf-8"))
url=m["source_urls"]["video"]
req=urllib.request.Request(url,headers={"User-Agent":"scanner-parity-golden-video-probe/1"})
with urllib.request.urlopen(req,timeout=600) as r, open(out,"wb") as f:
    while True:
        b=r.read(4*1024*1024)
        if not b: break
        f.write(b)
PY

cat > "$PROBE_SWIFT" <<'SWIFT'
import Foundation
import AVFoundation
import CoreGraphics

struct Sample: Codable {
    let requestedSeconds: Double
    let actualSeconds: Double
    let averageHash256: String
    let differenceHash64: String
}
struct Report: Codable {
    let schemaVersion: Int
    let durationSeconds: Double
    let width: Int
    let height: Int
    let sampleCount: Int
    let samples: [Sample]
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}
func grayPixels(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: width * height)
    guard let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                              bitmapInfo: CGImageAlphaInfo.none.rawValue) else { fatalError("CGContext") }
    ctx.interpolationQuality = .medium
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}
func averageHash256(_ image: CGImage) -> String {
    let p = grayPixels(image, width: 16, height: 16)
    let mean = Double(p.reduce(0) { $0 + Int($1) }) / Double(p.count)
    var out = [UInt8](repeating: 0, count: 32)
    for i in 0..<256 where Double(p[i]) >= mean { out[i / 8] |= UInt8(1 << (7 - (i % 8))) }
    return hex(out)
}
func differenceHash64(_ image: CGImage) -> String {
    let p = grayPixels(image, width: 9, height: 8)
    var out = [UInt8](repeating: 0, count: 8)
    for y in 0..<8 {
        for x in 0..<8 {
            let bit = y * 8 + x
            if p[y * 9 + x] > p[y * 9 + x + 1] { out[bit / 8] |= UInt8(1 << (7 - (bit % 8))) }
        }
    }
    return hex(out)
}

guard CommandLine.arguments.count == 2 else { fatalError("video path required") }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let asset = AVURLAsset(url: url)
let seconds = CMTimeGetSeconds(asset.duration)
if !seconds.isFinite || seconds <= 0 { fatalError("invalid duration") }
let track = asset.tracks(withMediaType: .video).first!
let transformed = track.naturalSize.applying(track.preferredTransform)
let width = Int(abs(transformed.width).rounded())
let height = Int(abs(transformed.height).rounded())
let fractions: [Double] = [0.02,0.08,0.16,0.24,0.32,0.40,0.50,0.60,0.68,0.76,0.84,0.92,0.98]
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = CMTime(seconds: 0.12, preferredTimescale: 600)
generator.requestedTimeToleranceAfter = CMTime(seconds: 0.12, preferredTimescale: 600)
var samples: [Sample] = []
for fraction in fractions {
    let requested = max(0.0, min(seconds - 0.05, seconds * fraction))
    var actual = CMTime.zero
    let image = try generator.copyCGImage(at: CMTime(seconds: requested, preferredTimescale: 600), actualTime: &actual)
    samples.append(Sample(requestedSeconds: requested,
                          actualSeconds: CMTimeGetSeconds(actual),
                          averageHash256: averageHash256(image),
                          differenceHash64: differenceHash64(image)))
}
let report = Report(schemaVersion: 1, durationSeconds: seconds, width: width, height: height,
                    sampleCount: samples.count, samples: samples)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(report))
SWIFT

xcrun swift "$PROBE_SWIFT" "$VIDEO" > "$PROBE_JSON.tmp"
python3 - "$VIDEO" "$PROBE_JSON.tmp" "$PROBE_JSON" "$EXPECTED_SOURCE_SHA" <<'PY'
import hashlib,json,os,sys
video,probe_in,out,source_sha=sys.argv[1:]
h=hashlib.sha256()
with open(video,"rb") as f:
    for b in iter(lambda:f.read(8*1024*1024),b""):
        h.update(b)
probe=json.load(open(probe_in,encoding="utf-8"))
probe.update({
    "videoBytes": os.path.getsize(video),
    "videoSHA256": h.hexdigest(),
    "sourceSHA": source_sha,
    "rawPathsPersisted": False,
})
open(out,"w",encoding="utf-8").write(json.dumps(probe,ensure_ascii=False,indent=2)+"\n")
PY

python3 - "$RELAY" "$RUN_ID" "$TOKEN" "$PROBE_JSON" <<'PY'
import json,sys,urllib.request
relay,run_id,token,payload_file=sys.argv[1:]
payload=json.load(open(payload_file,encoding="utf-8"))
body=json.dumps({"kind":"probe","payload":payload},ensure_ascii=False,separators=(",",":")).encode()
req=urllib.request.Request(
    f"{relay.rstrip('/')}/evidence?run_id={run_id}", data=body, method="POST",
    headers={"Authorization":f"Bearer {token}","Content-Type":"application/json"},
)
with urllib.request.urlopen(req,timeout=60) as r:
    response=json.loads(r.read())
if not response.get("ok"):
    raise SystemExit("Probe relay did not acknowledge evidence")
PY

echo "GOLDEN_VIDEO_EQUIVALENCE_PROBE_EVIDENCE_RELAYED"
