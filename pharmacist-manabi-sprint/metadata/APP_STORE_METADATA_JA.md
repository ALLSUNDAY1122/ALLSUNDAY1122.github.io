# App Store Metadata｜薬剤師国家試験｜学びスプリント

## 固定値
- App Store表示名：薬剤師国家試験｜学びスプリント
- サブタイトル：国試3回分を8問ずつ反復
- Bundle ID：`jp.allsunday1122.yakuzaishi`
- Version：`1.0.0`
- Build：`1`
- SKU：`yakuzaishi-sprint-ios`
- Primary language：Japanese
- Primary category：Education
- 価格：無料ダウンロード＋App内課金
- 年齢制限：App Store Connect最新質問票へ実装どおり回答。薬剤師国試は医学・治療情報を頻繁に扱うため、iOS 26以降の現行区分では16+相当を想定し、Apple算定値を最終採用する。
- サインイン：不要
- アカウント登録：なし
- 広告：なし
- 解析SDK：なし
- 独自クラウド同期：なし
- 学習データ：端末内保存

## URL
- Support：https://allsunday1122.github.io/pharmacist-manabi-sprint/support.html
- Privacy：https://allsunday1122.github.io/pharmacist-manabi-sprint/privacy.html
- Terms：https://allsunday1122.github.io/pharmacist-manabi-sprint/terms.html

## 課金
### 月額
- 種別：Auto-Renewable Subscription
- Product ID：`jp.allsunday1122.yakuzaishi.monthly`
- 期間：1か月
- 日本価格方針：200円相当（実表示はStoreKit `displayPrice`）
- Introductory Offer：Free Trial / 1 Week
- アプリ内で「7日間無料」を表示する条件：StoreKitがIntroductory Offer設定済みかつ当該利用者がeligibleと返した場合のみ

### 買い切り
- 種別：Non-Consumable
- Product ID：`jp.allsunday1122.yakuzaishi.lifetime`
- 日本価格方針：980円相当（実表示はStoreKit `displayPrice`）
- 利用期限：なし

## 無料範囲
- 第111回 必須90問
- 今日のスプリント 4／8／16問
- 基本の苦手・中断復帰・学習記録

## プレミアム範囲
- 第111・110・109回の採点対象1,031問
- 理論・実践・過去回
- 3回×必須・理論・実践＝9区分の模試
- 全問題を対象とする弱点学習

## 説明文
薬剤師国家試験の大きな問題量を、毎日4・8・16問の短い反復へ分けて学ぶ試験対策アプリです。

第111回・第110回・第109回の直近3回を収録。公式の正答・訂正・「解なし」・特殊採点を問題単位で監査し、間違えた問題は苦手へ自動で戻します。3回連続で正解すると苦手から卒業します。

主な機能：
- 標準8問の短時間スプリント（4／8／16問に変更可能）
- 必須・理論・実践を試験回別に演習
- 模擬試験
- 苦手の自動記録
- 分野別の着手進捗
- 5週間の学習ヒートマップ
- 試験日カウントダウン
- 学習データの書き出し・読み込み
- オフライン学習

厚生労働省が公開する薬剤師国家試験資料を出典として利用し、学習表示・解説は加工して作成しています。本アプリは厚生労働省の公式アプリではありません。また、本アプリは試験学習用であり、診断・治療・調剤・服薬指導等の医療上の判断を提供するものではありません。

## キーワード候補
薬剤師,薬剤師国家試験,国試,薬学,過去問,必須,理論,実践,資格,学習

## App Reviewメモ
- サインイン不要、アカウント登録なし、広告・解析なし。
- 第111回必須90問は購入せず利用可能。
- プレミアムはApple StoreKit 2のみ。外部決済導線なし。
- 購入画面にはStoreKitから取得した価格だけを表示。
- 月額の無料トライアル文言はStoreKitが設定済みかつ利用資格ありと返した場合のみ表示。
- 「購入を復元」は利用者操作時のみ`AppStore.sync()`を実行。
- 第111・110・109回の公式問題資料を出典として利用。第三者由来が確認された図表は原図を使用せず文章問題へ再構成済み。
- 1,035レコードのうち公式「解なし」4問は履歴参照用に保持し通常採点から除外。通常採点対象は1,031問。
- 端末内へ教材を同梱するため、学習本体はオフライン利用可能。
- 本体は単なるWebサイト表示ではなく、ローカル教材・学習状態・弱点復習・模試・StoreKit権利管理をiOSアプリ内で提供する。
