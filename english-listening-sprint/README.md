# 英語リスニング｜学びスプリント

「学びスプリント」ポートフォリオの1アプリ。同じ英文を5つの英語圏アクセント（Canada / Australia / United Kingdom / United States / India）で聞き比べながら学ぶ、バニラHTML/CSS/JSの単一ページ・リスニング教材アプリ。

## 現在の状態（2026-08-22時点）

- **Web試作（ChatGPT工程）→ 本開発（Claude工程）まで完了。ネイティブラッパー化は未着手。**
- 動作する参照実装は `index.html` 1ファイル（教材データを`<script>`に埋め込み済み、外部読み込みなし）
- 30レッスン（6テーマ × 5地域）、標準/短めの2尺、フリーミアム（各テーマ1問目は全地域無料、Canadaは全問無料）、重要表現パネル、312本の音声（Azure Neural TTS）
- **このフォルダにはコード・スクリプト・開発ノートのみを格納。音声ファイル（約312本、容量大）と完全な教材JSON（audio/ssmlフィールド込み）は本アプリを配布したzip、およびGoogle Driveに保存（別途共有）。**
- `data/`配下の`lessons-part{1,2,3}.json`は、教材の中身（英文・和訳・設問・語彙・短縮版テキスト・話者リスト）のみを含み、音声ファイルパス・SSMLは除外したトリム版。SSMLはvoicesの`azureVoice`名 + 本文から`scripts/generate_audio_azure.py`と同じテンプレートで再生成可能。

## 重要：GitHubへのpushが権限不足でブロック中

このフォルダの内容は、本来 `ALLSUNDAY1122/ALLSUNDAY1122.github.io` モノレポの `english-listening-sprint/` に配置する想定で準備した。しかし接続中のGitHub連携（integration）に書き込み権限がなく、`push_files`実行時に以下のエラーで失敗した。

```
403 Resource not accessible by integration
（POST .../git/trees）
```

新規リポジトリ作成（`create_repository`）でも同じ403が過去に発生しており、単発の問題ではなく連携全体の権限不足と判断。**GitHub Appの権限設定でこのリポジトリへの「Contents: Read and write」を有効にしてから、次のAIまたはユーザー自身が手動でpushする必要がある。**

## 重要：ネイティブアプリ化について

`docs/LEARNING_SPRINT_NATIVE_MASTER_2026-08-10.md`（ポートフォリオ共通のマスター方針、ChatGPT作成）により、**WKWebViewラッパーはもはや「ネイティブ」として認められず、SwiftUIによる本格的な書き直しが必須**とされています。本アプリはこのマスタードキュメントの追跡対象8アプリにまだ含まれていません。TestFlight申請・App Store Connect登録に着手する前に、必ず最新のマスタードキュメントを参照し、スコープを確認してください。

詳細は `DEVELOPMENT_HANDOFF.md` を参照。

## ディレクトリ構成

```
english-listening-sprint/
  README.md
  DEVELOPMENT_HANDOFF.md
  data/
    lessons-part1.json  (ca01-06, au01-04)
    lessons-part2.json  (au05-06, uk01-06, us01-02)
    lessons-part3.json  (us03-06, in01-06)
  scripts/
    generate_audio_azure.py
  docs/
    CLAUDE_V5_NOTES.md
    CLAUDE_V6_NOTES.md
```

※ v2〜v4の開発ノート、edge-tts版生成スクリプト、validate_lessons.py、CODEX_HANDOFF.mdなど、その他の開発資料は配布zip / Google Drive側に保存されています。GitHub権限が復旧し次第、追加コミットで補完してください。
