# 保健師国家試験｜市場・権利・要件調査

調査日: 2026-08-12 JST

## 1. 市場性

厚生労働省の合格発表による直近3回の受験者数は以下。

| 回 | 実施年 | 受験者数 | 合格者数 | 合格率 |
|---|---:|---:|---:|---:|
| 第112回 | 2026 | 7,467 | 6,502 | 87.1% |
| 第111回 | 2025 | 7,658 | 7,196 | 94.0% |
| 第110回 | 2024 | 7,795 | 7,456 | 95.7% |

直近3年は毎年約7,500〜7,800人が受験している。看護師国試より市場は小さいが、資格試験として毎年更新される明確なコア需要がある。売上・有料転換率は一次資料から確定できないため推測しない。

## 2. 競合確認

2026-08-12時点の日本App Storeで、少なくとも以下の競合を確認した。

- 保健師国試400問
- 保健師-試験対策-国家資格
- 国試〜ぷ｜看護師・助産師・保健師国家試験過去問対策学習アプリ
- 保健師＜対策シリーズ＞

競合は過去問量、弱点復習、記録、模試、AI等を既に訴求している。したがって「過去問が解ける」だけでは差別化にならない。

本アプリの差別化軸は次とする。

1. 1回8問の短時間周回を中心にした学習習慣設計
2. `わからない` を正式回答として扱う
3. 誤答・わからないを自動で苦手化し、3連続正解で解除
4. 出題基準10分類への明示的マッピング
5. `ここだけ覚える` を含む短く独自の解説
6. 完全オフライン・ログイン不要を初期標準とする
7. 各問題に一次根拠・確認日・法令基準日・権利根拠を保持する
8. Golden Master v2.1の固定UIでシリーズ品質を統一する

## 3. 公式試験構成

第112回公式問題冊子は午前55問、午後55問で合計110問。合格発表では一般問題75点満点、状況設定問題70点満点（状況設定は1問2点）とされているため、最新回の採点対象構成は一般75問・状況設定35問として扱える。

回答形式は公式冊子の注意事項から、4〜5択の単一選択、2つ選択、計算問題の形式を想定する。実装では LearningSprintCore の `singleChoice` / `multiChoice` / `numeric` を利用可能とする。

## 4. 出題範囲

現行の厚生労働省「保健師国家試験出題基準 令和5年版」を正本とし、以下の10分類を分野別演習のトップレベル分類とする。

1. 公衆衛生看護学概論
2. 公衆衛生看護方法論I（個人・家族・グループへの支援）
3. 公衆衛生看護方法論II（地域組織・地域への支援、事業化と施策化）
4. 対象別公衆衛生看護活動論
5. 学校保健・産業保健
6. 健康危機管理
7. 公衆衛生看護管理論
8. 疫学
9. 保健統計
10. 保健医療福祉行政論

出題基準の改訂、法令・制度・統計の更新を検知した場合は制度改定ループを再発火する。

## 5. 著作権・利用条件

厚生労働省サイトは、特記または別の権利表記がないコンテンツについて公共データ利用規約（PDL1.0）に基づく利用を認めている。PDL1.0は条件に従った複製・公衆送信・翻訳・翻案と商用利用を認める一方、出典表示、加工表示、第三者権利の個別確認を要求する。

したがって「厚労省サイトに掲載されているため全問題を無条件に転載可能」とは扱わない。特に写真、図表、引用文、第三者作成資料、人物・施設画像などは問題単位で第三者権利を監査する。

### 採用方針

- 主軸: 法令、厚労省資料、出題基準、公的統計、公的ガイドライン等の一次資料から独自作問する。
- 公式過去問: 出題傾向・難度・論点設計の参照元として使用する。
- 公式問題本文を直接収録する場合: 当該問題ごとに権利表記・第三者素材を確認し、出典を付ける。
- 公式問題を編集・加工する場合: 出典に加え、加工したことと加工主体を明記する。
- 第三者権利が不明な写真・図表・引用素材: 収録しない。必要なら独自図版へ置換する。
- 問題本文、正解、解説、根拠のいずれかを変更した場合: 問題生成・監査ループを再実行する。

## 6. 問題バンク設計

学びスプリント共通の3回分監査ルールに合わせ、初期製品の作問目標を「独自模試3回 x 110問 = 330問」とする。これは公式問題数の主張ではなく、本アプリの製品設計上の作問枠である。

各問題は最低限次を保持する。

