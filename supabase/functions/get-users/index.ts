import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { withAdminAccess } from "../_shared/admin-runtime.ts";

Deno.serve(withAdminAccess("GET", async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  // Diagnostics never need platform credentials, even for administrators.
  const { data: profiles, error } = await supabase
    .from("profiles")
    .select("id, username, display_name, created_at")
    .order("created_at", { ascending: false })
    .limit(5);
  if (error) throw error;
  return { profiles };
}));
