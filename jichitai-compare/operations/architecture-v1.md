# 全国自治体比較サイト 並列運用アーキテクチャ v1

- architectureVersion: `1.0.0`
- designedAt: `2026-07-18`
- coordinator: `編集長・全国統括`
- targetRepository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- targetDirectory: `jichitai-compare/`
- relatedIssue: `#10`
- status: `designed`

## 1. 目的

4地方調査班が同時に自治体情報を更新しても競合しにくく、調査元、進捗、公開データ、検証結果を分離して管理できる構成へ移行する。

設計原則は次のとおり。

1. 調査元データは1自治体1ファイルとする。
2. 作業進捗も1自治体1ファイルとする。
3. 公開サイトは生成済みの単一JSONだけを読み込む。
4. 地方調査班は担当自治体の調査元ファイルと進捗ファイルだけを編集する。
5. 共通定義、生成処理、検証処理、公開画面は編集長・全国統括だけが変更する。
6. 既存3自治体の情報を欠落させず、生成前後の意味的同一性を検証する。
7. 生成物は入力が同じならバイト単位で同じ結果になるようにする。
8. `PARALLEL_READY`は実装、検証、PR統合、公開確認の完了後にだけ作成する。

## 2. ディレクトリ構成

```text
jichitai-compare/
├─ data/
│  ├─ municipalities/
│  │  ├─ 12/
│  │  │  ├─ 12203.json
│  │  │  └─ 12227.json
│  │  └─ 13/
│  │     └─ 13123.json
│  ├─ generated/
│  │  └─ municipalities.json
│  └─ service-definitions.json
├─ operations/
│  ├─ tasks/
│  │  ├─ 12203.json
│  │  ├─ 12227.json
│  │  └─ 13123.json
│  ├─ progress.json
│  ├─ migration-manifest.json
│  ├─ architecture-v1.md
│  └─ PARALLEL_READY
├─ scripts/
│  ├─ generate-municipalities.mjs
│  ├─ validate-data.mjs
│  └─ update-progress.mjs
├─ app.js
├─ index.html
├─ styles.css
└─ package.json
```

`operations/PARALLEL_READY`はPhase 0完了時まで存在させない。

## 3. 自治体調査元JSON

保存先：

```text
data/municipalities/{都道府県コード}/{自治体コード}.json
```

既存の自治体オブジェクトを大きく崩さず、1ファイルへ分割する。

### 3-1. 必須項目

```json
{
  "schemaVersion": "1.0.0",
  "code": "13123",
  "prefectureCode": "13",
  "prefecture": "東京都",
  "name": "江戸川区",
  "officialUrl": "https://www.city.edogawa.tokyo.jp/",
  "status": "researching",
  "summary": "自治体全体の概要",
  "updatedAt": "2026-07-18",
  "services": {}
}
```

必須項目：

- `schemaVersion`
- `code`
- `prefectureCode`
- `prefecture`
- `name`
- `officialUrl`
- `status`
- `summary`
- `updatedAt`
- `services`

### 3-2. 自治体コード規則

- `code`は5桁の数字文字列。
- `prefectureCode`は2桁の数字文字列。
- ファイル名は`{code}.json`と一致させる。
- 親ディレクトリ名は`prefectureCode`と一致させる。
- 同じ自治体コードを複数ファイルへ登録しない。

### 3-3. 自治体status

許可値：

- `todo`
- `researching`
- `verified`
- `unavailable`
- `needs_medium_review`
- `needs_revision`
- `needs_coordinator`
- `pr_open`
- `merged`
- `blocked`

自治体statusは9制度の状態と作業状況から進捗更新処理が算定することを原則とする。地方調査班が根拠なく`merged`へ変更してはいけない。

## 4. 制度情報スキーマ

`services`には`service-definitions.json`で定義された9制度IDをすべて含める。

```json
{
  "childMedical": {
    "status": "verified",
    "summary": "高校3年生相当まで",
    "eligibility": {
      "minAgeMonths": 0,
      "maxAgeYears": 18
    },
    "details": {
      "incomeLimit": "なし",
      "copay": "保険診療の自己負担分を助成",
      "application": "医療証の交付申請が必要"
    },
    "source": {
      "url": "https://example.jp/official",
      "checkedAt": "2026-07-18"
    },
    "additionalSources": [],
    "notes": []
  }
}
```

