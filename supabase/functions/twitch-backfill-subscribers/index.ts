import { withAdminAccess } from "../_shared/admin-runtime.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { reconcileTwitchSubscription } from "../_shared/twitch-reconcile.ts";
Deno.serve(withAdminAccess("POST", async () => {
  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const counts = { checked: 0, active: 0, inactive: 0, errors: 0 };
  // Bounded pages avoid silently dropping users at the database row limit.
  let after = "";
  while (true) {
    let query = db.from("twitch_account_bindings").select("user_id,twitch_user_id")
      .order("user_id").limit(100);
    if (after) query = query.gt("user_id", after);
    const { data, error } = await query;
    if (error) throw new Error("Binding lookup unavailable");
    if (!data?.length) break;
    for (const profile of data) {
      if (profile.twitch_user_id === Deno.env.get("TWITCH_BROADCASTER_ID")) {
        continue;
      }
      try {
        const active = await reconcileTwitchSubscription(
          profile.twitch_user_id,
        );
        counts.checked++;
        if (active) counts.active++;
        else counts.inactive++;
      } catch {
        counts.errors++;
      }
    }
    after = data[data.length - 1].user_id;
    if (data.length < 100) break;
  }
  return new Response(JSON.stringify(counts), {
    status: counts.errors ? 503 : 200,
    headers: { "Content-Type": "application/json" },
  });
}));
