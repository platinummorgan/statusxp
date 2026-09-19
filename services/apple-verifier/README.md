# Private Apple verification service

Deployed September 15, 2026 to Railway's existing StatusXP production project as `statusxp-apple-verifier`: `https://statusxp-apple-verifier-production.up.railway.app`. Apple reported successful fresh Production and Sandbox test delivery through Supabase; both matching receipts were confirmed. The service uses a dedicated secret configured in Railway and Supabase. Root workspace Railway CLI remains linked to the original sync service, so always target the verifier explicitly when deploying.

Redeploy from the repository root with `railway up services/apple-verifier --path-as-root --service statusxp-apple-verifier --environment production --project 423a981d-0826-42d4-b995-a7a53cfc6b21`. Do not upload the repository root or the sync-service folder to this service. Deployment does not depend on a GitHub branch merge.

Runs Apple's pinned official server library on Node 22. The hosted Supabase runtime lacks required X509 APIs. This service verifies notification, transaction and renewal JWS values, including certificate chains, pinned Apple roots, online revocation checks, app identity and environment. It has no database access and does not change subscriptions.

## Run and test

`npm ci` then `npm test`. Set `APPLE_VERIFIER_SECRET` to a random value of at least 32 characters and run `npm start`. `PORT` defaults to 8080. The Docker image runs as the non-root node user.

`GET /health` returns only readiness. `POST /verify` requires the dedicated bearer secret and a JSON body with `kind` (notification/transaction/renewal), boolean `sandbox`, and `signedPayload`. The request cannot override trust roots, app ID, bundle ID or online checks. No payloads or credentials are logged. Host only behind HTTPS; no browser/client should receive this secret.

Optional live test: set `APPLE_TEST_PAYLOAD_DIR` to an external directory containing `production_apple_test_jws.txt` and `sandbox_apple_test_jws.txt`, both obtained from Apple's test API, then run `npm test`. Do not commit signed payloads.

## Deployment order

1. Deploy this folder as a separate Node service (Dockerfile build context is this folder), with a new dedicated random `APPLE_VERIFIER_SECRET`. Keep the existing sync service unchanged.
2. Verify unauthorized calls fail and authorized Apple TEST messages pass.
3. Set Supabase `APPLE_VERIFIER_URL` to the HTTPS origin with no path and `APPLE_VERIFIER_SECRET` to the matching secret, using protected environment configuration.
4. Deploy `apple-store-notifications`, `verify-store-purchase` and `reconcile-premium-entitlements` together. Each imports the shared verification client.
5. Request fresh Apple Production/Sandbox tests, inspect Apple's delivery status and confirm server receipts. Then run controlled purchase/restore checks before a store update.

Do not deploy the updated Supabase client before the private service is available. Apple credentials remain in Supabase; only public trust anchors and the dedicated service secret are needed here. Signing keys and store API credentials are never sent to this service.

If availability fails, notification handlers return an error so Apple can retry; the client never treats an unverified payload as premium. The previous Deno verifier is already incompatible with production and is not a working rollback. Retain the last known working Node service revision for later rollbacks.

Apple roots mirror `supabase/functions/_shared/apple-roots.ts`; update both copies from Apple's official PKI and review fingerprint changes together.