### 4-1. 制度必須項目

すべての制度：

- `status`
- `summary`

`verified`：

- `source.url`
- `source.checkedAt`
- 制度定義で`ageRange`の場合は`eligibility.minAgeMonths`と`eligibility.maxAgeYears`

`unavailable`：

- 制度が存在しない、または自治体が提供していないことを示す公式根拠
- `source.url`
- `source.checkedAt`

`researching`、`needs_medium_review`、`needs_revision`、`needs_coordinator`、`blocked`：

- 未完了または停止理由を`summary`または`notes`へ記録する。

### 4-2. 制度status

全体の許可statusと同じ値を受け入れる。ただし、制度単位で通常使用するのは次の8種類とする。

- `todo`
- `researching`
- `verified`
- `unavailable`
- `needs_medium_review`
- `needs_revision`
- `needs_coordinator`
- `blocked`

`pr_open`と`merged`は原則として自治体・進捗レベルで使用する。既存データとの互換性確保のため許可値には残すが、制度へ設定された場合は検証警告を出す。

### 4-3. 出典

- `source.url`は主出典となる公式HTTPS URL。
- `source.checkedAt`は実際に確認した日付を`YYYY-MM-DD`で記録する。
- 複数の公式出典が必要な場合は`additionalSources`へ同じ形式で追加する。
- 検索結果、まとめサイト、ブログ、SNSだけを主出典にしない。
- URLの到達確認と内容確認は別物として扱う。

## 5. 自治体別進捗JSON

保存先：

```text
operations/tasks/{自治体コード}.json
```

### 5-1. 必須項目

```json
{
  "schemaVersion": "1.0.0",
  "municipalityCode": "13123",
  "municipalityName": "江戸川区",
  "prefectureCode": "13",
  "prefectureName": "東京都",
  "assignedTeam": "東日本調査班",
  "status": "researching",
  "currentService": "housingSupport",
  "nextServiceIndex": 6,
  "completedServices": [
    "childMedical",
    "sickChildCare",
    "childcareFee",
    "schoolMeals",
    "postpartumCare",
    "temporaryChildcare"
  ],
  "verifiedCount": 6,
  "researchingCount": 3,
  "unavailableCount": 0,
  "needsMediumReviewCount": 0,
  "currentBranch": null,
  "pullRequestNumber": null,
  "lastCheckedAt": "2026-07-18",
  "lastUpdatedAt": "2026-07-18T22:00:00+09:00",
  "lastUpdatedBy": "編集長・全国統括",
  "officialSources": [],
  "notes": [],
  "blockers": []
}
```

憲章指定項目に加え、運用上の更新時刻として`lastUpdatedAt`を持たせる。

### 5-2. 担当班の固定対応

- 北日本調査班：01～07
- 東日本調査班：08～15、19、20
- 中日本調査班：16～18、21～30
- 西日本調査班：31～47

検証処理は`prefectureCode`と`assignedTeam`の対応を確認する。

### 5-3. 集計値

次の値は自治体調査元JSONから機械的に再計算できる状態を正とする。

- `completedServices`
- `verifiedCount`
- `researchingCount`
- `unavailableCount`
- `needsMediumReviewCount`
- `officialSources`

手入力値と再計算値が異なる場合は検証を失敗させる。

## 6. 公開用生成JSON

生成先：

```text
data/generated/municipalities.json
```

公開形式は既存`data/municipalities.json`との後方互換性を維持する。

```json
{
  "meta": {
    "version": "1.0.0",
    "updatedAt": "2026-07-18",
    "municipalityCount": 3
  },
  "municipalities": []
}
```

### 6-1. 生成規則

1. `data/municipalities/*/*.json`だけを入力にする。
2. 各ファイルを構文検証する。
3. ファイルパス、都道府県コード、自治体コードの一致を確認する。
4. 同一自治体コードの重複を拒否する。
5. 9制度IDの存在を確認する。
6. 自治体コードの昇順で並べる。
7. オブジェクトのキー順を固定する。
8. インデント2文字、末尾改行ありで出力する。
9. `meta.updatedAt`は入力自治体の`updatedAt`最大値から算定し、実行時刻を使わない。
10. 入力が同じ場合は生成物も同一にする。
11. 1件でもエラーがあれば生成物を更新せず終了コード1とする。
12. 生成件数を標準出力へ表示する。

