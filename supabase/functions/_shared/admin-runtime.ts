import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { createAdminHandler } from "./admin-handler.ts";

// STATUSXP_ADMIN_USER_IDS is an optional server-managed comma-separated list.
// Protected owner/admin grants also authorize a verified account.
export function withAdminAccess(
  method: "GET" | "POST",
  execute: (req: Request) => Promise<unknown>,
): (req: Request) => Promise<Response> {
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return createAdminHandler({
    method,
    auth: {
      serviceRoleKey,
      adminUserIds: (Deno.env.get("STATUSXP_ADMIN_USER_IDS") ?? "")
        .split(",").map((id) => id.trim()).filter(Boolean),
      hasAdminAccess: async (userId) => {
        const db = createClient(Deno.env.get("SUPABASE_URL") ?? "", serviceRoleKey,
          { auth: { persistSession: false, autoRefreshToken: false } });
        const { data, error } = await db.rpc("has_app_admin_access", { p_user_id: userId });
        if (error) throw new Error("Administrative grant lookup unavailable");
        return data === true;
      },
      getUser: (token) =>
        createClient(
          Deno.env.get("SUPABASE_URL") ?? "",
          serviceRoleKey,
          { auth: { persistSession: false, autoRefreshToken: false } },
        ).auth.getUser(token),
    },
    execute,
  });
}
