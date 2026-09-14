# Twitch OAuth state validation — SX-006

Date: 2026-09-11. Implemented locally; deployment and a real Twitch authorization round trip remain pending.

The previous flow sent a constant state string and exchanged any callback code. The browser now generates 32 cryptographically random bytes for every attempt, stores the pending request in sessionStorage, and validates the returned state before calling the existing authenticated linking endpoint. This follows [Twitch's state guidance](https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/#authorization-code-grant-flow).

The pending request is tied to the StatusXP user and [Supabase session ID](https://supabase.com/docs/guides/auth/sessions#access-token-jwt-claims). A token refresh preserves the binding; another account or a new login does not. Decoding the session ID only correlates local state and does not grant backend permissions. Server authentication remains unchanged.

State expires after ten minutes and is removed before callback processing, including rejected callbacks. Missing, duplicate, mismatched, expired, malformed, or replayed values cannot reach code exchange. Provider denial also consumes the attempt. A failed exchange requires starting again. Callback query values are removed from browser history before asynchronous work, and provider-supplied error text is not displayed.

Browser storage must be available, and authorization must start on `https://statusxp.com`, the origin of the existing registered callback. Other origins show instructions to sign in on that host instead of starting a flow whose storage would be inaccessible on return. The existing settings navigation changes in the working tree were preserved.

## Validation and release

Sixteen focused tests cover random state, successful single consumption, expiry boundary, future timestamps, missing/mismatched/duplicate values, corrupt storage, account/session changes, token refresh, provider denial, replay, and unavailable storage. The successful test validates returning the code for exchange; it does not perform a real Twitch exchange.

Before marking SX-006 complete, deploy the web build and use a controlled account to verify connect → Twitch consent → callback → linked settings, denial, retry, expired callback, and account switch. Do not reuse a callback URL after deployment: the old constant-state flow is intentionally rejected. No Edge Function or database deployment is required by this batch. No real Twitch accounts were linked or changed during local validation.

The browser state check protects this callback flow against CSRF. It is not a global server-side replay ledger; provider codes remain subject to Twitch's own exchange rules. Server-side entitlement and credential-storage work remains tracked separately.

Local results: [analysis](oauth-analyze.txt) found no issues; [full Flutter suite](oauth-flutter-tests.txt) passed 56 tests, with the eight existing web-only tests skipped on the native runner; [release web build](oauth-build.txt) passed with the pre-existing optional Wasm incompatibility warnings. The eight guest-layout browser tests passed in the preceding batch and were not rerun for this OAuth-only change.
