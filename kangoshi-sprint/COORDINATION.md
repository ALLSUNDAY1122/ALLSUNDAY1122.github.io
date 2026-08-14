# 看護師国家試験｜学びスプリント 統括・3班編集境界

更新日: 2026-08-14
適用標準手順: AIアプリ開発 標準手順 v2.5
NO_PROGRESS正本: v2.0

## 目的

開発連番#3を、A必修150問・B一般390問・C状況設定180問（60症例×3問）で並行処理し、統括が720問、UI、模試、課金、リリースへ統合する。GitHub `main` を現在値の正本とし、過去チャットの数字は監査結果と一致するときだけ採用する。

## ループ原則

変更 → 対応品質ループ → 監査 → FAIL修正 → 再監査 → PASSまで反復 → 次工程。

一度PASSした対象でも変更後は関連PASSを失効させる。小分けバッチのPASSは最終PASSへ流用せず、試験回または試験回×大分類のcanonical JSONへ統合後、共通validatorとカテゴリ固有validatorを再実行する。

### NO_PROGRESS v2.0

- 同じ操作を繰り返さない。原因・層・戦略を変える。
- 正常に受理・実行中の外部jobは `WAIT_EXTERNAL` とし、再実行しない。
- 局所commitだけでは全体進展とみなさず、監査結果・成果物・PASS/FAIL・工程遷移で判定する。
- 専門監査・メディア監査など隔離可能な待ち項目は並列キューへ移し、独立して進められる作業を止めない。
- 人間判断が本当に必要なゲートまで自動継続する。

## 班の責任範囲

### A｜必修150問
`category == "必修"` の本文・解説・根拠・基準日・動的根拠・内容監査を担当。新規バッチは `A-required-*` / `A-REQUIRED-*`。

### B｜一般390問
`category == "一般"` の本文・解説・根拠・基準日・動的根拠・内容監査を担当。新規バッチは `B-general-*` / `B-GENERAL-*`。

### C｜状況設定180問
`category == "状況設定"` を3問1症例で担当。症例本文、患者像、時間経過、3問整合、解説、根拠、基準日を監査する。専門確認が必要でもその症例だけ隔離し、別症例を止めない。

## 統括だけが編集する共通領域

- `kangoshi-sprint/product-content/enriched-draft/**`
- `kangoshi-sprint/product-content/manifest.json`
- `kangoshi-sprint/product-content/enrichment-trigger.json`
- raw補正・正規化・共通apply/build/validate scripts
- `kangoshi-sprint/product-content/questions/**`
- canonical builder/validator
- `.github/workflows/kangoshi-*.yml`
- 共通UI、模試、課金、StoreKit 2、iOS、Privacy、申請・リリース関連

班で共通修正が必要な場合は直接編集せず、班固有成果物へID・理由・修正案を残す。

## 統括責任

- 3班のGitHub現在値を各ループで再取得。
- ID/batch重複0を維持。
- raw欠損は一次資料確認済み補正として再現可能な正規化工程へ組み込み、raw→L2→L3を再発火。
- 3カテゴリをcanonical JSONへ統合し、共通・固有validatorをPASSまで反復。
- メディア・採点例外・専門監査対象はcanonicalから削除せず隔離状態を保持。
- 720/720 L3後にメディア権利・専門監査を統合。
- 本番240問モードは各回240問が解放可能になってから完成扱い。
- Golden Master v2.1、標準8問（設定4/8/16）、4タブを維持。
- 模試、StoreKit 2、課金監査、リリース監査、TestFlightを担当。
- Notion正本をGitHub監査結果へ同期。

## 公開試用・課金・識別子

試用URL: `https://allsunday1122.github.io/kangoshi-sprint/`

2026-08-14に初期試作品の人間確認PASS。

課金は月額200円。StoreKit 2 `Product.displayPrice` を使用し、verified transaction・対象Product ID一致・未取消のみ権利付与、購入復元必須。

Bundle ID: `jp.allsunday1122.kangoshi`
予定Product ID: `jp.allsunday1122.kangoshi.monthly`
数値Apple IDは実発行値のみ記録する。

## 現在のゲート｜2026-08-14 18:55 JST

- raw: 720/720 PASS。第113回一般5問の公式PDF取込欠損は恒久補正済み。
- L2: 720 high、unclassified 0、状況設定専門補正4件反映、警告32/32解決、PASS。
- A必修: 150/150 **final canonical PASS_WITH_QUARANTINE**。通常候補136・隔離14。
- B一般: 390/390 **final canonical PASS_WITH_QUARANTINE**。integrity/common auditともexit 0。第113回13問の修復もcanonicalへ反映済み。
- C状況設定: 156/180問、52/60症例。残24問・8症例（第113回午後SC03〜SC10）。最終canonical未生成。
- 共通L3: **674/720、pending 46、dynamic evidence pending 19、FAIL、releaseAllowed=false**。
- 初期試作品確認: PASS。
- メディア権利、専門監査、模試240問、StoreKit 2、リリース監査、TestFlight: 未PASS。

次はCの60/60完了を待ち、状況設定canonical生成・再監査 → 共通L3再生成 → 残dynamic/media/content/scoring/expertキュー収束 → 権利・専門監査 → 模試 → StoreKit 2 → TestFlightへ進む。

全3カテゴリfinal canonical PASS、共通L3 720/720、権利・専門監査PASSまで製品版全体を完成扱いしない。
