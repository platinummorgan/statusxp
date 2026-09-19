# Batch 14 — SX-015 store ownership and subscription periods

Implemented locally on September 12, 2026. No deployment or live store purchases. SX-015 remains in progress.

The iOS purchase request previously omitted the app-account UUID, and Apple verification did not check the returned account claim. The client now supplies its app user UUID and the verifier rejects mismatched Apple account tokens. Google retains its SHA-256 account identifier and now uses the same explicit missing/mismatched-claim policy for subscriptions.

New subscription bindings use Apple's original transaction ID or a digest of Google's purchase token, separated by test/production environment. Raw Google purchase tokens are not stored. Verified Google replacement tokens reserve ownership of both the new and linked token. Ownership survives account deletion as an unassignable tombstone. First-time binding requires a matching store account claim; a missing claim is accepted only when the same subscription or its verified linked predecessor is already bound to that app user. Consumable delivery keeps its existing transaction-level binding and replay behavior.

Each verified subscription transaction retains its own period in `store_purchase_events`, with a binding key and verification time. Renewals cannot move a subscription to another app account. Re-verification can update a period's expiry; an older in-flight lookup cannot overwrite a newer observation. An older restored period cannot shorten another valid renewal period. Google uses the matching line item's latest successful order ID when available.

The common effective-premium lookup now includes bound Apple/Google periods alongside Stripe and Twitch, so store fulfillment no longer blindly overwrites other valid coverage. Expired or non-entitled period states cannot be revived by a stale legacy store projection. These decisions also drive AI credits and provider quota admission. The new migration leaves historical unbound events untouched.

Validation:

- [PostgreSQL fixture](../../../supabase/functions/verify-store-purchase/entitlement_test.sql) passed migration reapplication, missing-proof rejection, immutable renewal ownership, repeat delivery, ordered verification updates, overlapping periods, Google replacement ownership, expiry, permissions, deletion tombstones, and consumable replay. It also runs prior Stripe/Twitch/AI/quota fixtures. [Evidence](implementation-14-postgres.txt).
- [Independent-connection test](../../../supabase/functions/verify-store-purchase/entitlement_concurrency_test.cjs) verified that competing owners produce one binding and one fulfilled period.
- Five Deno identity/expiry tests and the verification entrypoint type check passed.
- Flutter analysis: no issues. Full native suite: 77 passed, nine web-only tests skipped. No iOS device purchase, store sandbox lifecycle, browser, or release build repeated.

The fixture directly changes period state to simulate revocation and verify the lookup. **No Apple notification or Google RTDN ingestion is implemented in this batch.** The purchase verifier still accepts currently entitled purchases only; refunds, holds, and other negative lifecycle transitions require the upcoming notification/reconciliation work. A hash alone cannot retrieve a Google purchase; scheduled reconciliation will need a reviewed private token storage strategy or authenticated provider notifications carrying the token.

Deployment prerequisites: inspect the live schema/function definitions and apply the secure-store migration and prior batches through batch 13 before `20260912120000_store_subscription_bindings.sql`. Coordinate the new verification function with this migration and the iOS client release. The old verifier does not supply the required subscription metadata. Follow manual migration policy; do not run `supabase db push --linked`.

Older iOS purchases may have no app-account token because the old client sent none. Unbound subscriptions without proof will require independently verified ownership reconciliation before restore/renewal fulfillment; do not silently infer ownership from a client-supplied transaction ID or bulk-bind historical rows. Existing legacy premium projections remain until expiry or replacement by bound source records. Review historical overlapping subscriptions and test-environment policy before cutover. Current sandbox entitlement behavior is preserved, not newly restricted here.

Remaining SX-015 work: authenticated Apple/Google lifecycle ingestion, durable negative-state/revocation handling, renewal scheduling, legacy reconciliation, and full live purchase/renewal/cancellation/refund/grace/restore/account-binding verification.

Provider references checked September 12, 2026: Apple's [appAccountToken](https://developer.apple.com/documentation/appstoreserverapi/appaccounttoken) and [originalTransactionId](https://developer.apple.com/documentation/appstoreserverapi/originaltransactionid), and Google's [SubscriptionPurchaseV2](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2). The installed `in_app_purchase_storekit` 0.4.11 Dart and Swift sources also confirm that `applicationUserName` reaches StoreKit's app-account token option.
