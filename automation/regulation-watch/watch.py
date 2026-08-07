from __future__ import annotations

import difflib
import hashlib
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parent
SOURCES_FILE = ROOT / "sources.json"
STATE_FILE = ROOT / "state.json"
SNAPSHOT_DIR = ROOT / "snapshots"
CHANGE_DIR = ROOT / "changes"

USER_AGENT = (
    "Mozilla/5.0 (compatible; ManabiSprintRegulationWatch/1.0; "
    "+https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io)"
)
TIMEOUT = 30
MAX_DIFF_LINES = 140
MAX_ISSUE_BODY = 60000


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def normalize_html(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "noscript", "svg", "canvas"]):
        tag.decompose()

    # Remove common volatile page furniture where possible.
    for selector in [
        "header", "footer", "nav", ".breadcrumb", ".breadcrumbs", ".cookie",
        "#cookie", ".sns", ".social", ".share", ".advertisement", ".ads"
    ]:
        for node in soup.select(selector):
            node.decompose()

    text = soup.get_text("\n")
    lines = []
    for raw in text.splitlines():
        line = re.sub(r"\s+", " ", raw).strip()
        if not line:
            continue
        # Ignore obvious access counters / generated timestamps that create noise.
        if re.fullmatch(r"(?:アクセス|閲覧)[：:]?\s*[0-9,]+", line):
            continue
        lines.append(line)
    return "\n".join(lines).strip() + "\n"


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def fetch(url: str) -> str:
    response = requests.get(
        url,
        headers={"User-Agent": USER_AGENT, "Accept-Language": "ja,en;q=0.8"},
        timeout=TIMEOUT,
    )
    response.raise_for_status()
    response.encoding = response.apparent_encoding or response.encoding
    return normalize_html(response.text)


def unified_diff(old: str, new: str) -> str:
    diff = list(
        difflib.unified_diff(
            old.splitlines(),
            new.splitlines(),
            fromfile="previous",
            tofile="current",
            lineterm="",
            n=3,
        )
    )
    if len(diff) > MAX_DIFF_LINES:
        diff = diff[:MAX_DIFF_LINES] + ["... diff truncated ..."]
    return "\n".join(diff)


def github_issue(source: dict, diff_text: str, checked_at: str) -> None:
    token = os.getenv("GITHUB_TOKEN")
    repo = os.getenv("GITHUB_REPOSITORY")
    if not token or not repo:
        print("GITHUB_TOKEN/GITHUB_REPOSITORY unavailable; skipping issue creation")
        return

    qualifications = "、".join(source.get("qualifications", [])) or "未分類"
    topics = "、".join(source.get("topics", [])) or "未分類"
    title = f"[制度改定候補] {source['name']} に変更を検知"
    body = f"""## 学びスプリント 制度改定監視\n\n公式監視元の内容に前回確認時から変更がありました。**変更をそのまま法改正と断定せず、人間またはAIが公式一次資料を確認してください。**\n\n- 監視元: {source['name']}\n- URL: {source['url']}\n- 影響候補資格: {qualifications}\n- 監視論点: {topics}\n- 優先度: {source.get('priority', 'medium')}\n- 検知時刻(UTC): {checked_at}\n\n### 差分（自動抽出）\n\n```diff\n{diff_text}\n```\n\n### 対応手順\n\n1. 公式ページで変更内容・公布日・施行日・試験適用日を確認する。\n2. 実際に試験範囲へ影響するか判定する。\n3. 影響する場合は、問題ID・選択肢・正解・解説・基準日をまとめて抽出する。\n4. 修正後は別AIまたは別工程で一次資料との照合監査を行う。\n5. アプリへ反映したVersionと反映日を記録して本Issueを閉じる。\n\n> このIssueはGitHub Actionsによる自動検知です。ページレイアウト変更だけの場合は「影響なし」として閉じてください。\n"""
    body = body[:MAX_ISSUE_BODY]

    api = f"https://api.github.com/repos/{repo}/issues"
    response = requests.post(
        api,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        json={"title": title, "body": body},
        timeout=TIMEOUT,
    )
    response.raise_for_status()
    issue = response.json()
    print(f"Created issue #{issue['number']}: {issue['html_url']}")


