# 星詠み Next.js MVP v0.2

独立した開発ブランチに配置。無料の3診断とStripeテストモードの決済コードを含む。

## 起動
npm install && npm run build && npm run dev

## 必要な環境変数
.env.example参照。Stripeのsk_test_キー、署名用Webhook secret、専用SupabaseのURL/secretをVercelの環境変数に登録する。実値をGitHubにコミットしない。

## DB
supabase/schema.sqlを専用プロジェクトで適用。public.fortune_ordersはRLSが有効でanon/authenticatedには権限なし。

## Stripeテスト
Webhook endpoint: /api/stripe/webhook。checkout.session.completed を購読。未設定の間POST /api/checkoutは503を返す。カード情報はStripe Checkoutが処理する。

## 要注意
実決済は実装・承認しない。特商法、利用規約、商品価値の妥当性は本番移行前に別途確認する。GitHub上のこのブランチはmainに未反映。
