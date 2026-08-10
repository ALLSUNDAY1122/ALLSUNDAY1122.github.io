# 通関士 Native canonical assets

`02_通関士.png` は Notion「学びスプリント｜App Store用アイコン正本一覧」から参照される Google Drive 個別PNGを、そのまま配置する。

- ファイル名: `02_通関士.png`
- expected bytes: `556001`
- expected SHA-256: `ff9fd508930e8728ef54907ec64a7835dcffb69a1a773edc645b79715fbfccaa`
- PNG: 1024×1024 / 8-bit RGB / alphaなし

禁止: 再描画、一覧画像からの切り出し、色変更、リサイズ済み別画像への差し替え、非公開Drive URLへのCIからの匿名curl。

`fetch-canonical-appicon.sh` がこのファイルのバイト数・SHA-256・PNG IHDRを検証して `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` に配置する。