def github_error_issue(source: dict, message: str, checked_at: str) -> None:
    token = os.getenv("GITHUB_TOKEN")
    repo = os.getenv("GITHUB_REPOSITORY")
    if not token or not repo:
        return
    title = f"[監視エラー] {source['name']} を3回連続で取得できません"
    body = (
        "学びスプリントの制度改定監視で3回連続の取得失敗を検知しました。\n\n"
        f"- 監視元: {source['name']}\n"
        f"- URL: {source['url']}\n"
        f"- 検知時刻(UTC): {checked_at}\n"
        f"- 最終エラー: `{message[:1500]}`\n\n"
        "URL変更・bot対策・サイト障害等を確認し、`sources.json` を修正してください。"
    )
    response = requests.post(
        f"https://api.github.com/repos/{repo}/issues",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        json={"title": title, "body": body},
        timeout=TIMEOUT,
    )
    response.raise_for_status()
    print(f"Created monitoring error issue: {response.json()['html_url']}")


def main() -> int:
    config = load_json(SOURCES_FILE, {"sources": []})
    state = load_json(STATE_FILE, {"version": 1, "sources": {}})
    state.setdefault("sources", {})
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    CHANGE_DIR.mkdir(parents=True, exist_ok=True)

    changed_count = 0
    error_count = 0

    for source in config.get("sources", []):
        source_id = source["id"]
        checked_at = now_iso()
        item_state = state["sources"].setdefault(source_id, {})
        snapshot_path = SNAPSHOT_DIR / f"{source_id}.txt"

        print(f"Checking {source['name']} ...")
        try:
            current = fetch(source["url"])
            current_hash = sha256(current)
            previous = snapshot_path.read_text(encoding="utf-8") if snapshot_path.exists() else None
            previous_hash = sha256(previous) if previous is not None else None

            item_state.update(
                {
                    "name": source["name"],
                    "url": source["url"],
                    "last_checked_at": checked_at,
                    "last_success_at": checked_at,
                    "last_hash": current_hash,
                    "consecutive_errors": 0,
                    "error_alerted": False,
                }
            )

            if previous is None:
                snapshot_path.write_text(current, encoding="utf-8")
                item_state["baseline_created_at"] = checked_at
                print("  baseline initialized")
            elif current_hash != previous_hash:
                diff_text = unified_diff(previous, current)
                snapshot_path.write_text(current, encoding="utf-8")
                stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                change_path = CHANGE_DIR / f"{stamp}_{source_id}.diff"
                change_path.write_text(diff_text + "\n", encoding="utf-8")
                item_state["last_change_at"] = checked_at
                item_state["last_change_file"] = str(change_path.relative_to(ROOT))
                github_issue(source, diff_text, checked_at)
                changed_count += 1
                print("  change detected")
            else:
                print("  no change")

        except Exception as exc:  # monitor should continue through other sources
            error_count += 1
            message = f"{type(exc).__name__}: {exc}"
            item_state["last_checked_at"] = checked_at
            item_state["last_error"] = message
            item_state["consecutive_errors"] = int(item_state.get("consecutive_errors", 0)) + 1
            print(f"  ERROR: {message}", file=sys.stderr)
            if item_state["consecutive_errors"] >= 3 and not item_state.get("error_alerted"):
                try:
                    github_error_issue(source, message, checked_at)
                    item_state["error_alerted"] = True
                except Exception as issue_exc:
                    print(f"  Failed to create error issue: {issue_exc}", file=sys.stderr)

        time.sleep(1)

    state["last_run_at"] = now_iso()
    state["last_run_changes"] = changed_count
    state["last_run_errors"] = error_count
    save_json(STATE_FILE, state)
    print(f"Done: {changed_count} changes, {error_count} errors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
