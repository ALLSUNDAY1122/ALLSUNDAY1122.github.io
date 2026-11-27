# Supabase backend — 園プリント見落としガード

- Project: `enprint-guard-prod`
- Project ref: `qwvdrxkuongnevupxywp`
- Region: `ap-northeast-1`
- Storage bucket: `enprint-documents` (private, 10 MiB, household-folder scoped)
- Edge Function: `extract-print-tasks` (JWT verification enabled)
- AI model configured in function: `gpt-6-luna`
- AI input: Apple Vision OCR text only; the original image is not sent to OpenAI.
- Responses API uses `store: false`, strict JSON schema, max 1,400 output tokens.
- Global server-side quota: maximum 1,000 analyses per calendar month (atomic reservation).
- `OPENAI_API_KEY` is read only from Edge Function environment; never commit it or place it in the iOS app.
- API quota reservation is global across all households and capped at 1,000 requests per calendar month; failed attempts count toward the cap.

## Applied database design
- Households and household_members
- Children, documents, tasks
- Single-use, 7-day hashed household invites
- AI usage logs (token counts, model, status)
- RLS for all app tables and private storage
- Household-scoped composite foreign keys
- Authenticated-only SECURITY DEFINER RPCs for household creation/invite acceptance
- Helper functions moved to non-exposed `private` schema

## Secret setup (owner action)
Open [Edge Function Secrets](https://supabase.com/dashboard/project/qwvdrxkuongnevupxywp/functions/secrets) and add:
- Name: `OPENAI_API_KEY`
- Value: your OpenAI API key

Do not put the key in GitHub, source code, App Store Connect, or this chat. The secret is not yet configured. The deployed function returns HTTP 503 until it exists.

## Cost gate
OpenAI API calls are metered separately from ChatGPT and Supabase. No OpenAI requests have been sent by this app yet. The function reserves no more than 1,000 calls per calendar month; with 16,000 OCR characters and 1,400 output tokens per call, conservative token-cost estimate is about US$2.75/month if 3 input tokens per character are assumed. Actual cost should usually be lower. Do not configure the secret or enable AI calls until the owner approves a monthly spending limit. Current selected model: `gpt-6-luna`; the current Standard rate is US$0.05 per 1M input tokens and US$0.25 per 1M output tokens. At the 16,000-character input limit, 1,400 output tokens and a conservative 3 input tokens per character, 1,000 calls are approximately US$2.80/month before taxes and exchange-rate changes. Actual usage should normally be lower. See official pricing: https://developers.openai.com/api/docs/pricing.

## Supabase Auth redirect allowlist
In Authentication > URL Configuration, add the following exact Redirect URL:
`enprintguard://login-callback`
The app uses an email magic link; the app must be installed on the device that opens the link.
