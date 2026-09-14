import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { reconcileTwitchSubscription } from "../_shared/twitch-reconcile.ts";
const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return reply({ error: "Use POST" }, 405);
  const token = /^Bearer ([^\s]+)$/i.exec(
    req.headers.get("Authorization") ?? "",
  )?.[1];
  if (!token) return reply({ error: "Unauthorized" }, 401);
  try {
    const db = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: `Bearer ${token}` } },
        auth: { persistSession: false },
      },
    );
    const { data, error } = await db.auth.getUser(token);
    if (error || !data.user) return reply({ error: "Unauthorized" }, 401);
    const binding = await db.rpc("get_my_twitch_binding");
    if (binding.error) throw new Error("Binding lookup failed");
    if (!binding.data) {
      return reply({ isLinked: false, isSubscribed: false });
    }
    const isSubscribed = await reconcileTwitchSubscription(binding.data);
    return reply({ success: true, isLinked: true, isSubscribed });
  } catch {
    return reply(
      { error: "Subscription check unavailable. Please try again." },
      503,
    );
  }
});
