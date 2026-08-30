# クリップボードWidget｜App Store Connect Web操作引き継ぎ

更新: 2026-08-30

## 現在状態
- Bundle ID: `jp.allsunday1122.clipboardwidget`
- Widget Extension: `jp.allsunday1122.clipboardwidget.widget`
- App Store Connect App ID: 未発行
- App Store Connect API read-back: match_count = 0
- 署名済みIPA生成: PASS
- TestFlight upload: App Store Connect Appレコード未作成のため停止
- 本審査自動提出: 禁止

## 正しい人間介入境界
Notion「申請手順」正本に従い、新規AppレコードのWeb UIフォーム入力・作成はエージェント担当。ユーザー担当はAppleログイン、パスワード、2FA、本人確認など本人操作が不可避な部分のみ。

## Web UI固定packet
- Platform: iOS
- Name: `クリップボードWidget`
- Primary language: Japanese
- Bundle ID: `jp.allsunday1122.clipboardwidget`
- SKU: `clipboard-widget-20260827`
- User Access: Full Access

## browser-capable agentの実行手順
1. App Store Connect Web UIを開く。
2. 未ログインならユーザーにログイン/2FAのみ依頼する。認証情報は記録しない。
3. Apps → + → New App。
4. 上記固定packetを入力し作成する。
5. 作成後、数値App IDをユーザーに転記させず、既存App Store Connect API GatewayでBundle IDから再取得する。
6. Apple実発行App IDをNotion「【正本】対象アプリ識別情報｜App Store Connect / Codemagic」とクリップボードWidget正本へ反映する。
7. `clipboard-widget-phase0` Codemagic workflowを起動し、署名→IPA→TestFlight uploadを実行する。
8. Apple processing完了とInternal TestFlight利用可能状態をread-backする。
9. 実機受入のみユーザーへ戻す。期待値: Large Widgetの`TESTをコピー`タップ後、アプリ画面へ遷移せず、メモへ `Widget Copy Test` が完全一致でPasteできること。

## この通常チャットで確認した環境制約
- ローカルChromium/Playwrightは存在する。
- `https://appstoreconnect.apple.com` への遷移は `net::ERR_BLOCKED_BY_ADMINISTRATOR` で遮断された。
- したがって、この通常チャットの実行面ではApple Web UIへ到達できない。
- App Store Connect APIの `POST /v1/apps` は実アカウントでも403、`apps` resourceはCREATE非対応。

この停止は「ユーザーがAppレコードを手入力すべき」という意味ではない。browser-capable Work/Computer Use実行面へ移った時点で、エージェントがWeb UI作成を担当する。
