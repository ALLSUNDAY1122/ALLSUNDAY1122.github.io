# 実行した検証

- raw.jsonのJSON parse成功、グラフnode数3,682を確認。
- raw.json.gzを展開しながら計算したSHA-256が原本と一致。
- 証拠ファイルのcredential形状スキャンに一致なし。環境変数全量の読み取り・保存は未実施。
- 対象コードは実行していない。workflow案は未実行。
- git diff --cached --check: 最初は番号付き抜粋と結合ログの空白で失敗。原stdout/stderrは保持し、表示用抜粋・結合ログの末尾空白を修正して再実行。

- 保存先変更後: raw.json.gzは23,576,915 bytes、50MB未満。未圧縮raw.jsonは追加対象外。圧縮データの展開後SHA-256を再確認。
