# FP3級・FP2級 本番申請ロードマップ

更新日：2026-11-07 JST

## 優先順

FP3級を先行する。FP2級は独自600問とUI移行を別工程として進める。8月のExpo版をそのまま再提出する前提には戻さない。

| 工程 | FP3級 | FP2級 |
|---|---|---|
| 正本・現在地 | SwiftUI正本・180問を特定済み | 独自600問契約、現UI8問を確認済み |
| Apple readback | 商品READY_TO_SUBMIT、本体PREPARE_FOR_SUBMISSION、旧TestFlight期限切れ | 旧TestFlight期限切れ。商品等は未確認 |
| 権利条件 | 公式条件の再確認・問題別表示を修正 | 利用条件と独自作問契約を区別。契約は維持 |
| 製品修正 | 回答保存・復元・購入入口・公開ページを修正中 | 600問実体を確認するGateを追加。現状は未達 |
| 内容監査 | 180問の変更影響と基準日を再確認 | 論点一覧→20問バッチ→独立監査→600問 |
| 次の必須入力 | 正本AppIcon原本 | 600問の作問・監査成果物 |
| Release判定 | アイコン・内容監査・実機確認後 | 600問・v2.1 UI・課金・実機確認後 |

詳細：

- [FP3 申請状況](fp3-manabi-sprint/RELEASE_STATUS.md)
- [FP3 利用条件確認](fp3-manabi-sprint/audits/LEGAL_REVIEW_20261107.md)
- [FP2 申請状況](fp2-manabi-sprint/RELEASE_STATUS.md)

## 完了条件

検証済みビルドと初回買い切り商品を同時にApp Reviewへ送信し、「審査待ち」を実際に確認する。アップロード、TestFlight、審査提出、承認、公開を別々に記録する。

## 作業場所と保持

本作業はユーザーの「進めて」に基づく申請準備。原本ブランチと他アプリの変更を保護するため、`work/fp-release-20261107` に独立checkoutを作成。所有者はこのチャット、用途はFP両アプリの申請準備、ブランチは `codex/fp-release-preparation-20261107`。作成後のworktree登録一覧で元checkoutと本checkoutの2件を確認。Draft PRのレビュー・統合後に保持を再判断し、自動削除はしない。
