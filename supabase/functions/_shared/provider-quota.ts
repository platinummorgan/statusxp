import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

export class QuotaDenied extends Error {
  constructor(public retryAfter: number) {
    super("Request limit reached. Please try again later.");
  }
}
export async function admitProvider(
  userId: string,
  provider: string,
): Promise<void> {
  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    {
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  const { data, error } = await client.rpc("admit_provider_request", {
    p_user_id: userId,
    p_provider: provider,
  });
  if (error || !data || typeof data.allowed !== "boolean") {
    throw new Error("Quota service unavailable");
  }
  if (!data.allowed) {
    throw new QuotaDenied(Math.max(1, Number(data.retry_after) || 60));
  }
}
export async function quotaResponse(
  userId: string,
  provider: string,
  headers: Record<string, string>,
): Promise<Response | null> {
  try {
    await admitProvider(userId, provider);
    return null;
  } catch (error) {
    const denied = error instanceof QuotaDenied;
    return new Response(
      JSON.stringify({
        error: denied
          ? error.message
          : "Quota service unavailable. Try again later.",
        ...(denied
          ? {
            retry_after: error.retryAfter,
            message: error.message,
            nextSyncAvailableAt: new Date(Date.now() + error.retryAfter * 1000)
              .toISOString(),
          }
          : {}),
      }),
      {
        status: denied ? 429 : 503,
        headers: {
          ...headers,
          "Content-Type": "application/json",
          "Cache-Control": "no-store",
          ...(denied ? { "Retry-After": String(error.retryAfter) } : {}),
        },
      },
    );
  }
}
