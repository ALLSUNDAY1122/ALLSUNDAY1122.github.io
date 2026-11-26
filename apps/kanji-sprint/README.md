# 小学生漢字｜学びスプリント（作業名）— 初期実装

小学1〜6年の1,026字を学年別に「読み」と「書き」で学ぶ iOS アプリの初期実装一式。
仕様は `SPEC.md`、データは `data/kanji-1026.json`（変更しないこと）。
このフォルダは GitHub リポジトリ上の `apps/kanji-sprint/` に対応する。

- Bundle ID: `jp.allsunday1122.kanjisprint`
- 課金: 無料＋広告（AdMob）／買い切り¥500（`jp.allsunday1122.kanjisprint.premium.noads`、非消耗型）で広告なし。学年ロックなし
- iPhone専用（TARGETED_DEVICE_FAMILY "1" をプロジェクト側・ターゲット側の両方に記載し、CIで生成後 pbxproj も強制）

## ファイル一覧

| パス | 行数 | 内容 |
|---|---|---|
| `ios/project.yml` | 56 | XcodeGen 定義。AdMob SDK を SPM で追加（googleads/swift-package-manager-google-mobile-ads、from 11.0.0）。Info.plist へ GADApplicationIdentifier（テスト用）・SKAdNetworkItems・iPhone 4方向の画面向きを設定 |
| `ios/prepare-ios.sh` | 35 | `../data/kanji-1026.json` を `ios/Resources/` へコピーし、件数1,026・学年別字数 80/160/200/202/193/191・全件 strokes あり・画数一致を検証して PASS を出す |
| `ios/Assets.xcassets/` | — | 最小構成のみ（AppIcon は空。アイコン作成は残課題） |
| `ios/Sources/KanjiStudyApp.swift` | 59 | @main。Store 注入、`.preferredColorScheme(.light)`、AdMob 初期化と子ども向け設定（tagForChildDirectedTreatment=true、maxAdContentRating=G）。共通の Palette と PrimaryButtonStyle もここに定義 |
| `ios/Sources/KanjiStore.swift` | 304 | データ読み込み、学年別グループ化、SVG パスパーサ（M/m/C/c/S/s、相対→絶対変換、S の反射制御点）、画ごとの Path・点列・始点・終点 API、今日の学習（苦手優先） |
| `ios/Sources/StudyRecordStore.swift` | 224 | 学習記録（UserDefaults キー `kanji-study-record-v1`）。字ごとの正誤、書き完了、苦手（3連続正解で解除）、日次集計、セッション履歴20件、リセット |
| `ios/Sources/PremiumStore.swift` | 109 | StoreKit 2。買い切り1件のみ。isNoAds、purchase()、restore()（AppStore.sync）、Transaction.updates 監視 |
| `ios/Sources/AdsBannerView.swift` | 28 | GADBannerView の UIViewRepresentable。テスト用バナーユニットID、npa=1（非パーソナライズ） |
| `ios/Sources/HomeView.swift` | 274 | 学年カード1〜6年、今日の学習、苦手復習、学習状況、設定導線、下部バナー（isNoAds で非表示）。画面遷移（KanjiRoute）の定義もここ |
| `ios/Sources/GradeKanjiListView.swift` | 123 | 学年の漢字グリッド（漢字＋読み1つ＋学習済み／苦手／書けた印）、学年クイズ導線 |
| `ios/Sources/KanjiDetailView.swift` | 203 | 大きな漢字、音・訓読み（送り仮名は「.」の後ろを navy で色分け、「-」は非表示）、画数、筆順、記録、クイズ／書き練習導線 |
| `ios/Sources/StrokeOrderView.swift` | 125 | 筆順のステップ表示と自動再生（Shape の trim で1画ずつ描く）。マス目ガイド付き |
| `ios/Sources/ReadingQuizView.swift` | 300 | 読みクイズ10問。2モード（漢字→読み／読み→漢字、mixed 可）。選択肢は同学年プールから生成し正解と重複する読みを除外。即時正誤＋全読み表示、「わからない」、結果画面（ホームへ戻る／苦手だけ復習） |
| `ios/Sources/WritingPracticeView.swift` | 228 | なぞり書き。対象画をオレンジで点滅表示し、指を離した時点で始点・終点の距離（109座標系で28以内）を判定。外れた側に応じたヒント文。全画完了で「書けた！」＋記録 |
| `ios/Sources/SettingsView.swift` | 93 | Premium 購入シート（価格表示・購入・復元）、学習記録リセット（確認アラート付き）、クレジット（KANJIDIC2 © EDRDG / CC BY-SA 4.0、KanjiVG © Ulrich Apel and contributors / CC BY-SA 3.0） |

