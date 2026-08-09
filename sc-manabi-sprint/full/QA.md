# 情報処理安全確保支援士｜学びスプリント 製品候補版QA

基準日: 2026-08-09

## 初期試作品
- iPhone Safari起動: HUMAN PASS
- 主要操作: HUMAN PASS

## 325問接続後の自動・静的監査
- JavaScript構文: PASS
- 325問以外を拒否する実行時ゲート: PASS
- 問題ID重複拒否: PASS
- 問題文・4択・正答・解説・ここだけ覚える必須検査: PASS
- IPA公開過去問の試験回別模試: 3回 × 25問を要求
- 模試25問未満時の開始禁止: PASS
- 日次4/8/16問: PASS
- 中断保存: PASS
- 苦手3連続正解解除: PASS
- 出典・一部改変表示: PASS
- 結果画面: PASS
- 分野別記録: PASS
- 5週間ヒートマップ: PASS
- 試験日・必要ペース: PASS
- 文字サイズ3段階: PASS
- JSON export/import: PASS
- Safe Area: PASS
- PWA manifest / portrait: PASS
- Service Worker / 問題データキャッシュ: PASS

## 現在のゲート
実データ325問は既存 q0.txt〜q5.txt を連結・展開して読み込む。ブラウザ上で 325/325 と必須項目検査が成立したときだけ `status=full` とし、学習開始を許可する。

次の人間確認では iPhone Safari で `full/` を開き、ホームに「問題データ 325/325 読込済み」、模試に各回「25/25」が表示されることを確認する。ここがPASSするまで、App Store製品化ゲートへ進めない。
