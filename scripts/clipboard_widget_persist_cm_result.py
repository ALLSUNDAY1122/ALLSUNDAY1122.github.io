import argparse
import io
import json
from pathlib import Path
import urllib.request
import zipfile


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--input', required=True)
    ap.add_argument('--output', required=True)
    ap.add_argument('--recover-diagnostics', action='store_true')
    args = ap.parse_args()

    src = Path(args.input)
    if not src.exists():
        print('no result file')
        return
    r = json.loads(src.read_text(encoding='utf-8'))
    keep = {k: r.get(k) for k in (
        'request_id','ok','workflow_id','branch','resolved_app_id','build_id',
        'status','app_id','error','build_details'
    )}
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(keep, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    if not args.recover_diagnostics:
        return
    arts = ((r.get('build_details') or {}).get('artifacts') or [])
    bundle = next((a for a in arts if a.get('type') == 'bundle' and a.get('short_lived_download_url')), None)
    if not bundle:
        print('no bundle artifact')
        return
    data = urllib.request.urlopen(bundle['short_lived_download_url'], timeout=60).read()
    zf = zipfile.ZipFile(io.BytesIO(data))
    wanted = {
        'clipboard-widget-asc-record-bootstrap.log',
        'clipboard-widget-produce-safe.log',
    }
    for name in zf.namelist():
        base = Path(name).name
        if base in wanted:
            (out.parent / base).write_bytes(zf.read(name))
            print('recovered', base)


if __name__ == '__main__':
    main()
