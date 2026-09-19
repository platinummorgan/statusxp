import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { currentTwitchSubscription } from "./twitch-subscription.ts";
export async function reconcileTwitchSubscription(
  twitchId: string,
): Promise<boolean> {
  const observedAt = new Date().toISOString();
  const active = await currentTwitchSubscription(twitchId);
  const messageId = `reconcile:${crypto.randomUUID()}`;
  const hash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`${twitchId}:${observedAt}:${active}`),
  );
  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const { error } = await db.rpc("apply_twitch_event", {
    p_message_id: messageId,
    p_body_hash: Array.from(
      new Uint8Array(hash),
      (b) => b.toString(16).padStart(2, "0"),
    ).join(""),
    p_signed_at: observedAt,
    p_twitch_user_id: twitchId,
    p_active: active,
  });
  if (error) throw new Error("Twitch reconciliation failed");
  return active;
}
