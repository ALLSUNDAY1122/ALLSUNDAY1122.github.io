# Pitari review asset bridge

Only App 6795941132 / jp.allsunday.pitariresize / iOS 1.0 / Build 12 is supported.
No builds, prices, purchase behavior or unrelated app metadata are changed.

The workflow reads automation/pitari-review-command.json on a main-branch push.
Supported actions: reserve_assets, complete_assets, audit, remove_failed_screenshots.
Every action first verifies app/bundle/version/build/review-detail/localization ownership.

reserve_assets uses the official Apple reserve endpoint. Apple upload operations are
AES-256-GCM encrypted with an ephemeral key, which is RSA-OAEP-SHA256 wrapped for the
task's public RSA key (3072 bits or larger). Only sanitized metadata and ciphertext
are committed. The private key and media stay on the authorized local machine.
No plaintext signed upload URLs, Apple JWTs or private contacts are logged/artifacted.

The local client decrypts instructions in memory, validates Apple HTTPS hosts and
exact, nonoverlapping byte ranges, and sends the original bytes using Apple's method
and request headers. Complete with uploaded=true and sourceFileChecksum (MD5), then
read assetDeliveryState until COMPLETE. A reservation or HTTP upload success alone
is not completion.

Existing matching filename/size reservations are reused. No automatic POST retry is
performed after an uncertain result. remove_failed_screenshots can remove only the
two recorded FAILED screenshots in the known Pitari set, and only after the real
Build 12 replacement is COMPLETE.

Review submission is a separate, explicitly authorized operation after the required
privacy, notes, contact, IAP and asset checks. WAITING_FOR_REVIEW readback is required.

Official references:
- https://developer.apple.com/documentation/appstoreconnectapi/uploading-assets-to-app-store-connect
- https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appstorereviewattachments
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip

Validated locally: syntax plus encryption/decryption round trip, wrong-app fail-closed
behavior, asset-ownership rejection, and protection against removing failed images
before the replacement reaches COMPLETE.
