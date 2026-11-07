# Excalidraw: Service DNA → New Venture Frontier

STATUS: REA_RUN_PARTIAL

指定の公開CLIによる初回解析は実行済み、終了コード0。解析の網羅性はpartial。保存先はユーザー指定により ALLSUNDAY1122/ALLSUNDAY1122.github.io に変更した。「初回」はこのセッションで保存した初回実行を指し、過去の全環境に実行歴がないことは証明しない。

## 真髄の一文（推論）

このサービスの核は、手描きの表現・端末内のデータ保持・共同編集時の競合調停・可搬な図面を組み合わせ、曖昧な考えをすぐ共有・修正できる共通の作業面にする技術DNAである。

## 実測・観察

- 実行: `npx -y rea-agents@latest analyze-javascript-application /tmp/targets/excalidraw --json`、2026-10-20 14:03:54 UTC開始、66.411秒、終了コード0。REA 6.7.0、analyzer provider version 1。
- 対象: https://github.com/excalidraw/excalidraw 、commit `bee01e3a12812c930109aa91242658709480bbf3`、depth 1、MIT。対象の依存関係インストール・ビルド・起動は行っていない。
- Evidence ID: `ev_199ebd1a37a6245ebeb7125433a10b22aa77677b2e30f681c374d8eb64bdee36`。
- REA subject SHA-256: `30ca66940f6d1524867f109ed42afc3031e4b95e407bc241b685555830d27988`。これはREA定義のartifact digestであり、Git commit SHAとは別。
- `raw.json#/normalized_result/statistics`: relevant_files=811、parsed_javascript_files=714、text_bytes_read=10,509,113、visited_ast_nodes=856,926、parse_failures=3。
- graph.nodes=3,682、graph.edges=4,197、integrity_contradictions=[]。矛盾が空でも完全性の証明にはならない。
- `raw.json#/normalized_result/graph/coverage/status` は `partial`。limitationsは1,212件。親のresult budget不足、semantic result budget=0により未展開の関係がある。parse_failuresの原因・ファイル別内訳は本レポートでは確定していない。
- setupは最初にネットワーク制限で失敗。権限変更後の再試行ではclone先のローカルbinが未ビルドで失敗したため、`/tmp`から公開版を実行して成功した。setupのplannedActions/appliedActionsは空。設定適用・MCP登録完了とは表現しない。
- doctorは終了コード1。ネイティブエンジン、skill、Codex登録が未設定。対象を指定する回避策のdoctorも1。その一方で、外部エンジンなしのJavaScript静的解析は成功した。
- raw.jsonはstdoutそのもの（124,851,778 bytes）。SHA-256は `196e9343786784b0e624b2fd6d3eac5783bfd4152ec23928afdfe7c79c667ea9`。`raw_result: null` はREA envelope内の値であり、出力がなかったという意味ではない。

## 技術DNA（コードで観察した事実と推論を分離）

全リンクは上記commitに固定。REA参照は [evidence-index.json](evidence-index.json) のJSON Pointerで原本へ辿れる。コードの該当行は [source-excerpts.md](source-excerpts.md) にも保存。REAは静的な構文・ファイルの根拠を提供し、以下の具体的なアルゴリズム説明はコードを直接読んで補足したもの。

