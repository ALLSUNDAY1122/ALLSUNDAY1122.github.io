#!/usr/bin/env bash
set -Eeuo pipefail

SYNC_BRANCH="coord/central-b-main-sync-final-20260725"
ROOT="jichitai-compare"
ISSUE_NUMBER="$(jq -r '.issue.number // 0' "$GITHUB_EVENT_PATH")"
COMMENT_BODY="$(jq -r '.comment.body // ""' "$GITHUB_EVENT_PATH")"

if [[ "$ISSUE_NUMBER" != "3131" || "$COMMENT_BODY" != *"/run-central-b-main-sync"* ]]; then
  echo "Issue command does not match Central B synchronization; exiting."
  exit 0
fi

report_failure() {
  local line="$1"
  local status="$2"
  gh issue comment 3131 --repo "$GITHUB_REPOSITORY" --body "中日本B全国同期runnerが行${line}で失敗しました（exit ${status}）。Actionsログを確認してください。" || true
}
trap 'report_failure "$LINENO" "$?"' ERR

# Always build from the latest main branch containing this temporary runner.
git fetch origin main region/central
git checkout -B "$SYNC_BRANCH" origin/main
# Push an immediate checkpoint so runner start is externally observable.
git push --force-with-lease origin "HEAD:$SYNC_BRANCH"
gh issue comment 3131 --repo "$GITHUB_REPOSITORY" --body "中日本B全国同期runnerを開始しました。作業ブランチ: \`$SYNC_BRANCH\`"

python3 "$ROOT/scripts/sync-central-b-audit-to-main.py"

(
  cd "$ROOT"
  npm run generate
  npm run progress
  npm run validate:generated
)

# The final synchronization PR must not retain temporary runner files.
cp "$ROOT/scripts/jichitai-compare.original.yml" .github/workflows/jichitai-compare.yml
rm "$ROOT/scripts/jichitai-compare.original.yml"
rm "$ROOT/scripts/sync-central-b-audit-to-main.py"
rm "$ROOT/scripts/run-central-b-main-sync.sh"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
git diff --cached --quiet && { echo "No synchronization changes found"; exit 1; }
git commit -m "全国品質同期: 中日本B監査訂正57件をmainへ反映"
git push --force-with-lease origin "HEAD:$SYNC_BRANCH"

PR_URL="$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$SYNC_BRANCH" --base main --state open --json url --jq '.[0].url // empty')"
if [[ -z "$PR_URL" ]]; then
  PR_URL="$(gh pr create \
    --repo "$GITHUB_REPOSITORY" \
    --base main \
    --head "$SYNC_BRANCH" \
    --title "全国品質同期: 中日本B監査訂正57件をmainへ反映" \
    --body $'Issue #3131対応。\n\n中日本Bの10回監査で確定した57制度を、最新mainを基準にregion/centralからサービス単位で同期します。全国生成データ・静的ページ・進捗を再生成し、validate:generated成功済みです。\n\nCloses #3131')"
fi
PR_NUMBER="${PR_URL##*/}"

python3 - "$PR_NUMBER" <<'PY'
import json
import sys
from pathlib import Path

root = Path("jichitai-compare")
pr_number = int(sys.argv[1])
report_path = root / "operations/audits/central-b-main-sync-20260725.json"
report = json.loads(report_path.read_text(encoding="utf-8"))
report["synchronizationPullRequest"] = pr_number
report_path.write_text(json.dumps(report, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
for code in report["municipalityCodes"]:
    task_path = root / "operations/tasks" / f"{code}.json"
    if not task_path.exists():
        continue
    task = json.loads(task_path.read_text(encoding="utf-8"))
    task["pullRequestNumber"] = pr_number
    task_path.write_text(json.dumps(task, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
PY

git add "$ROOT/operations/audits/central-b-main-sync-20260725.json" "$ROOT/operations/tasks"
git commit -m "ops: 中日本B全国同期PR番号を記録"
git push origin "HEAD:$SYNC_BRANCH"
gh issue comment 3131 --repo "$GITHUB_REPOSITORY" --body "中日本B監査訂正57件の同期PRを作成しました: $PR_URL"
trap - ERR
