import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { googleGet } from "../_shared/google-play.ts";
import { applyGoogleSnapshot } from "../_shared/google-reconcile.ts";
import { googlePushAuth } from "./auth.ts";
import { createGoogleNotificationHandler } from "./handler.ts";
import { packageId, parseGoogleSnapshot } from "./snapshot.ts";
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
const email = Deno.env.get("GOOGLE_PLAY_PUSH_SERVICE_ACCOUNT_EMAIL") ?? "";
const audience = Deno.env.get("GOOGLE_PLAY_PUSH_AUDIENCE") ?? "";
Deno.serve(createGoogleNotificationHandler({
  subscription: email && audience
    ? Deno.env.get("GOOGLE_PLAY_PUBSUB_SUBSCRIPTION") ?? ""
    : "",
  authenticate: googlePushAuth(email, audience),
  seen: async (id, hash) => {
    const { data, error } = await db.from("google_play_notification_receipts")
      .select("body_hash").eq("message_id", id).maybeSingle();
    if (error || (data && data.body_hash !== hash)) {
      throw new Error("Receipt unavailable");
    }
    return !!data;
  },
  lookup: async (token) =>
    parseGoogleSnapshot(
      await googleGet(
        `/androidpublisher/v3/applications/${packageId}/purchases/subscriptionsv2/tokens/${
          encodeURIComponent(token)
        }`,
      ),
      token,
    ),
  apply: (id, hash, observedAt, snapshot, token) =>
    applyGoogleSnapshot(db, id, hash, observedAt, snapshot, token),
}));
