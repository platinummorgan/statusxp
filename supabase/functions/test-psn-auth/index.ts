import { withAdminAccess } from "../_shared/admin-runtime.ts";

// The old diagnostic logged secrets and submitted a hardcoded user's sync.
// Keep a harmless response for old tooling until the deployment is removed.
Deno.serve(withAdminAccess("GET", async () =>
  new Response(
    JSON.stringify({
      error: "Diagnostic retired. Use the sync service health endpoint.",
    }),
    { status: 410, headers: { "Content-Type": "application/json" } },
  )));