### 6-2. 非公開情報

次は公開用JSONへ含めない。

- `currentBranch`
- `pullRequestNumber`
- 内部作業メモ
- blockersの内部詳細
- 調査担当者の個人情報
- 検索途中の民間サイトURL

## 7. 全国進捗JSON

保存先：

```text
operations/progress.json
```

`operations/tasks/*.json`と自治体調査元JSONから自動集計する。

最低限の項目：

- `schemaVersion`
- `updatedAt`
- `totalMunicipalities`
- `registeredMunicipalities`
- `todoMunicipalities`
- `researchingMunicipalities`
- `prOpenMunicipalities`
- `mergedMunicipalities`
- `blockedMunicipalities`
- `needsMediumReviewMunicipalities`
- `needsCoordinatorMunicipalities`
- `verifiedServices`
- `researchingServices`
- `unavailableServices`
- `teams`
- `stalledMunicipalities`

全国自治体総数は、将来追加する正式な自治体コード一覧を基準にする。Phase 0では登録済み3自治体の集計を作成し、総数が未確定の場合は`totalMunicipalitiesSource`へ根拠を記録する。

## 8. 検証設計

検証は次の順序で行う。

1. 共通制度定義の検証
2. 自治体調査元JSONの検証
3. 自治体別進捗JSONの検証
4. 調査元と進捗の対応検証
5. 担当班検証
6. 公開用JSON生成
7. 生成済みJSONの再検証
8. 生成物と元データの一致検証
9. JavaScript構文確認
10. 変更範囲検証

最低限検出する項目：

- JSON構文エラー
- 必須項目不足
- 自治体コード重複
- ファイル名と自治体コードの不一致
- ディレクトリ名と都道府県コードの不一致
- 自治体名または都道府県名の空欄
- 9制度ID不足または重複
- 未許可status
- `verified`なのに公式出典がない
- `unavailable`なのに公式根拠がない
- `checkedAt`形式不正
- HTTPSでない公式URL
- 自治体ファイルに対応する進捗ファイルがない
- 進捗ファイルに対応する自治体ファイルがない
- `assignedTeam`と都道府県の不一致
- 進捗集計値と実データの不一致
- generatedと元データの不一致
- 地方調査班PRで許可外ファイルが変更されている
- `jichitai-compare/`以外の変更

URLの実到達確認はネットワーク障害による誤判定を避けるため、構文検証と分離する。

## 9. package.jsonコマンド

予定コマンド：

```json
{
  "scripts": {
    "generate": "node ./scripts/generate-municipalities.mjs",
    "progress": "node ./scripts/update-progress.mjs",
    "validate": "node ./scripts/validate-data.mjs",
    "check": "npm run validate && npm run generate && npm run progress && npm run validate"
  }
}
```

生成後に差分が残る場合、GitHub Actionsでは失敗させ、生成物のコミット漏れを検出する。

## 10. app.js切替方針

変更前：

```text
./data/municipalities.json
```

変更後：

```text
./data/generated/municipalities.json
```

`service-definitions.json`の読み込みは維持する。

画面はすべてのstatusを安全に表示できるようにする。

- `verified`：確認済み
- `unavailable`：制度なし・対象外確認済み
- `todo`：未着手
- `researching`：調査中
- `needs_medium_review`：要詳細確認
- `needs_revision`：修正中
- `needs_coordinator`：統括確認中
- `blocked`：確認停止中
- `pr_open`：審査中
- `merged`：統合済み

未完了statusを`verified`相当として表示してはいけない。

## 11. GitHub Actions方針

PRおよびmain更新時に、`jichitai-compare/`の変更がある場合だけ実行する。

予定処理：

1. Node.jsセットアップ
2. `npm ci`または依存関係がない場合はNode実行環境だけを使用
3. `npm run validate`
4. `npm run generate`
5. `npm run progress`
6. `npm run validate`
7. `git diff --exit-code -- jichitai-compare/data/generated jichitai-compare/operations/progress.json`
8. `node --check jichitai-compare/app.js`
9. PRの変更範囲確認

既存GitHub Pagesの公開設定は変更しない。

