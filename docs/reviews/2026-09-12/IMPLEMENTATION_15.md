# Batch 15 — SX-015 Google Play subscription notifications

Implemented locally on September 12, 2026. No function deployment, Google configuration change, live purchase, refund, or account mutation. SX-015 remains in progress.

`google-play-notifications` authenticates Pub/Sub push using Google's RSA signature, issuer, expiry, expected audience, verified service-account email, and exact configured Pub/Sub subscription. The handler also checks the package and limits request bodies. Supabase JWT verification is disabled only for this new endpoint, whose handler requires Google authentication.

Subscription and subscription-void notifications fetch current state from the Play Developer API. Notification type and delivery time do not directly grant or revoke access. Test notifications record a receipt without fetching Play. Acknowledgement follows the atomic database commit. Completed duplicates skip the API lookup; simultaneous duplicates can each fetch current state but commit one receipt. Provider/database failures return a retryable non-success response. Only hashes/digests and state are persisted, not notification bodies, raw purchase tokens, or bearer tokens.

Google now has a current-state record per token digest. Active, grace-period, and canceled-but-unexpired subscriptions retain access. Hold, pause, pending, and expiry states do not. Google's revocation transition is reflected by the API's expired state. State supersedes older purchase periods and stale legacy projections. Other valid providers retain access through the shared premium lookup, AI badge/reservation, and quota decisions.

Mobile purchase verification updates the same state through a database trigger. Verification start times order the observations; an older in-flight lookup cannot restore access after a newer expiry/hold. Completed replacements permanently retire the old token's coverage, so later old-token notifications cannot restore it. Pending replacements do not retire the old token. The existing immutable bindings and account-claim checks apply to known and linked owners. A notification without a verified owner records state without inventing an account binding; a later verified purchase can establish ownership.

Google API access and the JWT signing helpers were extracted from the purchase verifier for reuse. Google token exchange and API fetch now each have a ten-second timeout. Both Apple EC and Google RSA signing paths were tested after extraction.

Validation:

- Sixteen Deno tests passed: real JWT signature/claim validation, envelope/package checks, replay, size limits, API/commit failures, notification parsing, negative states, store identities/expiry, and shared JWT signing. Both affected Edge entrypoints type-check.
- [PostgreSQL fixture](../../../supabase/functions/google-play-notifications/entitlement_test.sql) passed migration reapplication, receipt atomicity/conflicts, hold, recovery, grace, cancellation, expiry, provider fallback, replacement retirement, unbound ownership, and mobile/push ordering. It also runs the prior combined entitlement fixtures. [Evidence](implementation-15-postgres.txt).
- [Independent-connection test](../../../supabase/functions/google-play-notifications/concurrency_test.cjs) delivered duplicate expiry notifications alongside an older mobile verification: one receipt, no restored Google coverage.
- Flutter files were unchanged; Flutter/browser/device suites and release builds were not repeated. Google sandbox/live delivery and real signing-key rotation remain unverified.

Manual deployment prerequisites: reconcile the live schema and apply prior batches through batch 14 before `20260912130000_google_play_notifications.sql`. Deploy the new endpoint and the purchase verifier with its extracted shared helpers. Follow the manual migration policy; do not use `supabase db push --linked`.

Required server configuration (names only; no values recorded):

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` with the existing Play API access.
- `GOOGLE_PLAY_PUSH_SERVICE_ACCOUNT_EMAIL`: the configured authenticated-push service account.
- `GOOGLE_PLAY_PUSH_AUDIENCE`: the exact expected OIDC audience.
- `GOOGLE_PLAY_PUBSUB_SUBSCRIPTION`: the full `projects/.../subscriptions/...` subscription name.
- Existing Supabase URL/service-role key.

Configure authenticated push and the Play subscription notification topic only after the endpoint/database are ready. Verify a signed test notification, renewal, hold/recovery, cancellation, and revoked subscription in the sandbox before cutover. Configure retries and a dead-letter destination with operational monitoring. Consumable notifications/refunds and pending refund-review actions are not implemented here and return 422 rather than being silently acknowledged. A voided subscription notification reconciles current access; a refund that does not revoke coverage is not treated as automatic revocation.

Legacy ownership reconciliation from batch 14 remains necessary: notifications alone do not associate unknown token digests with an app account. Google API failures, including tokens no longer queryable, remain retryable and need dead-letter handling. No raw token storage or periodic reconciliation schedule has been added.

Remaining SX-015 work: Apple server notifications, scheduled renewal/missed-event reconciliation, consumable refund handling, legacy cutover, and the full live lifecycle/device matrix. Do not mark SX-015 complete based on these local checks.

Provider references checked September 12, 2026: [Pub/Sub push authentication](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions), [RTDN reference](https://developer.android.com/google/play/billing/rtdn-reference), [subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions), and [replacement-token security guidance](https://developer.android.com/google/play/billing/security). JWT verification uses pinned `jose` 6.1.0 and its [official verification API](https://github.com/panva/jose/blob/main/docs/jwt/verify/functions/jwtVerify.md).