生成物（push しない）: `ios/Resources/kanji-1026.json`（prepare-ios.sh が生成）、`ios/Info.plist`（XcodeGen が生成）。

## 設計メモ

- **座標系**: KanjiVG のパスは 109×109 で保持し、表示側で `KanjiStrokeShape` が描画領域に拡縮する。なぞり判定もユーザーの点列を 109 座標系へ戻してから始点・終点の距離を測る。
- **パーサ**: データ全9,662画のコマンドは M/m/C/c/S/s のみ（検証済み）。S/s の第1制御点は直前の曲線の第2制御点を現在点で反射。点列は3次ベジェを20分割サンプリングし、始点・終点はパス端点そのもの。
- **クイズの選択肢**: 読み→漢字モードでは、その読みを持つ他の字を誤答にしない（正解の複数化防止）。漢字→読みモードでは、その字の全読みを誤答プールから除外する。
- **広告の子ども向け配慮**: requestConfiguration で child-directed treatment と上限Gを設定し、ATT は出さない。リクエストには GADExtras で npa=1 を付ける。Premium 購入済みの場合はバナー自体を配置しない。
- **色**: ITパスポートのダークモード事故の教訓でライト固定＋固定 Palette。文字色に `.primary` / `.secondary` は不使用。数値は `Text(verbatim:)` で補間し、カンマ区切りの混入を防ぐ。
- **Info.plist の AdMob キー**: GADApplicationIdentifier は INFOPLIST_KEY と info.properties の両方に、SKAdNetworkItems（配列）は info.properties に書いた。最終成果物の Info.plist に両キーが入っているかは Codemagic の検証ステップで断言する（下記スニペット参照）。初回ビルドで検証が落ちたら、生成された Info.plist の実物を見て project.yml 側を直すこと。

## 品質チェック結果（2026-11-27、ローカル実施）

- 括弧バランス: 全12 Swift ファイルで `{}` `()` `[]` の数が一致（文字列・コメントを除いて機械チェック）。全ファイル OK。
- パスデータ: 全9,662画がトークン化でき、コマンドごとの数値グループ数（M=2n、C=6n、S=4n）も正しいことを確認。
- prepare-ios.sh: ローカル実行で PASS（1,026件・学年別字数・全件 strokes・画数一致）。
- project.yml と下記ワークフロー YAML: パース検証 OK。
- Swift のコンパイル確認はローカルにコンパイラがないため未実施。Codemagic の初回ビルドが確認になる。

## push 手順（親エージェント向け）

1. ローカル `kanji-app/` の内容を、リポジトリ `ALLSUNDAY1122/ALLSUNDAY1122.github.io` の `apps/kanji-sprint/` へ配置する。`data/` と `SPEC.md` は既存のものをそのまま使う（この作業では変更していない）。
2. push 対象パスのマニフェスト案（リポジトリルートからの相対パス、NUL 区切りで push-files へ）:

```text
apps/kanji-sprint/data/kanji-1026.json
apps/kanji-sprint/ios/project.yml
apps/kanji-sprint/ios/prepare-ios.sh
apps/kanji-sprint/ios/Assets.xcassets/Contents.json
apps/kanji-sprint/ios/Assets.xcassets/AppIcon.appiconset/Contents.json
apps/kanji-sprint/ios/Sources/KanjiStudyApp.swift
apps/kanji-sprint/ios/Sources/KanjiStore.swift
apps/kanji-sprint/ios/Sources/StudyRecordStore.swift
apps/kanji-sprint/ios/Sources/PremiumStore.swift
apps/kanji-sprint/ios/Sources/AdsBannerView.swift
apps/kanji-sprint/ios/Sources/HomeView.swift
apps/kanji-sprint/ios/Sources/GradeKanjiListView.swift
apps/kanji-sprint/ios/Sources/KanjiDetailView.swift
apps/kanji-sprint/ios/Sources/StrokeOrderView.swift
apps/kanji-sprint/ios/Sources/ReadingQuizView.swift
apps/kanji-sprint/ios/Sources/WritingPracticeView.swift
apps/kanji-sprint/ios/Sources/SettingsView.swift
```

