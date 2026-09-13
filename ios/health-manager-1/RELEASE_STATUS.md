# Release Status

Status: **公開準備 / 現行Release Gate再監査中**  
Updated: 2026-09-13

## 現行製品契約
- App Store Connect App ID: `6799581662`
- Bundle ID: `jp.allsunday1122.healthmanager1`
- 収録: 独自作問264問
- 公表回対応3セット + 追加演習3セット
- 1セット44問
- 今日のスプリント: 4 / 8 / 16問
- 月額: `jp.allsunday1122.healthmanager1.monthly` / 200円
- 買い切り: `jp.allsunday1122.healthmanager1.lifetime` / 800円
- 対象者の月額7日無料トライアルはStoreKitの資格・ASC設定を正本とする

旧記録の「132問」「Apple側App未登録」「買い切り980円」は履歴であり、現行Release判断へ使用しない。

## 現在のRelease Gate
- [ ] 現行264問を構造・正答・解説・重複・一次根拠・法令基準日まで再監査
- [ ] StoreKit UI / entitlement / 購入 / 復元 / revocationのRegression Gate
- [ ] 学習循環 Acceptance Contract
- [ ] Visual Gate
- [ ] ASC Version / IAP / Build / TestFlight fresh read-back
- [ ] 現HEADとRelease Buildの差分0
- [ ] Build `VALID / APP_STORE_ELIGIBLE / expired=false`
- [ ] Primary Category / 年齢評価 / Store screenshots / Review Detail整合
- [ ] 新Release Buildの実機Human Test
- [ ] Submit for Review直前のユーザー最終承認

TestFlightは開発QAに使用せず、AI Preflight / Visual Gate / Release Gate通過後のHuman Testに限定する。