## 12. 地方調査班の編集範囲

地方調査班が変更できるファイル：

```text
data/municipalities/{担当都道府県コード}/{担当自治体コード}.json
operations/tasks/{担当自治体コード}.json
```

地方調査班が変更できない主なファイル：

- `app.js`
- `index.html`
- `styles.css`
- `data/service-definitions.json`
- `data/generated/`
- `scripts/`
- `operations/progress.json`
- `operations/PARALLEL_READY`
- `.github/workflows/`
- 他自治体ファイル
- `jichitai-compare/`以外

## 13. 既存3自治体の移行方法

対象：

- 市川市（12203）
- 浦安市（12227）
- 江戸川区（13123）

移行手順：

1. 現行`data/municipalities.json`のblob SHA、meta version、自治体数、自治体コード、制度数を`operations/migration-manifest.json`へ記録する。
2. 各自治体オブジェクトを内容変更せず自治体別ファイルへ分割する。
3. `schemaVersion`と`updatedAt`だけを必要に応じて追加する。
4. 各自治体に対応する進捗JSONを作成する。
5. 新生成スクリプトから`data/generated/municipalities.json`を生成する。
6. 現行一括JSONと生成JSONについて、metaの移行用項目を除いた自治体配列を深い比較で照合する。
7. 自治体数3件、制度数各9件、公式URL、checkedAt、summary、detailsの欠落がないことを確認する。
8. `app.js`の参照先を生成JSONへ切り替える。
9. 公開確認が完了するまで現行一括JSONを削除しない。
10. Phase 0 PR内の最終検証後、旧一括JSONを削除するか、非参照の移行バックアップとして残すかを差分量とロールバック性から決定する。

原則としてGit履歴を正式なバックアップとし、公開ディレクトリへ不要な重複データを恒久的に残さない。

## 14. 後方互換性

- 生成JSONのトップレベルは既存と同じ`meta`と`municipalities`を維持する。
- 自治体オブジェクトの既存フィールド名を維持する。
- 制度の`source`形式を維持する。
- `additionalSources`や`notes`は任意項目とし、既存画面が無視できるようにする。
- `app.js`の初期変更は読込パスとstatus表示対応に限定する。

## 15. ロールバック方針

Phase 0は1本の専用ブランチとPRで管理する。

ロールバック条件：

- 生成件数が3件にならない
- 既存自治体データに欠落がある
- 検証スクリプトが失敗する
- GitHub Actionsが失敗する
- 公開サイトが自治体データを読み込めない
- 既存3自治体の表示が消える
- 他プロジェクトへ差分が発生する

ロールバック方法：

1. Phase 0 PRを統合前なら統合しない。
2. 統合後に重大障害が出た場合はPhase 0統合コミットをrevertする。
3. `app.js`の参照先を旧`data/municipalities.json`へ戻す。
4. `PARALLEL_READY`が作成済みの場合は削除または`ready: false`へ戻し、地方調査班を停止する。
5. 原因と影響範囲をIssue #10へ記録する。

強制push、履歴改変、他プロジェクトの上書きによる復旧は行わない。

## 16. Phase 0ブランチ運用

Phase 0実装ブランチ：

```text
agent/jichitai-parallel-architecture
```

このブランチで工程0-2から0-10までを積み上げ、工程0-11で専用PRを作成する。

各工程は内容が分かるコミット単位に分ける。

- 移行設計を追加
- 既存3自治体を個別ファイルへ分割
- 自治体別進捗ファイルを追加
- 公開用生成処理を追加
- 並列運用向け検証を追加
- 公開データ参照へ切替
- 自治体比較のActionsを追加
- 全国進捗集計を追加
- 移行検証を完了

## 17. 完了条件

工程0-2は、次を満たした時点で完了とする。

- 自治体調査元JSONの構造が定義されている。
- 制度情報の構造が定義されている。
- 自治体別進捗JSONの構造が定義されている。
- status許可値と用途が定義されている。
- 地方担当区分が定義されている。
- 公開用JSONの生成規則が定義されている。
- 既存3自治体の移行方法が定義されている。
- 検証、Actions、ロールバック方針が定義されている。
- 設計文書がPhase 0専用ブランチへ保存されている。

次工程は「工程0-3：既存データの分割」とする。
