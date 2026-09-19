# Premium entitlement production audit — September 14, 2026

## Result
Confirmed production billing handlers can change the single account-wide premium record without evaluating every active provider. This is a cross-provider access defect. The investigation does **not** establish that Twitch overwrote this owner's Google subscription.

## Evidence collected read-only
- The owner's store_purchase_events query returned no rows. Google Play subscription status itself was not queried: no verified transaction/token is recorded for this account in the available ledger.
- Live REST schema exposes user_premium_status and store_purchase_events. It does not expose store_subscription_bindings, twitch_account_bindings, stripe_customers, or get_my_premium_entitlement. Direct probes for those tables returned PGRST205. Thus the newer entitlement implementation in the repository is not available through the live API.
- Deployed function inventory: twitch-eventsub-webhook v20; twitch-check-subscription v13; twitch-backfill-subscribers v9; stripe-webhook v45; verify-store-purchase v1. Google/Apple notification handlers and premium reconciliation were absent from the deployed inventory.
- Downloaded the deployed sources into D:/.tmp/statusxp-premium-audit-20260914 using the Supabase Management API. Local project functions were not overwritten.
- Deployed stripe-webhook subscription updates change is_premium by user ID alone (around lines 151–160). Cancellation sets is_premium=false and expires premium by user ID alone (around lines 194–201), without checking another active provider or a developer grant.
- Deployed twitch-check-subscription grants upsert a single premium_source=twitch row; revoke logic checks only the current source. Its writes use expires_at, but the actual column is premium_expires_at. The deployed Twitch webhook has the same column mismatch, including its protective read, whose error is ignored. These mismatches can cause failed access updates; they are not evidence of a successful historical overwrite.
- Deployed Twitch backfill uses the correct premium_expires_at column but only preserves existing apple/google/stripe sources. It does not preserve developer grants. It also uses a source hierarchy rather than independently retained subscriptions.
- Deployed verify-store-purchase calls fulfill_verified_store_purchase. Its function body was not retrieved, so the local migration body is not asserted to be the live definition.
- The owner's pre-correction projection had is_premium=true, source=twitch, expiry March 14, 2026; updated_at was February 9, 2026. There is no per-provider history in this projection to establish what it replaced. The prior explicit owner-authorized correction set source=developer with no expiry and was independently verified. No further production mutation occurred during this audit.

## Owner/admin access
The application source has no implemented application-wide owner/admin role. The app_updates policy uses the backend service role, not an end-user admin role. The developer premium projection enables features but is not equivalent to administrative permissions or protection against subsequent billing writes. Do not assign a backend service-role credential to a browser session or claim a metadata flag provides permissions that policies do not implement.

## Required repair and rollout
1. Preserve provider subscriptions independently, tied to the authenticated StatusXP account. Effective premium is true when ANY verified provider is active; there is no provider priority for access.
2. Keep permanent owner/developer grants in a separate server-controlled record. Billing handlers cannot revoke or replace those grants. Add an explicit owner/admin authorization model for privileged application operations as those operations are defined.
3. Reconcile the live schema with the existing source-specific migrations and verified handlers. Review their dependencies and compatibility before staging; do not blindly deploy the entire migration directory.
4. Replace every legacy writer (Twitch checks, webhook, backfill; Stripe updates/cancellations; store verification) with source-specific updates followed by shared entitlement calculation. Retire legacy endpoints during coordinated rollout.
5. Test active Google + expired Twitch, active Twitch + expired Google, active Apple + canceled Stripe, multiple same-provider subscriptions, expired all, delayed/replayed events, identity binding, and owner grant + every billing event. Assert the same effective result for web, iOS and Android consumers.
6. Confirm the owner's Google purchase in Play Console or via a restored verified purchase linked to this StatusXP account. An empty app ledger does not prove the store subscription is inactive. Do not charge again to diagnose it.
7. Deploy the reviewed server/client change and verify real signed-in access across platforms. This audit did not deploy billing handlers or apply schema migrations.

