# HM2 Q0 コーディネーター再統合：40+69+69・権利90件の経過（2026-11-22 JST）

配布JSON Git blob: `72888a617ff17bf84b25e9d5a61f5cdec0d7493d`。各分割資料の更新は並列進行中であり、以下のblob SHAは本統合時のスナップショット。

| 分割 | Git blob SHA | 論理件数 | 実質進捗（記録に基づく） |
|---|---|---:|---|
| 既存40 | `9de6287a59c25a3f976bbbde5256917a10bc37e1` | 40 | 二次意味検査40、独立二重承認0 |
| A | `f38233d12c12f29cdf4b7edf3d3eec992d702ac6` | 69 | スライス自身の評価：52 PASS / 17 HOLD。PASSは独立二重承認ではない |
| B | `3f7e9bc5915007f07c00705ef0664ac1d3db6716` | 69 | 69/69内容点検、原典全肢逐問直接確認は未完了。従前の公式直接照合申告4と探索記録 |
| C | `d74bf8652ea16ef1f35856c1df2e0a4f66b9cd39` | 300 | 個別原典調査90/300、最終権利承認0/300 |

## ID集合検算
- 40 + A69 + B69 = 178件。重複：0件。現行bankの存在：178/178。
- C主一覧300件、重複：0、bank存在：300/300。

## 40問の現行法令の追跡
- 40問200肢の意味検査は `HM2_Q0_COORD_SECOND_PASS_40_PROVISIONAL_20261122.md` と `HM2_Q0_COORD_40_LEGAL_SOURCE_RECHECK_20261122.md` に記録。現行配布JSONの正答indexとの基本的整合は維持。
- 2026-11-22適用版の労働安全衛生規則について e-Gov の2026年施行版を検索・照合。 https://laws.e-gov.go.jp/law/347M50002000032?occasion_date=20260618
- 厚労省の選任報告案内により衛生管理者選任事由から14日以内、報告は遅滞なくという2要件を確認。 https://www.mhlw.go.jp/stf/newpage_09979.html
- 2025年1月からの選任報告・健診結果報告等の原則電子申請を別の厚労省資料で照合。 https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/denshishinsei_00002.html
- 労基法34条休憩、32条労働時間、36条届出について厚労省公式説明を確認。 https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudouseisaku/chushoukigyou/joken_kankyou_rule.html
- 一部の公開FAQは旧紙提出説明を残している。2025年電子申請化との時間的整合を優先し、古いFAQを単独根拠にしない。
- 二次意味検査の実施主体はこれまでと同系列のAIセッションであり、独立した別実施者による二回目の真正な再検査と認定できない。レビュー用アーティファクトの正規SHA-256、参照前宣誓、別セッションID、各肢原典引用・施行版まで揃っていない。**正式二重チェック完了0/40**。

## 追加のリスク・保留
- AのHOLD 17件は保留維持。特にNo.52 `sm2-5y-r08-hyg-01` の『20〜50分』の仮眠時間表現、No.63の個別SDSと一般手順の対応は一次根拠・表現修正を要検討。
- Cの個別調査90件は権利承認ではない。初期からの設問原典類似と出典適合性疑義、No.88のStatPearls商用・翻案条件、No.87のCC帰属等は未解消。最終権利承認0/300。

## 回帰・判定
- 実行環境 `git ls-remote` は `Could not resolve host: github.com` で失敗。checkoutができずNode/Python回帰18件を実測できていない。GitHub接続に新規workflow起動操作がないためGHA手動実行も不可。
- Q0の形式検査と実質検査を混同しない。**Q0 BLOCKED / Q1 BLOCKED**。データ・生成元・ゲートの制限変更なし。App Review提出およびTestFlight配信なし。
