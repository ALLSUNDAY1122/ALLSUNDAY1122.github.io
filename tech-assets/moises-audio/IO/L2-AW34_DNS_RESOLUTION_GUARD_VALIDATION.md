# L2-AW34 DNS Resolution Guard Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 IO only. AW14 already rejected literal localhost/private IP URLs, credentials, insecure redirects, excessive redirects and unbounded downloads. The remaining pre-connect gap was a public-looking hostname that resolved to loopback/private/link-local/reserved addresses, including redirect destinations.

AW34 adds a DNS resolution guard to the canonical public/direct URL importer route. It does not claim complete DNS-rebinding elimination because URLSession performs its own later connection resolution.

## Fresh canonical state

- Notion canonical: v4 autonomous lanes / late integration unchanged.
- Worker contract SHA: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`.
- Work Package SHA: `aad7983bdaf315a996dce1496ed245008085c712`.
- Lane Plan SHA: `10b595b47e5a71278bde32e8656bd284e14e62eb`.
- Resource Lock SHA: `55b0056b5563c64515ddc74abd448c545c7c0bb4`, integration epoch 22, assignment epoch 2.
- Worker-2 prior status blob: `f66454261ef04a003040e7da14ed4018d18739f2` at AW33 status commit `8abc7c97600168732cc6f9cd9bb5e81249bcc656`.
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`.
- Worker branch matched AW33 status commit exactly before AW34.

## Production behavior

### DNS resolution guard

`IOSystemHostResolver` uses `getaddrinfo` and numeric `getnameinfo` results. `IOPublicHostResolutionPolicy` fails closed if any returned address is not considered globally routable.

Blocked IPv4 classes include loopback, unspecified, RFC1918, carrier-grade NAT, link-local, benchmark, documentation, multicast and reserved ranges. IPv6 blocks unspecified, loopback, link-local, unique-local, multicast, documentation space and IPv4-mapped addresses whose embedded IPv4 is blocked.

A mixed DNS answer such as one public address plus one private address is rejected because URLSession may choose any answer.

### Initial request and redirects

`IOResolutionGuardedDirectDownloadTransport` keeps the AW14 byte, response, redirect, cancellation, staging and storage-pressure protections and adds resolution checks:

1. original URL passes existing syntactic/local-literal policy;
2. original hostname is resolved and all answers must be public before the URLSession task starts;
3. every HTTP redirect passes existing redirect policy;
4. the redirect destination hostname is resolved and all answers must be public before `completionHandler(request)` permits the redirect.

The standard production initializer of `IOBoundedRemoteAudioImporter` now constructs `IOResolutionGuardedDirectDownloadTransport`. The explicit downloader-injection initializer remains for tests/admin composition and can bypass this guard if the caller deliberately supplies another downloader; it is not the approved App production route.

### Remaining DNS rebinding boundary

The guard is a pre-connect resolution check. URLSession may resolve the same hostname again after validation. Therefore a hostile authoritative DNS server could theoretically return a public address to the guard and a private address to the later URLSession lookup. AW34 reduces ordinary SSRF/private-resolution exposure but does not claim this TOCTOU solved. Final closure requires Apple networking evidence and either endpoint verification or connection pinning to the validated address set.

## Validation

Portable resolver/policy core compiled with Swift 6.2.1 using strict concurrency and warnings-as-errors after correcting Linux `ai_protocol` typing and Swift 6.2 deprecated C-string construction.

Executable result:

`L2_AW34_SELF_TEST_PASS public=3 blocked=17 mixed_dns_rejected=true hostname_private_resolution_rejected=true`

Covered examples include public IPv4/IPv6, loopback, private, CGNAT, link-local, benchmark, multicast, IPv6 ULA/link-local/multicast/documentation and IPv4-mapped private addresses.

Prepared XCTest regression:

- `IO/Tests/IOResolutionGuardTests.swift`

Committed blobs:

- `IOResolutionGuardedDirectDownloadTransport.swift`: `f10e1c5ca6108b169c1abcd3228e0509f2876d1d`
- `IOBoundedRemoteAudioImporter.swift`: `c737bf91d6fe5e926a6dd9b5042693dfaa0a948d`
- `IOResolutionGuardTests.swift`: `40468c2bdf58302225eeedcc3425eeca9baa3791`
- `L2AW34ResolutionGuardSelfCheck.swift`: `da23a2938a3a54de93c389fefc5bce81ddafb24f`

Static audit:

`L2_AW34_STATIC_AUDIT_PASS checks=20/20`

Audit points included standard importer wiring, initial DNS check before task resume, redirect DNS check before redirect approval, mixed-answer rejection, IPv4-mapped IPv6 handling, existing literal-host policy retention, HTTPS downgrade rejection retention, redirect limit retention, response/media/size/storage validation retention, cancellation cleanup, staging-size verification, no Shared/App/PARITY change and explicit TOCTOU non-claim.

## AW34 commits before Evidence

1. `e261e907564c9ef1d93b3d0ce352bbc1a3977759` — add resolution-guarded transport
2. `6229f4c1743c152759f342347d7ea646d8fb1a17` — route standard importer through guarded transport
3. `66d6f11a65eb26e3d422b1a5d001e418d42867f9` — DNS guard regression tests
4. `5da213d27c91e66a515978eb6cb92c10e010f83e` — portable self-check
5. `23fba73eccb25f8045d076112387514b8c9f3d4c` — portable resolver compile fixes

## Remaining gates

- DNS rebinding between preflight resolution and URLSession's own connection resolution is not proven closed.
- Real Apple URLSession redirect callbacks, IPv6 behavior, captive-network/proxy behavior and endpoint evidence are pending.
- Public URL import reference support and current-Moises behavioral parity still require HQ reference evidence.
- Real codec/media fixtures and user-visible failure UX remain pending.
- The custom downloader injection initializer can bypass the guard and is not approved for App production.

## PARITY

No PARITY row is promoted. MOI-P002 remains MISSING until reference-supported routes and real iPhone behavior are validated by HQ.
