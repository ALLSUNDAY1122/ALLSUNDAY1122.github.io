# AI引継ぎ帳 v0.6 Apple資格情報作成・検証キット

作成日：2026年7月24日

ローカル配布キット：

`AI_Handover_Log_v0.6_Apple_Credential_Creation_Validation_Kit_2026-07-24.zip`

SHA-256：

`e14d6974d06d24ef8fc7374ba00b8fff24786b598c68d8c6580b476d35c1e066`

検証済み項目：

- `verify_app_store_connect_api_key.py`のPython構文
- `validate_apple_release_credentials_macos.sh`のBash構文
- 一時的に生成したP-256秘密鍵によるES256 JWT作成
- JOSE署名が64バイトの`R || S`形式であること

ローカルキットに秘密情報、実証明書、実プロビジョニングプロファイル、実APIキーは含まれない。