| DNA | 観察した事実・根拠 | 価値に関する推論 |
|---|---|---|
| 再現可能な手描き表現とキャッシュ | [shape.ts L83](https://github.com/excalidraw/excalidraw/blob/bee01e3a12812c930109aa91242658709480bbf3/packages/element/src/shape.ts#L83)〜165: RoughGenerator、WeakMap、themeを考慮した再利用、export時の再生成。L201: element.seed。REA file observation: nodes/1349/observations/1。 | ラフな表現の一貫性と再描画の負担軽減を両立する設計。操作速度や利用者の心理効果は未測定。 |
| 要素単位の競合調停 | [reconcile.ts L23](https://github.com/excalidraw/excalidraw/blob/bee01e3a12812c930109aa91242658709480bbf3/packages/excalidraw/data/reconcile.ts#L23)〜115: 編集中の要素保護、version比較、同versionではversionNonceによる決定、fractional index順序。REA nodes/1362/observations/0。 | 複数人の図面更新を共通の表現で扱える。収束性・全競合ケース・CRDTとしての性質は実証していない。 |
| クライアント側暗号化の送信経路 | [encryption.ts L50](https://github.com/excalidraw/excalidraw/blob/bee01e3a12812c930109aa91242658709480bbf3/packages/excalidraw/data/encryption.ts#L50)〜94: Web Crypto AES-GCMとIV。[Portal.tsx L85](https://github.com/excalidraw/excalidraw/blob/bee01e3a12812c930109aa91242658709480bbf3/excalidraw-app/collab/Portal.tsx#L85)〜103: roomKeyで暗号化してsocketへ送信。encryptionのREA nodes/3209/observations/1、Portalはコード補足。 | 共有時の内容保護を差別化要素にできる可能性。鍵配布・サーバー・運用を含む安全性の監査は未実施。 |
| 端末内保存を中心にした編集状態 | [LocalData.ts L73](https://github.com/excalidraw/excalidraw/blob/bee01e3a12812c930109aa91242658709480bbf3/excalidraw-app/data/LocalData.ts#L73)〜150: 要素とappStateのlocalStorage保存、quota例外、debounceした保存とfiles保存。REA nodes/428/observations/0・1にsetItemのobserved根拠。 | アカウントやネットワークに依存する場面を減らせる設計。ただし完全オフライン動作・永続性は未検証。 |
| 図を編集可能なデータとして運べる | [json.ts L52](https://github.com/excalidraw/excalidraw/blob/bee01e3a12812c930109aa91242658709480bbf3/packages/excalidraw/data/json.ts#L52)〜78: type/version/elements/appState/filesのJSON。[export.ts L1038](https://github.com/excalidraw/excalidraw/blob/bee01e3a12812c930109aa91242658709480bbf3/packages/excalidraw/scene/export.ts#L1038)〜1050: SVGへのシーンデータ埋め込み。REA nodes/1770/observations/0、nodes/1631/observations/0。 | 共有した画像から編集可能な成果物へ戻る導線を作れる可能性。読み戻しの往復試験は未実施。 |

## 推論と未確認事項

価値の中心は技術と編集データの可搬性という仮説。利用者が増えるほど参加者の習熟・共有機会が増える可能性はあるが、ネットワーク効果、流通優位、継続率、売上、顧客獲得費用を示す証拠は取得していない。独自データが競争優位かも不明。REAのElectron向けsummaryに0が並ぶことを、ブラウザー機能が存在しない証拠にはしない。対象の実コードは実行しておらず、性能・UX・暗号化の安全性を実測したとは言わない。

## 別市場への移植先（すべて仮説）

1. 設備保全・現場引継ぎ: 写真上のラフ図と端末内保存を用い、通信が不安定な現場の説明を残す。
2. 教育・少人数指導: 図解、共同修正、編集可能な持ち帰り教材へ移植する。
3. 製造業の機密設計レビュー: 暗号化された共有と競合調停を社内のレビュー用作業面に移植する。機密用途には別途鍵管理・権限・監査が必要。

## 新サービス案（未検証の収益仮説）

| 案 | 課題 | 価値 | 最小構成 | 収益仮説 | 検証実験 |
|---|---|---|---|---|---|
| 現場スケッチ引継ぎ帳 | 写真と口頭説明だけでは作業箇所・理由が伝わらない | 写真への図示と変更履歴を一つの編集可能な帳票にする | 画像背景、矢印・手描き、端末保存、JSON/SVG出力。自動同期は初期対象外 | チーム月額。履歴保持と帳票テンプレートへ課金 | 許諾を得た3現場・各5件で既存引継ぎと比較。確認質問数・作成時間・有料継続意向を測り、質問数30%減を暫定合格条件にする |
| 図解チュータールーム | 遠隔指導では学習者の途中思考が見えにくい | 同じ図を双方が修正し、そのまま教材として持ち帰れる | 2人共同編集、消し戻し、授業別保存、編集可能な出力 | 講師席の月額と教室契約 | 許諾を得た講師5人で各2授業。既存方法と課題修正までの時間・翌週再利用を比較。半数以上の講師が再利用し、2人以上が有料試用を選ぶか確認 |
| 機密レビューキャンバス | 早期設計案を共有する際の流出懸念と資料修正の摩擦 | 暗号化した作業面で論点を図に直接残す | 自社管理の共有基盤、room単位の鍵管理、招待失効、図の履歴、JSON出力。安全性レビューを公開前ゲートにする | 組織年額、専用配置・監査機能の追加料金 | 自社所有の架空設計データで3チームの試作評価。レビュー完了時間と残論点数を比較し、2社の有償PoC意向と鍵失効要件の充足を確認 |

MITコードを再利用する場合は著作権表示・ライセンスを保持する。商標や公式サービスとの関係は別に扱う。上記の実験は提案のみで、実施していない。

## 保存・公開状態

保存先: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io 、ブランチ `research/rea-first-run`。mainへの直接pushは行わない。

元の morluto/rea へのfork作成拒否（HTTP 403）は初回作業の履歴として publication.log に保持する。今回はユーザー指定の新しい保存先でpush権限を確認した。

原本は `raw.json.gz`（23,576,915 bytes、50MB未満）で保存し、未圧縮raw.jsonはGitに含めない。圧縮版を展開すると元のstdoutと同一のraw.jsonになることをSHA-256で確認した。要約は [raw-summary.json](raw-summary.json)、詳しい根拠索引は [evidence-index.json](evidence-index.json)。本文中の `raw.json#/...` は展開後のJSON Pointerを意味する。

```bash
gzip -dc raw.json.gz > /tmp/excalidraw-rea-raw.json
sha256sum /tmp/excalidraw-rea-raw.json
# 196e9343786784b0e624b2fd6d3eac5783bfd4152ec23928afdfe7c79c667ea9
```

## 次回の毎時GitHub Actions実行

[hourly-workflow.yml.example](hourly-workflow.yml.example) は未実行の提案。default branchに `.github/workflows/rea-hourly.yml` として配置すれば毎時17分UTCの起動を要求できるが、GitHub scheduleの遅延・スキップはあり得る。初回はworkflow_dispatchで検証する。書き込み可能なリポジトリ、Actions利用枠、npm/GitHubへの通信が必要。静的解析にAPIキーは不要。NodeとREAを固定し、対象commit・REAの版・終了コード・実行時間を毎回記録する。

doctorの失敗を保存しつつ解析を試し、解析自体の失敗はjob failureとする。毎回coverageとparse_failuresを別判定すること。完全な意味解析が必要なら対象をサブパスへ分けた追加runを設計し、原runと混同しない。生出力はGitコミットではなくartifactに保持し、保存期間と容量予算を設定する。PR自動作成まで行う場合のみ追加のcontents/pull-requests書き込み権限とレビュー方針を決める。