3. ルート `codemagic.yaml` の `workflows:` に下記 `kanji-sprint-ios` を追加する（既存の `itpassportstudy-ios` と並べる）。これは codemagic.yaml の差分として別途 push する。
4. Codemagic で `kanji-sprint-ios` を実行し、検証ステップの PASS（UIDeviceFamily==[1]、同梱 JSON 1,026件、GADApplicationIdentifier、SKAdNetworkItems）まで確認する。

## codemagic.yaml 追加スニペット（workflows: の下へ）

```yaml
  kanji-sprint-ios:
    name: 小学生漢字 - SwiftUI Internal TestFlight
    max_build_duration: 60
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: "Codemagic Shiwake Swipe"
    environment:
      ios_signing:
        provisioning_profiles:
          - kanjisprint_appstore
      vars:
        BUNDLE_ID: jp.allsunday1122.kanjisprint
        XCODE_PROJECT: apps/kanji-sprint/ios/KanjiStudy.xcodeproj
        XCODE_SCHEME: KanjiStudy
      xcode: latest
    scripts:
      - name: Prepare and validate kanji resources
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/apps/kanji-sprint/ios"
          bash -n prepare-ios.sh
          bash prepare-ios.sh
          test -s Resources/kanji-1026.json
      - name: Install XcodeGen and generate project
        script: |
          set -euo pipefail
          HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
          cd "$CM_BUILD_DIR/apps/kanji-sprint/ios"
          python3 - <<'PY'
          import os, pathlib
          p = pathlib.Path('project.yml')
          s = p.read_text()
          number = os.environ.get('BUILD_NUMBER', '')
          if not number.isascii() or not number.isdecimal() or int(number) < 1:
              raise SystemExit('FAIL: Codemagic BUILD_NUMBER missing or invalid')
          print('PASS: Codemagic BUILD_NUMBER=' + number)
          assert s.count('CURRENT_PROJECT_VERSION: 1') == 1
          p.write_text(s.replace('CURRENT_PROJECT_VERSION: 1', 'CURRENT_PROJECT_VERSION: ' + number, 1))
          PY
          xcodegen generate
          python3 - <<'PY'
          import pathlib, re
          p = pathlib.Path('KanjiStudy.xcodeproj/project.pbxproj')
          s = p.read_text()
          found = re.findall(r'TARGETED_DEVICE_FAMILY = [^;]+;', s)
          assert found, 'FAIL: TARGETED_DEVICE_FAMILY not found in generated project.pbxproj'
          p.write_text(re.sub(r'TARGETED_DEVICE_FAMILY = [^;]+;', 'TARGETED_DEVICE_FAMILY = 1;', s))
          print('PASS: forced TARGETED_DEVICE_FAMILY=1 (' + str(len(found)) + ' occurrences)')
          PY
          grep -q 'TARGETED_DEVICE_FAMILY = 1;' KanjiStudy.xcodeproj/project.pbxproj
      - name: Apply App Store signing profiles
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/apps/kanji-sprint/ios"
          xcode-project use-profiles
      - name: Build signed IPA
        script: |
          set -euo pipefail
          xcode-project build-ipa --project "$CM_BUILD_DIR/$XCODE_PROJECT" --scheme "$XCODE_SCHEME"
      - name: Verify signed IPA and bundled kanji data
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR"
          ipa=(build/ios/ipa/*.ipa)
          test "${#ipa[@]}" -eq 1
          test -f "${ipa[0]}"
          expanded="$(mktemp -d)"
          ditto -x -k "${ipa[0]}" "$expanded"
          app="$expanded/Payload/KanjiStudy.app"
          codesign --verify --deep --strict "$app"
          python3 - "$app" <<'PY'
          import json, os, pathlib, plistlib, sys
          from collections import Counter
          app = pathlib.Path(sys.argv[1])
          info = plistlib.loads((app / 'Info.plist').read_bytes())
          assert info['CFBundleIdentifier'] == os.environ['BUNDLE_ID']
          assert info.get('UIDeviceFamily') == [1], f"FAIL: UIDeviceFamily must be [1] (iPhone only): {info.get('UIDeviceFamily')!r}"
          expected_orientations = {'UIInterfaceOrientationPortrait', 'UIInterfaceOrientationPortraitUpsideDown', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'}
          for key in ('UISupportedInterfaceOrientations', 'UISupportedInterfaceOrientations~ipad'):
              values = info.get(key)
              if key.endswith('~ipad') and values is None:
                  values = info.get('UISupportedInterfaceOrientations')
              if not isinstance(values, list) or len(values) != 4 or set(values) != expected_orientations:
                  raise SystemExit(f'FAIL: {key} must contain all four orientations: {values!r}')
          print('PASS: IPA Info.plist supports all four orientations')
          assert info['ITSAppUsesNonExemptEncryption'] is False
          # AdMob 設定（Build 1 はテスト用アプリID。本番IDに差し替えたらこの期待値も変える）
          assert info.get('GADApplicationIdentifier') == 'ca-app-pub-3940256099942544~1458002511', f"FAIL: GADApplicationIdentifier: {info.get('GADApplicationIdentifier')!r}"
          skad = {item.get('SKAdNetworkIdentifier') for item in info.get('SKAdNetworkItems', [])}
          assert 'cktu78qm5g.skadnetwork' in skad, f'FAIL: SKAdNetworkItems missing cktu78qm5g: {skad!r}'
          print('PASS: AdMob app id and SKAdNetworkItems present')
          expected = pathlib.Path('apps/kanji-sprint/ios/Resources/kanji-1026.json').read_bytes()
          actual = (app / 'kanji-1026.json').read_bytes()
          assert actual == expected
          items = json.loads(actual)['kanji']
          assert len(items) == len({i['kanji'] for i in items}) == 1026
          counts = Counter(i['grade'] for i in items)
          assert [counts[g] for g in range(1, 7)] == [80, 160, 200, 202, 193, 191]
          assert all(i['strokes'] and len(i['strokes']) == i['strokeCount'] for i in items)
          print('PASS: signed IPA and 1026 bundled kanji')
          PY
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: false
        submit_to_app_store: false
```

