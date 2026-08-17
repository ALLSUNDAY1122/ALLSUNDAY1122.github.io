# Release Status

Status: **教材132問・法令51問 最終追加監査PASS / Apple側登録・署名ビルド待ち**
Updated: 2026-08-08

- 旧44論点×3の水増し構造を破棄
- 3公表回の問1〜44の出題領域に対応した独自132問へ再構築
- ID / 問題文 / conceptKey / 選択肢集合 132/132一意
- 正答文の完全重複0、意味的重複として棄却すべき問題0
- 関係法令51/51を2026-08-08基準で一次資料再監査PASS
- FP2 v1.3 UI / StoreKit 2 / Privacy Manifest / Codemagic設定は維持

残作業: Apple Developer / App Store Connect / 署名付きIPA / TestFlight / StoreKit Sandbox実機確認。


## UI Master v2.1
2026-08-09: 最上位正本をNotion UI Master v2.1へ更新。FP2 v1.3基準を廃止し、Golden Master世代の紙・方眼・4タブ・8問・記録・設定体系へ同期。

## 課金仕様更新｜2026-08-09
Notion「申請手順」第6節B/Cに合わせ、買い切り単独から2プランへ変更。
- 月額 `jp.allsunday1122.healthmanager1.monthly`: 200円相当 / 1か月 / 初回対象者7日無料 / 自動更新
- 買い切り `jp.allsunday1122.healthmanager1.lifetime`: 980円相当 / Non-Consumable
- どちらでもプレミアム範囲を解放
- 価格と無料トライアル対象可否はStoreKitを正本に表示
Apple側の商品作成とSandbox実機確認は未完了。
