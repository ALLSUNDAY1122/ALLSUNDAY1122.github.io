#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER_DIR="$ROOT/scanner-parity/HQGoldenRunner"
MODE="${GOLDEN_MODE:-thresholdless}"
RUN_ID="${GOLDEN_RUN_ID:-}"
TOKEN="${GOLDEN_DOWNLOAD_TOKEN:-}"
RELAY="${GOLDEN_RELAY_URL:-}"
EXPECTED_SOURCE_SHA="${GOLDEN_EXPECTED_SOURCE_SHA:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Golden v3 Codemagic executor requires macOS." >&2
  exit 2
fi
if [[ -z "$RUN_ID" || -z "$TOKEN" || -z "$RELAY" || -z "$EXPECTED_SOURCE_SHA" ]]; then
  echo "Missing required Golden relay environment." >&2
  exit 2
fi
if [[ "$MODE" != "thresholdless" && "$MODE" != "thresholded" ]]; then
  echo "GOLDEN_MODE must be thresholdless or thresholded." >&2
  exit 2
fi

cd "$ROOT"
actual_source_sha="$(git rev-parse HEAD)"
if [[ "$actual_source_sha" != "$EXPECTED_SOURCE_SHA" ]]; then
  echo "Source SHA mismatch; refusing Golden execution." >&2
  exit 3
fi

WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/scanner-golden-v3.XXXXXX")"
RAW_DIR="$WORK_ROOT/raw"
WORKSPACE="$WORK_ROOT/workspace"
THRESHOLDLESS_WORKSPACE="$WORK_ROOT/thresholdless"
mkdir -p "$RAW_DIR" "$WORKSPACE" "$THRESHOLDLESS_WORKSPACE"
chmod 700 "$WORK_ROOT" "$RAW_DIR" "$WORKSPACE" "$THRESHOLDLESS_WORKSPACE"

cleanup_local() {
  rm -rf "$WORK_ROOT"
}
trap cleanup_local EXIT

MANIFEST="$WORK_ROOT/manifest.json"
VIDEO="$RAW_DIR/golden-v3-video.mp4"
PDF="$RAW_DIR/golden-v3-reference.pdf"

python3 - "$RELAY" "$RUN_ID" "$TOKEN" "$MANIFEST" <<'PY'
import json,sys,urllib.request
relay,run_id,token,out=sys.argv[1:]
url=f"{relay.rstrip('/')}/manifest?run_id={run_id}"
req=urllib.request.Request(url,headers={"Authorization":f"Bearer {token}","Accept":"application/json"})
try:
    with urllib.request.urlopen(req,timeout=60) as r:
        data=r.read()
except Exception as exc:
    raise SystemExit(f"Golden relay manifest request failed: {type(exc).__name__}")
obj=json.loads(data)
open(out,"wb").write(json.dumps(obj,ensure_ascii=False,indent=2).encode())
PY

python3 - "$MANIFEST" "$VIDEO" "$PDF" "$RELAY" "$RUN_ID" "$TOKEN" <<'PY'
import hashlib,json,os,sys,urllib.request
manifest_path,video_path,pdf_path,relay,run_id,token=sys.argv[1:]
m=json.load(open(manifest_path,encoding="utf-8"))

EXPECTED={
    "video": (int(m["expected_video_bytes"]), str(m["expected_video_sha256"]).lower(), video_path),
    "pdf": (int(m["expected_pdf_bytes"]), str(m["expected_pdf_sha256"]).lower(), pdf_path),
}

def download_url(url,path):
    req=urllib.request.Request(url,headers={"User-Agent":"scanner-parity-golden-v3/1"})
    try:
        with urllib.request.urlopen(req,timeout=300) as r, open(path,"wb") as f:
            while True:
                b=r.read(1024*1024)
                if not b: break
                f.write(b)
    except Exception as exc:
        raise SystemExit(f"External Golden source download failed: {type(exc).__name__}")

def download_chunks(kind,path):
    chunks=(m.get("chunks") or {}).get(kind) or []
    if not chunks:
        raise SystemExit(f"No source URL or relay chunks available for {kind}")
    with open(path,"wb") as out:
        for item in chunks:
            idx=int(item["index"])
            url=f"{relay.rstrip('/')}/chunk?run_id={run_id}&kind={kind}&index={idx}"
            req=urllib.request.Request(url,headers={"Authorization":f"Bearer {token}"})
            try:
                with urllib.request.urlopen(req,timeout=180) as r:
                    data=r.read()
            except Exception as exc:
                raise SystemExit(f"Relay chunk download failed for {kind}:{idx}: {type(exc).__name__}")
            if len(data)!=int(item["size"]):
                raise SystemExit(f"Relay chunk size mismatch for {kind}:{idx}")
            if hashlib.sha256(data).hexdigest()!=str(item["sha256"]).lower():
                raise SystemExit(f"Relay chunk SHA mismatch for {kind}:{idx}")
            out.write(data)

sources=m.get("source_urls") or {}
for kind in ("video","pdf"):
    size,sha,path=EXPECTED[kind]
    source=sources.get(kind)
    if source:
        download_url(source,path)
    else:
        download_chunks(kind,path)
    st=os.stat(path)
    if st.st_size!=size:
        raise SystemExit(f"{kind} byte-count mismatch")
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for b in iter(lambda:f.read(8*1024*1024),b""):
            h.update(b)
    if h.hexdigest()!=sha:
        raise SystemExit(f"{kind} SHA-256 mismatch")
