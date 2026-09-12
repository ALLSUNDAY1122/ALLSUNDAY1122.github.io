# ChatGPT Queue Dispatcher PoC

GitHub上のTask Queueを一定間隔で確認し、登録したChatGPT会話タブへ次のTaskを投入するChrome拡張機能のPoCです。

今回の実証対象は **学びスプリント 開発連番16「作業療法士国家試験」** です。

## 目的
Codexを多数ChatGPTセッションの配車係として使う方式をやめ、
`GitHub Queue → Chrome Dispatcher → ChatGPT Worker → GitHub checkpoint → 次Task`
の連鎖が成立するかを検証します。

## 安全設計
- PoC既定値は `maxActive=1`。まず直列8Taskで連鎖を検証します。
- QueueはGitHubの公開raw JSONを**読み取るだけ**。拡張機能へGitHub tokenを保存しません。
- Queueの完了更新はChatGPT WorkerがGitHub Connectorで行います。
- 拡張機能はChatGPTの回答本文を収集・保存しません。
- UIでは「生成中か否か」とcomposer/send buttonだけを確認します。
- 連投によるUsage Limit回避は目的にせず、Task完了とGitHub状態更新を発火条件にします。
- secret/token/署名鍵を拡張機能・Queue・GitHubへ保存しません。

## 重要
ChatGPTのWeb UIは自動化用の安定APIではありません。DOM変更で送信が壊れる可能性があります。
その場合は自動停止し、selectorを修正して再開します。長期の正本スケジューラはGitHub Queueです。

OpenAIの利用条件上、出力をプログラムで抽出する設計にはしません。
このPoCは入力配車と生成状態の確認に限定します。

## インストール
1. このフォルダをPCへ保存します。
2. Chromeで `chrome://extensions` を開きます。
3. 「デベロッパーモード」をON。
4. 「パッケージ化されていない拡張機能を読み込む」で、このフォルダを選択します。
5. ChatGPTで新規会話を1つ開き、拡張機能アイコンを押します。
6. `Worker-1 / ANY` のまま「現在のタブを登録」。
7. `maxActive=1`、確認間隔2分のまま「自動配車を有効化」→「保存」。
8. 「今すぐ確認」で LS16-001 が送信されれば初期I/O PASSです。

## Queue
`learning-sprint-16/queue.json`

Taskは依存関係がすべて `DONE` になったものだけ実行可能です。
WorkerはTask完了時にGitHub Connectorで対象Taskだけ `DONE` に更新します。
次回pollでlocal leaseが解放され、次Taskが同じWorkerへ自動投入されます。

## PoC合格条件
- LS16-001→003まで最低3Taskが、人間の「次」なしで連続する。
- 同一Taskの二重投入0。
- 完了前に次Taskを投入0。
- GitHub Queueと実作業の不一致0。
- Codex使用0。
- ChatGPT出力本文のプログラム抽出0。
- 途中でChromeを再起動しても、Queue/leaseから安全に再開できる。

3Task連鎖PASS後に `maxActive=2` を別実験として評価します。
