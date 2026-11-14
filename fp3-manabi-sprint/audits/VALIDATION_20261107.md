# 申請準備の検証記録

確認日：2026-11-07 JST

| 検証 | 結果 | 範囲 |
|---|---|---|
| `node --test scripts/tests/fp3-session.test.mjs` | 6件PASS | 回答直後再起動、二重集計防止、苦手・迷い保存、3連続解除、欠損ID、旧形式、最終位置復帰 |
| `python -B -m unittest discover -s scripts/tests -p 'test_fp*.py'` | 11件PASS | Apple APIの全ページ取得・不正リンク拒否・権限エラーと404の区別、FP2データ検査 |
| FP3 payload構造監査 | PASS | 180問・通常178・隔離2・正誤90・択一90。正答内容の再監査ではない |
| [回帰CI 42356734464](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/42356734464) | success | 17件の回帰＋payload構造。credentials不要 |
| [Apple読み取り 42355999714](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/42355999714) | success | 買い切りREADY_TO_SUBMIT、本体PREPARE_FOR_SUBMISSION、全配信地域JPN |
| [Native Simulator 42356365949](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/42356365949) | success | 変更コードのrevision `50c4ffe1`。iPhone 17 Pro上で実ビルド・UI Test・購入画面のPNG取得 |
| Chromeの開発プレビュー | 確認済み | 実ソースのStoreKit bridgeを模擬。回答→再読込→再開、採点済み状態、問題別出典、設定→購入画面、privacy表示 |
| FP2製品データ検査 | 想定FAIL | `PRODUCT_BANK_MISSING`。検証用8問を承認済み600問に数えない |
| FP2 v2.1移行Gate | 想定FAIL | 旧UI等の既存14件＋実体と配線の2件。Releaseの通過証拠にはしない |

## Simulator画像の確認

XCTest attachment名：`FP3-IAP-Review-Paywall`。取得したPNGを目視し、教材ホームの上に購入画面が表示され、価格・購入復元・閉じる操作が画面内に収まることを確認。`isAssociatedWithFailure=false`。

価格は `SKTestSession(configurationFileNamed: "Review")` のローカル設定値。Apple実商品価格との一致や本物の購入処理を確認したとは報告しない。既に登録済みのASC審査画像は今回置換していない。

## 未検証・未実施

- 全180問の現行一次資料による内容再監査、物理iPhoneの購入・復元・キャンセル・pending・返金。
- 正本AppIcon、公開URLのHTTPS配信、App Privacy・契約等のWeb UI最終確認。
- 新しいRelease/TestFlightの作成・送信、本番審査提出、公開。
- 旧Expo版の `typecheck` 等は現行Swift正本の検証結果に流用しない。

## ビルド経路の補足

ローカルのEAS CLIは25.2.0、解決されたnode-forgeは1.4.0と読み取り確認。リポジトリのAGENTS.mdにあるEAS証明書処理の依存確認条件を満たす新しいEAS build/submitは実行していない。将来EASを配送経路に採用する場合は、公式修正版と互換性を別途確認する。今回のSimulator確認はGitHub macOS上の署名なしテストであり、この依存を変更していない。