print("GOLDEN_V3_EXTERNAL_SOURCE_IDENTITY_PASS")
PY

post_json() {
  local kind="$1"
  local payload_file="$2"
  python3 - "$RELAY" "$RUN_ID" "$TOKEN" "$kind" "$payload_file" <<'PY'
import json,sys,urllib.request
relay,run_id,token,kind,payload_file=sys.argv[1:]
payload=json.load(open(payload_file,encoding="utf-8"))
body=json.dumps({"kind":kind,"payload":payload},ensure_ascii=False,separators=(",",":")).encode()
url=f"{relay.rstrip('/')}/evidence?run_id={run_id}"
req=urllib.request.Request(url,data=body,method="POST",headers={"Authorization":f"Bearer {token}","Content-Type":"application/json"})
try:
    with urllib.request.urlopen(req,timeout=60) as r:
        response=json.loads(r.read())
except Exception as exc:
    raise SystemExit(f"Golden evidence relay failed: {type(exc).__name__}")
if not response.get("ok"):
    raise SystemExit("Golden evidence relay did not acknowledge payload")
PY
}

post_simple_failure() {
  local stage="$1"
  local code="$2"
  local f="$WORK_ROOT/failure.json"
  python3 - "$stage" "$code" "$EXPECTED_SOURCE_SHA" > "$f" <<'PY'
import json,sys
stage,code,sha=sys.argv[1:]
print(json.dumps({"stage":stage,"exitCode":int(code),"sourceSHA":sha,"rawPathsPersisted":False},separators=(",",":")))
PY
  post_json failure "$f" || true
}

if [[ "$MODE" == "thresholdless" ]]; then
  set +e
  bash "$RUNNER_DIR/run-formal-golden-v3-thresholdless-and-calibrate.sh" \
    --video "$VIDEO" \
    --pdf "$PDF" \
    --workspace "$WORKSPACE"
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    if [[ -f "$WORKSPACE/hq-golden-execution-failure.json" ]]; then
      post_json failure "$WORKSPACE/hq-golden-execution-failure.json" || true
    else
      post_simple_failure thresholdless "$rc"
    fi
    exit "$rc"
  fi

  execution="$WORKSPACE/hq-golden-execution.json"
  calibration="$WORKSPACE/hq-golden-calibration-evidence.json"
  test -f "$execution" && test -f "$calibration"
  bundle="$WORK_ROOT/thresholdless-evidence.json"
  python3 - "$execution" "$calibration" > "$bundle" <<'PY'
import json,sys
execution=json.load(open(sys.argv[1],encoding="utf-8"))
calibration=json.load(open(sys.argv[2],encoding="utf-8"))
print(json.dumps({"execution":execution,"calibration":calibration},ensure_ascii=False,separators=(",",":")))
PY
  post_json thresholdless "$bundle"
  echo "GOLDEN_V3_THRESHOLDLESS_EVIDENCE_RELAYED"
  exit 0
fi

# thresholded mode: reconstruct the SHA-bound thresholdless workspace and decision
python3 - "$RELAY" "$RUN_ID" "$TOKEN" "$THRESHOLDLESS_WORKSPACE" <<'PY'
import json,os,sys,urllib.request
relay,run_id,token,out=sys.argv[1:]
def get(path):
    req=urllib.request.Request(f"{relay.rstrip('/')}/{path}?run_id={run_id}",headers={"Authorization":f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req,timeout=60) as r:
            return json.loads(r.read())
    except Exception as exc:
        raise SystemExit(f"Golden relay prerequisite request failed: {type(exc).__name__}")
ev=get("thresholdless-evidence")
decision=get("decision")
os.makedirs(out,exist_ok=True)
open(os.path.join(out,"hq-golden-execution.json"),"w",encoding="utf-8").write(json.dumps(ev["execution"],ensure_ascii=False,indent=2))
open(os.path.join(out,"hq-golden-calibration-evidence.json"),"w",encoding="utf-8").write(json.dumps(ev["calibration"],ensure_ascii=False,indent=2))
open(os.path.join(out,"hq-golden-threshold-decision.json"),"w",encoding="utf-8").write(json.dumps(decision,ensure_ascii=False,indent=2))
PY

set +e
bash "$RUNNER_DIR/run-formal-golden-v3-from-threshold-decision.sh" \
  --video "$VIDEO" \
  --pdf "$PDF" \
  --thresholdless-workspace "$THRESHOLDLESS_WORKSPACE" \
  --decision "$THRESHOLDLESS_WORKSPACE/hq-golden-threshold-decision.json" \
  --workspace "$WORKSPACE"
rc=$?
set -e

if [[ -f "$WORKSPACE/hq-golden-execution.json" ]]; then
  post_json machine "$WORKSPACE/hq-golden-execution.json" || true
elif [[ -f "$WORKSPACE/hq-golden-execution-failure.json" ]]; then
  post_json failure "$WORKSPACE/hq-golden-execution-failure.json" || true
else
  post_simple_failure thresholded "$rc"
fi
exit "$rc"
