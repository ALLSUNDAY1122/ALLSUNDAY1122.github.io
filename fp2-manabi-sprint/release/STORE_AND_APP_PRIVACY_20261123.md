# FP2 ストア資料｜現行スコープ注記（2026-11-24）

本ファイルの下段は2026-11-23時点の**ストア候補調査履歴**。現行の教材数は**正規310／公式逐語選抜298／独自予備12／FAIL2隔離／HOLD0**、公開許可0。App ID/Bundle ID/Version/Build/IAPやApple側App Privacyは**最新実測なしでは確定しない**。iOSプロジェクトが存在しない等の過去記述も現行実態の根拠にしない。最終判断は `RELEASE_STATUS.md` とQ0〜Q5最終ゲート正本に従う。

---

# FP2｜ストア掲載・App Privacy候補（2026-11-23）

## 対象実物・範囲
- GitHubリリースブランチ `feature/fp2-release-scope-20261123`
- `fp2-manabi-sprint/index.html` と `fp2-approved-bank.js` をソース検査。正規バンクは `questions/canonical/approved-questions-20261123.json`。
- Apple App ID: `6797228406`（プロジェクト既知のID、**ASCライブ照合は未実施**）。
- このリポジトリの `fp2-manabi-sprint/` にFP2専用iOSネイティブプロジェクト / StoreKit /署名ビルドは現時点のリポジトリ一覧で確認できない。Bundle ID / CFBundleShortVersionString / CFBundleVersion / IAP Product IDは**未確定**。別製品 `fp2-kakomon-coach/ios-app` を自動流用しない。
- App Review提出やASC書込みは一切行わない。

## WebソースからのApp Privacy暫定判断
| 種類 | Webコードでの実装 | 現段階のASC回答 |
|---|---|---|
| 学習記録・正誤・連続正解・目標・任意試験日 | `localStorage` 端末保存 | アプリ運営者によるオフデバイス収集はコード内未確認 |
| ユーザー操作のJSONバックアップ | ブラウザ内作成/読み込み。コード内にサーバ送信なし | データの外部送信なし（Web版に限る） |
| 学習問題JSON | 同一オリジンからfetch | リクエスト時のIP等をホスティングが収集・保持する可能性 |
| 分析/広告SDK、第三者トラッキング | Web HTML/adapterから未検出 | 現行Webソース上は「なし」、iOS配布ビルド未検証 |
| 課金/IAP、StoreKit | Web HTML/adapterでは未検出 | iOSプロジェクト未発見のため**未確認** |
| クラッシュ/診断 | Web画面にSDKなし | iOS/Apple診断・配信基盤の条件未確認 |
| 外部サイト | 公式過去問の出典URLへのユーザー操作リンク | 遷移先サイトのプライバシー条件は別 |

**結論：**「データの収集なし」は、配布する最終iOSバイナリ・ホスティング解析/ログ取扱・App Store Connectプライバシー回答の三者の実測まで**最終確定不可**。Webソースのみで誤ってYES確定しない。

## 公開前サポート・プライバシーURL
- ソース準備：`fp2-manabi-sprint/support.html`／`fp2-manabi-sprint/privacy.html`。
- 公開時URL候補：
  - `https://allsunday1122.github.io/fp2-manabi-sprint/support.html`
  - `https://allsunday1122.github.io/fp2-manabi-sprint/privacy.html`
- 現在Web外部到達テスト：**到達確認できず**。main/Pagesへ未公開のリリースブランチ上にだけ存在。**現時点でASC掲載用の到達可能URLとしては使用禁止**。

## ストア掲載文候補（App Review未提出）
- 表示名：`FP2級｜学びスプリント`
- サブタイトル：`公式問題の出典を確認して学ぶ`
- プロモーション文：`問題ごとに出典・加工有無・法令基準日を表示。正誤や学習履歴を振り返れるFP2級学習アプリです。`
- 説明：
「FP技能検定2級の学科対策を、出典が確認できる問題で進める学習アプリです。4肢択一の問題演習、解説と根拠の確認、学習記録、苦手復習、1日4/8/16問の目標設定、学習データのJSONバックアップに対応しています。過去問を利用・加工した設問は出典と加工内容を明示します。内容監査PASSはApp Store公開承認を意味しません。法令・制度の取扱いは表示の基準日をご確認ください。」
- キーワード候補：`FP2級,ファイナンシャルプランナー,学科,過去問,資格試験,金融,保険,年金,相続,税金`
- 注意：模試が公式60問の再現・満点保証と誤認させる文言、未実装のオフライン保証、未確定IAP価格を表示しない。

## 不足する配布証拠
1. 実際にASCで選ばれたFP2のBundle ID、Version、Build、IAPとApple上のApp Privacy設定。
2. FP2専用のiOSプロジェクト、署名・ipa生成、GitHub web bankと配布アプリ内bankのSHA一致。
3. 実機iPhoneの画面、UI Master v2.1の30状態、バックアップ復元、オフライン、クラッシュとリリース用スクリーンショット。
4. サポート／プライバシーの公開HTTP200、実運営者問い合わせ導線、ASC掲載内容の一致。
5. Appleの最終審査操作は必ずユーザー承認後に別工程。
