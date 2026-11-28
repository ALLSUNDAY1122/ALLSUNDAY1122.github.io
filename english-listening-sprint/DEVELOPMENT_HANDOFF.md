# 英語リスニング｜学びスプリント：開発引継ぎ資料

作成日: 2026-08-22 / 作成: Claude（本開発担当AI）
宛先: 次工程を担当するAI（ChatGPT web版 または Codex）

## 1. これは何か

「学びスプリント」ポートフォリオの英語リスニング学習アプリ。ChatGPTによるMVP企画・試作を経て、Claudeが本開発（データ拡充・UI改善・フリーミアム設計・音声生成・3回の辛口レビュー改善サイクル）を担当した。

## 2. 現在地（正直な進捗報告）

- ✅ Web版（HTML/CSS/JS単一ファイル）は完成し、動作確認済み（jsdomでの自動テスト135項目パス）
- ✅ 30レッスン分の教材（英文・和訳・設問・重要表現・短縮版）、312本の音声ファイル（Azure Neural TTS）
- ✅ フリーミアム設計（レッスン単位ロック、goTo()のロック回避バグ修正済み）
- ❌ **ネイティブアプリ化：未着手**
- ❌ **GitHub Actions / Codemagic / App Store Connect登録：未着手**
- ❌ **GitHubへのコードpushも権限不足でブロック中**（詳細はREADME参照。連携のContents write権限が必要）
- ❌ **TestFlight申請：未着手（前提のネイティブラッパーが存在しないため申請不可）**
- ❌ **Bundle ID・App Store Connect App ID：未発行**

「引継ぎ準備中」の段階であり、「TestFlight準備中」ではないことに注意してください。

## 3. 必ず確認してほしいこと：ネイティブ化の方針転換

他アプリ（例: touroku-hanbaisha）と同様に「HTML試作 → SwiftUI/WKWebViewラッパー → GitHub Actions → Codemagic → App Store Connect → TestFlight」という手順を想定していましたが、リポジトリ内の `docs/LEARNING_SPRINT_NATIVE_MASTER_2026-08-10.md`（ChatGPT作成、Codexへの正式引継ぎはまだ）によると：

> WKWebViewラッパーは「ネイティブアプリ」として認めず、SwiftUIによる本格的な書き直しが今後のrelease readinessの必須条件

とされています。**本アプリ（英語リスニング）はこのマスタードキュメントの追跡対象8アプリの一覧にまだ含まれていません。** つまり、そのままWKWebViewラッパーでTestFlightに出すことは、ポートフォリオの現行方針と矛盾します。

次工程の担当者は、以下のいずれかを確認・実施してください。
1. `LEARNING_SPRINT_NATIVE_MASTER_2026-08-10.md` を更新し、本アプリを追跡リストに追加した上で、SwiftUI版の設計に着手する
2. もしくは、方針側でこのアプリを例外扱い（WKWebViewラッパーで先行リリース可とする）ことをユーザー（森田氏）と正式に合意する

どちらにせよ、**ユーザーの明示確認なしにApp Store正式審査へ提出しないこと**（既存SOPの禁止事項）。

## 4. Bundle ID / Team ID（提案・未確定）

- Apple Team ID: `MN3D2ZM44N`（全アプリ共通、確定）
- 提案Bundle ID: `jp.allsunday1122.englishlistening`（`docs/APP_STORE_IDENTIFIERS_CANONICAL.md` の命名規則に準拠。**まだ登録・確定はしていません**）
- App Store Connect App ID: 未発行
- Codemagicプロファイル: 未設定
- IAP: 未設定（フリーミアムのプレミアム機能を課金化する場合は別途設計要）

## 5. 教材データの所在

- 本フォルダ `data/lessons-part{1,2,3}.json`: 教材本文・設問・重要表現・話者リスト（音声パス/SSML除く）
- 完全版（音声ファイル312本込み、SSML込みのlessons.json、index.html本体）: Google Driveに別途アップロード（共有リンクは森田氏に確認）、および森田氏のローカルPCに配布済みzip（`english-listening-mvp_v8.zip`）
- **index.htmlは教材データを`<script>`タグに直接埋め込んでいる**（file://での読み込み時に外部JSON参照が失敗する既知の問題への対処）。data/lessons.jsonを更新したら、必ずindex.html内の埋め込みJSONも手動で再同期すること

## 6. 開発の経緯（要約）

- v2〜v4: 初期MVP、地域別に異なる話題、比較機能の試験実装
- v5: 6テーマ×5地域を完全統一（同一英文・同一設問、話者と音声のみ地域差）、台本長さの意味を反転（標準を2倍化）、比較機能を本編に統合し独立モードは削除、312本音声を再生成
- v6: 3回の辛口レビュー改善サイクル（フリーミアムのロック回避バグ修正＋無料範囲をレッスン単位に、vocabフィールドの新設と重要表現パネル追加、長さトグルの語数・時間表示とデフォルト変更）

詳細は `docs/CLAUDE_V5_NOTES.md`、`docs/CLAUDE_V6_NOTES.md` を参照。

## 7. 次のアクション（推奨）

1. GitHub連携のContents write権限を有効化し、このフォルダの内容を`ALLSUNDAY1122/ALLSUNDAY1122.github.io`の`english-listening-sprint/`へpush
2. `LEARNING_SPRINT_NATIVE_MASTER_2026-08-10.md` の追跡リストに本アプリを追加するか、ユーザーと方針を確認
3. SwiftUIネイティブ版の設計（または例外合意後にWKWebViewラッパーの構築）
4. Bundle ID / App Store Connect App IDの正式発行
5. GitHub Actions → Codemagicパイプラインの設定
6. TestFlight内部テスト提出（App Store正式審査への提出は森田氏の最終承認後のみ）
