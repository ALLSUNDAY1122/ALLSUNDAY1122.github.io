# MOI-SEP-002 — Commercial separator fast-track options

Captured: 2026-08-22 JST
Purpose: reduce the current trained-weight/data-acquisition critical path without weakening the commercial-rights or Golden QA gates.

This note is procurement/technical evidence only. It does not authorize a vendor, create an account, accept terms, spend money, or promote PARITY.

## Preferred evaluation fast-track: AudioShake API

Official developer material captured on 2026-08-22 states:
- production source-separation API is available to developers;
- developers building karaoke, remix, practice and audio applications are an intended audience;
- new accounts receive 10 credits to start building;
- the API supports asynchronous processing;
- instrument models include `vocals`, `drums`, `bass`, `other`, guitar families, keys/piano, strings and winds;
- vocals/drums/bass/other are each listed at 1 credit per processed audio minute;
- AudioShake states its models are trained on licensed data;
- API/SDK technology can be licensed into partner technology.

Official sources:
- https://developer.audioshake.ai/
- https://developer.audioshake.ai/models
- https://developer.audioshake.ai/separate-stems
- https://www.audioshake.ai/audioshake-partners-integrations-api-sdk-stems-transcription

### Why it fits the current boundary

The project's current client provider already models an asynchronous remote job with stable progress/failure/result semantics. A vendor backend adapter can map AudioShake tasks/results into that internal API without exposing vendor IDs or secrets through HQ Shared contracts.

A 4-target request (vocals/drums/bass/other) consumes 4 credits per source minute under the currently documented model-credit table. The 10-credit signup allocation is therefore enough only for a short technical smoke test, not the required full Golden corpus.

### Human/procurement gates before use

Before the project sends user or QA audio to AudioShake:
1. create/approve the vendor account and API key outside GitHub;
2. confirm the exact commercial embedding/production agreement for the intended app, not only trial access;
3. confirm input retention/deletion, regional processing, confidentiality and output-use terms;
4. confirm forecast pricing/credits for 12+ G1/G2 tracks and later long-track tests;
5. place credentials in a secret manager/runtime environment, never app source or GitHub.

A trial/API key may prove technical compatibility but does not by itself prove production commercial clearance.

## Secondary fast-track: LALAL.AI API/business solution

Official material captured on 2026-08-22 states:
- Business Solution offers API integration for applications/services with server-side splitting;
- Business Enterprise pricing is custom and API integration is included;
- a business trial is advertised with 30 minutes but the business comparison page marks API integration support as unavailable for that trial tier;
- the consumer Pro plan currently lists API Access at USD 19.99 month-to-month or USD 180/year (USD 15/month effective), but consumer/API access must not be assumed equivalent to a commercial white-label production grant;
- Enterprise supports audio/video inputs and custom high-volume arrangements.

Official sources:
- https://www.lalal.ai/business-solutions/
- https://www.lalal.ai/pricing/
- https://www.lalal.ai/guides/faq/

### Human/procurement gates before use

The same commercial/privacy/output-rights review is required. For product shipping, prefer written Business/Enterprise terms rather than inferring commercial embedding rights from consumer Pro API access.

## Project-owned training route remains valid

If vendor terms/cost/privacy are unacceptable, the verified canonical route remains:
- Demucs/HTDemucs-class permissive code;
- random/project-controlled initialization;
- rights-cleared real multitracks with explicit ML-training and commercial resulting-weight rights;
- project-owned checkpoint and model/training manifests;
- server inference first;
- Golden G1/G2 differential validation before any P003/P004 promotion.

This route has a longer critical path because the verified licensing audit identifies rights-cleared real multitrack acquisition and iterative model training as the dominant schedule/cost risk.

## Recommendation

For the next unblock decision, evaluate AudioShake first because the current public developer surface directly exposes the required four core stems and async production API. Use it initially only as a technical/quality candidate. Production selection must wait for written commercial/privacy terms and Golden A/B evidence.

Regardless of vendor or project-owned model, `MOI-P003`/`MOI-P004` remain MISSING until real multi-genre outputs, objective/listening quality, latency and recovery gates are actually measured.