## Repair progress — September 14
- Applied only 20260914120000_protected_app_access and 20260914121000_sync_app_access_grants to production, manually in bounded transactions, and recorded both versions in the migration ledger. No bulk migration push was used.
- Created a server-controlled app_access_grants owner record for the user-identified account. Billing projection inserts/updates preserve its non-expiring premium. Grant creation/revocation synchronizes the projection; ordinary users cannot read/write the grants table or self-promote.
- Added explicit owner/admin authorization for app_updates management. The updated shared Edge admin gate supports verified protected grants alongside the existing server allowlist. Deployed get-users with this gate; other administrative endpoints are not claimed to have been redeployed or verified.
- Corrected the earlier admin finding: newer server code already had an optional STATUSXP_ADMIN_USER_IDS allowlist. It lacked the durable protected grant implemented here; there is still no general-purpose admin dashboard.
- Verified the owner's role, premium status, null expiry and server-side admin result from the live database. No production billing events were replayed as tests.
- Local PostgreSQL combined entitlement fixtures passed (Stripe, Twitch, verified store binding, Google and Apple lifecycle fixtures). Added cross-provider tests: expired Twitch + active Google; expired Google + active Twitch; canceled Stripe + active Apple; no active providers; owner grant preserved across legacy writes; self-promotion denied; owner changelog access/ordinary user denial; explicit grant revocation/reactivation/deletion.
- Admin handler tests: 17 passed, including verified protected owner, ordinary user denial, invalid authentication and lookup failure. get-users Deno type check passed before deployment.
- Public Apple listing and Apple lookup API identify StatusXP as app 6757080961, bundle com.statusxp.statusxp, seller Michael Dorminey. Configured APPLE_APP_STORE_APP_ID in live Supabase. Sources: https://apps.apple.com/us/app/statusxp/id6757080961 and https://itunes.apple.com/lookup?id=6757080961.

## Still required for account-wide subscription rollout
The protected owner fix is live. The general cross-provider billing repair is **not** deployed. Legacy Stripe/Twitch writers still need coordinated replacement; do not represent the local fixture results as live billing validation.

Missing production configuration includes GOOGLE_PLAY_PUSH_SERVICE_ACCOUNT_EMAIL, GOOGLE_PLAY_PUSH_AUDIENCE, GOOGLE_PLAY_PUBSUB_SUBSCRIPTION; Google token vault keys; APPLE_APP_STORE_ISSUER_ID, APPLE_APP_STORE_KEY_ID, APPLE_APP_STORE_PRIVATE_KEY. The Google verification service account already exists as a Supabase secret. Generate token encryption keys securely during setup; obtain Apple credentials through an approved local/server secret channel, never in chat or committed files.

User will retrieve the Google Cloud project details. Apple app ID was found independently, so the user need not retrieve it. Google Console project selector shows Project ID; use the project associated with Play billing/notification configuration: https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects.

Next: configure verified notifications and reconciliation, inventory/backfill existing subscription identities (including the owner's missing Google ledger record), reconcile and stage the existing migration dependency chain (AI reservations/quota helpers, Stripe fulfillment, Twitch receipts/bindings, store bindings, Google/Apple state, reconciliation queues), then deploy coordinated handlers and client verification. Do not deploy latest store verification against an incompatible schema or without Apple credentials. Older store clients' ownership-claim compatibility must be verified before cutover.

### Google project identified
Read-only gcloud inventory found two projects named StatusXP. Project statusxp (number 99712650730) contains statusxp-play-verifier@statusxp.iam.gserviceaccount.com and has androidpublisher.googleapis.com and pubsub.googleapis.com enabled. Project utility-trees-474818-u2 (number 395832690159) returned no service accounts or matching enabled APIs. Use statusxp for the Play notification setup. This identifies the configured Cloud resources; the contents of the Supabase service-account secret were not retrieved or compared. No Pub/Sub topics were returned for statusxp at inspection time.

## Superseding rollout update
The previously pending billing server rollout is now deployed. See PREMIUM_ROLLOUT.md for exact migrations, deployed handlers, preserved legacy membership results, tests, and remaining store-console/real-purchase validation. Earlier investigation findings describe the pre-rollout deployment; they do not describe the replacement handlers.
