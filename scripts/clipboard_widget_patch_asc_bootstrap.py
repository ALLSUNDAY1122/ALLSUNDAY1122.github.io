from pathlib import Path

p = Path('codemagic.yaml')
s = p.read_text(encoding='utf-8')
marker = '\n  clipboard-widget-asc-record-bootstrap:\n'
if marker in s:
    print('bootstrap workflow already present')
    raise SystemExit(0)

block = r'''
  clipboard-widget-asc-record-bootstrap:
    name: Clipboard Widget - Create App Store Connect Record
    max_build_duration: 30
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: "Codemagic Shiwake Swipe"
    environment:
      groups:
        - app2_010_touhan_signing
      vars:
        BUNDLE_ID: jp.allsunday1122.clipboardwidget
        APP_NAME: クリップボードWidget
        APP_SKU: clipboard-widget-20260827
      xcode: latest
    scripts:
      - name: Create App Store Connect record with stored Apple web credentials
        script: |
          set -euo pipefail
          DIAG="$CM_BUILD_DIR/clipboard-widget-asc-record-bootstrap.log"
          : > "$DIAG"
          exec > >(tee -a "$DIAG") 2>&1
          echo 'STAGE credential-probe'
          USERNAME="${FASTLANE_USER:-${APPLE_ID:-${APP_STORE_CONNECT_USERNAME:-}}}"
          PASSWORD="${FASTLANE_PASSWORD:-${APPLE_ID_PASSWORD:-}}"
          SESSION="${FASTLANE_SESSION:-}"
          echo "has_username=$([[ -n \"$USERNAME\" ]] && echo true || echo false)"
          echo "has_password=$([[ -n \"$PASSWORD\" ]] && echo true || echo false)"
          echo "has_session=$([[ -n \"$SESSION\" ]] && echo true || echo false)"
          if [[ -z "$USERNAME" || ( -z "$PASSWORD" && -z "$SESSION" ) ]]; then
            echo 'BLOCKED: no stored Apple web-login credential/session usable by fastlane produce'
            exit 44
          fi
          echo 'STAGE fastlane'
          if ! command -v fastlane >/dev/null 2>&1; then
            gem install fastlane --no-document
          fi
          export FASTLANE_USER="$USERNAME"
          export FASTLANE_PASSWORD="$PASSWORD"
          export FASTLANE_SESSION="$SESSION"
          export FASTLANE_SKIP_UPDATE_CHECK=1
          export FASTLANE_HIDE_CHANGELOG=1
          export FASTLANE_DISABLE_COLORS=1
          RAW="$CM_BUILD_DIR/clipboard-widget-produce-raw.log"
          set +e
          fastlane produce \
            --username "$USERNAME" \
            --app_identifier "$BUNDLE_ID" \
            --app_name "$APP_NAME" \
            --sku "$APP_SKU" \
            --language 'ja-JP' \
            --platform ios \
            --skip_devcenter true \
            >"$RAW" 2>&1
          STATUS=$?
          set -e
          python3 - <<'PYSAN'
          from pathlib import Path
          import os,re
          src=Path(os.environ['CM_BUILD_DIR'])/'clipboard-widget-produce-raw.log'
          dst=Path(os.environ['CM_BUILD_DIR'])/'clipboard-widget-produce-safe.log'
          raw=src.read_text(errors='replace') if src.exists() else ''
          raw=re.sub(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '[REDACTED EMAIL]', raw)
          raw=re.sub(r'-----BEGIN [^-]+-----.*?-----END [^-]+-----', '[REDACTED PEM]', raw, flags=re.S)
          raw=re.sub(r'eyJ[A-Za-z0-9._-]{20,}', '[REDACTED JWT]', raw)
          raw=re.sub(r'(?i)(session|cookie|password|token)(\s*[=:]\s*)\S+', r'\1\2[REDACTED]', raw)
          dst.write_text(raw[-20000:])
          PYSAN
          cat "$CM_BUILD_DIR/clipboard-widget-produce-safe.log"
          rm -f "$RAW"
          exit "$STATUS"
    artifacts:
      - clipboard-widget-asc-record-bootstrap.log
      - clipboard-widget-produce-safe.log
'''

p.write_text(s.rstrip() + block + '\n', encoding='utf-8')
print('added clipboard-widget-asc-record-bootstrap workflow')