- id
- examRound（独自模試1〜3）
- subject（上記10分類）
- topic
- answerType
- prompt
- choices / correctIndices または数値正解
- explanation
- memoryPoint
- sourceTitle
- sourceURL / sourceRefs
- sourceCheckedAt
- lawBaselineDate
- contentVersion
- rightsBasis
- originType

330問は全て独立論点または実質的に異なる適用判断とし、言い換え・選択肢順変更・数値差し替えによる水増しを禁止する。

## 7. UI / Native要件

最上位は「学びスプリント UI要件定義 v2.1」。v1.0指定は、資格固有要件を保ちつつv2.1の固定UIへ上位互換として読み替える。

必須:

- SwiftUI native。WKWebView / WebKit を主UIにしない
- ホーム / 問題 / 結果 / 模試 / 記録 / 設定
- 下部4タブ: ホーム / 模試 / 記録 / 設定
- 標準8問、目標4 / 8 / 16
- 生成り紙 + 藍 + 朱 + 緑 + 金
- 問題文・主要教材表現は明朝、操作系はゴシック
- 82pt相当の進捗リング
- 正誤演出、ここだけ覚える
- 分野別演習
- 苦手復習
- 途中再開
- 35日ヒートマップ
- 試験日と必要ペース
- JSONバックアップ / 復元
- 完全オフライン
- VoiceOver / Dynamic Type / 44pt以上のタップ領域 / portrait
- StoreKit 2（Product ID確定後）

## 8. 受入条件

### Foundation Gate

- NativePackage `swift test` PASS
- `WKWebView` / `import WebKit` / `UIViewRepresentable` 0件
- 最新試験構成テスト PASS（55 + 55 = 110）
- 出題基準10分類テスト PASS
- 第三者権利未処理コンテンツが `blocked` 判定になること

### Content Gate

- 330問ちょうど
- 模試1〜3が各110問
- ID重複0
- 独自問題の本文完全一致0
- 高類似・人工的水増し0
- 正答不整合0
- 解説欠損0
- 一次根拠欠損0
- 基準日欠損0
- 権利根拠欠損0
- 医療・制度・統計の一次資料監査 PASS

### Product Gate

- 全主要画面がNative SwiftUI
- 単体/UIテスト PASS
- 小型/大型iPhoneの2サイズ以上で重大UI不具合0
- StoreKit 2の購入・復元・pending・cancel・unverified・revokedを確認
- オフラインで主要学習機能が完結
- JSONバックアップ往復テスト PASS
- 辛口レビュー改善3回完了、重大指摘0

### Release Gate

- Bundle ID / ASC App ID / IAP Product ID / Codemagic profile は正本値のみ
- Privacy / App Store原稿 / 実装の整合 PASS
- signed IPA
- Internal TestFlight
- App Store本審査はユーザー承認まで停止

## 9. 現在のブロッカー / 確認待ち

正本 `docs/APP_STORE_IDENTIFIERS_CANONICAL.md` に開発連番 #13 が未登録のため、以下は要確認。

- Bundle ID
- App Store Connect App ID
- IAP Product ID
- Codemagic profile
- 課金方式と価格

これらがなくても、問題設計・独自問題作成・Native Swift Package・静的監査までは継続する。

## 10. 一次資料・競合証跡

- 厚生労働省 第112回保健師国家試験 午前問題: https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp260424-03a_01.pdf
- 厚生労働省 第112回保健師国家試験 午後問題: https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp260424-03b_01.pdf
- 厚生労働省 第112回合格発表: https://www.mhlw.go.jp/general/sikaku/successlist/2026/siken03_04_05/about.html
- 厚生労働省 第111回合格発表: https://www.mhlw.go.jp/general/sikaku/successlist/2025/siken03_04_05/about.html
- 厚生労働省 第110回合格発表: https://www.mhlw.go.jp/general/sikaku/successlist/2024/siken03_04_05/about.html
- 保健師国家試験出題基準 令和5年版: https://www.mhlw.go.jp/content/10803000/000958455.pdf
- 厚生労働省 利用規約・著作権: https://www.mhlw.go.jp/chosakuken/index.html
- デジタル庁 PDL1.0: https://www.digital.go.jp/resources/open_data/public_data_license_v1.0
- App Store 保健師国試400問: https://apps.apple.com/jp/app/id1059618516
- App Store 保健師-試験対策-国家資格: https://apps.apple.com/jp/app/id6757066344
- App Store 国試〜ぷ: https://apps.apple.com/jp/app/id6753952586
- App Store 保健師＜対策シリーズ＞: https://apps.apple.com/jp/app/id1624168129
