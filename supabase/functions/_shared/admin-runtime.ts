import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { createAdminHandler } from "./admin-handler.ts";

// STATUSXP_ADMIN_USER_IDS is an optional server-managed comma-separated list.
// Without it, only trusted automation holding the service-role key is allowed.
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
