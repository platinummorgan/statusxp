import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { createTwitchHandler } from "./handler.ts";
import { currentTwitchSubscription } from "../_shared/twitch-subscription.ts";
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
Deno.serve(createTwitchHandler({
  secret: Deno.env.get("TWITCH_EVENTSUB_SECRET") ?? "",
  broadcasterId: Deno.env.get("TWITCH_BROADCASTER_ID") ?? "",
  seen: async (messageId, hash) => {
    const { data, error } = await db.from("twitch_event_receipts").select(
      "body_hash",
    ).eq("message_id", messageId).maybeSingle();
    if (error) throw new Error("Receipt lookup failed");
    if (data && data.body_hash !== hash) throw new Error("Message conflict");
    return !!data;
  },
  check: currentTwitchSubscription,
  apply: async (o) => {
    const { error } = await db.rpc("apply_twitch_event", {
      p_message_id: o.messageId,
      p_body_hash: o.bodyHash,
      p_signed_at: o.signedAt,
      p_twitch_user_id: o.twitchUserId,
      p_active: o.active,
    });
    if (error) throw new Error("Entitlement update failed");
  },
}));
