# Splat Lab Native

iPhone単体で「ARKit撮影 → Nerfstudio形式保存 → msplat/Metalで3D Gaussian Splat学習 → MetalSplatterで表示」までを検証するネイティブiOS PoCです。

## 目的

旧 `omochabako/` の疑似3D（撮影写真を順に見せる方式、粗いポリゴン方式）を捨て、実Gaussian Splat生成がiPhone 16で成立するかだけを先に検証します。

## 実装済み

- ARKit world trackingによるカメラ姿勢取得（LiDAR必須ではない）
- 位置・角度差に基づく自動フレーム選別
- 24〜48枚のJPEG＋camera-to-world行列保存
- Nerfstudio互換 `transforms.json` 生成
- `msplat` によるMetalオンデバイス学習（PoC既定2,000 iterations）
- `.splat` 出力
- `MetalSplatter` による実3DGS表示
- Files/AirDrop等への`.splat`共有
- 外部API・アカウント・解析・クラウド送信なし

## 依存関係とライセンス

- `Voxelio-app/msplat` source-only iOS fork at `d620d9c...` — Apache-2.0（上流 rayanht/msplat）
- `scier/MetalSplatter` at `2b965de...` — MIT

Voxelioの `ios-gaussian-splatting-demo` 本体（PolyForm Noncommercial）は依存・コピーしていません。公開されているアーキテクチャは技術調査の比較対象としてのみ使用し、アプリ実装は独自です。

## ビルド

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project SplatNative.xcodeproj -scheme SplatNative -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO build
```

実機ではiOS 18以降が必要です。カメラとMetal学習はシミュレータでは評価できません。

## PoC合格条件

1. iPhone 16で24枚以上撮影できる。
2. `transforms.json` と撮影画像が端末内に生成される。
3. `msplat` のiterationが進み、`result.splat` が作成される。
4. 生成結果をアプリ内で回転・拡大できる。
5. 花束・工作・ぬいぐるみのうち2/3以上で「写真の切替ではなく立体」と認識できる。

品質が不足する場合は、撮影枚数・フレーム選別・マスク・初期点群・学習iterationを順に改善します。疑似3Dへは戻しません。
