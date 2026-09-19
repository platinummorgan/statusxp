import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { withAdminAccess } from "../_shared/admin-runtime.ts";

Deno.serve(withAdminAccess("POST", async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { error } = await supabase.from("profiles").update({
    psn_sync_status: "stopped",
    psn_sync_progress: 0,
    xbox_sync_status: "stopped",
    xbox_sync_progress: 0,
    steam_sync_status: "stopped",
    steam_sync_progress: 0,
  }).or(
    "psn_sync_status.eq.syncing,psn_sync_status.eq.cancelling,xbox_sync_status.eq.syncing,xbox_sync_status.eq.cancelling,steam_sync_status.eq.syncing,steam_sync_status.eq.cancelling",
  );
  if (error) throw error;

  const now = new Date().toISOString();
  const results = await Promise.all(
    ["psn_sync_logs", "xbox_sync_logs", "steam_sync_logs"].map((table) =>
      supabase.from(table)
        .update({ status: "cancelled", completed_at: now })
        .in("status", ["pending", "syncing"])
    ),
  );
  const failed = results.find((result) => result.error);
  if (failed) throw failed.error;
  return {
    success: true,
    message: "All running syncs have been force-stopped",
  };
}));