## 残課題

- **AdMob 本番ID差し替え**: 浩平の AdMob アカウント開設後、本番のアプリIDとバナーユニットIDに差し替える。対象は3か所: `ios/project.yml` の GADApplicationIdentifier（INFOPLIST_KEY と info.properties の2か所）、`ios/Sources/AdsBannerView.swift` の `testUnitID`。あわせて Codemagic 検証ステップの GADApplicationIdentifier 期待値も本番IDに変える。
- **ASC 新規アプリ作成と Bundle ID 登録**: `jp.allsunday1122.kanjisprint`（SKU 案 `kanjisprint-ios-2026`、アプリ名「小学生漢字｜学びスプリント」）。
- **買い切り商品¥500の登録**: `jp.allsunday1122.kanjisprint.premium.noads`（非消耗型）。審査用スクリーンショットは設定画面の Premium シートを使う想定。
- **アプリアイコン**: `Assets.xcassets` は空（ビルドは通るが提出には必須）。ITパスポートと同じく正規アイコン素材を用意する。
- **署名プロファイル名の確定**: ワークフローでは `kanjisprint_appstore` と仮置きした。Codemagic 側で実際に使うプロファイル名に合わせること。
- **App Privacy 申告**: 広告 SDK（Google Mobile Ads）分が必要。ITパスポートの「Data Not Collected」とは異なるので、提出時に申告内容を用意する。
- **未実装（次フェーズ）**: SPEC 3.3 の「書きテスト」（お手本なし）と 3.4 の学年別まとめテスト。読みクイズ・筆順・なぞり書きは本実装に含む。
- **初回ビルドでの確認点**: SPM で GoogleMobileAds 11.x が解決できるか、生成 Info.plist に GADApplicationIdentifier / SKAdNetworkItems が入るか（検証ステップで断言済み）、AdMob の PrivacyInfo.xcprivacy 同梱に伴う署名まわり。
