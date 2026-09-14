import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import {
  limitedProviderHandler,
  providerHeaders,
} from "../_shared/limited-provider-handler.ts";
import { quotaResponse } from "../_shared/provider-quota.ts";
const client = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_ANON_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);
const getUser = async (token: string) => {
  const { data, error } = await client.auth.getUser(token);
  return error ? null : data.user?.id ?? null;
};

Deno.serve(limitedProviderHandler({
  getUser,
  admit: (user) => quotaResponse(user, "moderation", providerHeaders),
  validate: (body) =>
    typeof body.text === "string" && body.text.trim().length > 0 &&
    body.text.length <= 5000,
  execute: async (body) => {
    const key = Deno.env.get("OPENAI_API_KEY");
    if (!key) throw new Error("Unavailable");
    const response = await fetch("https://api.openai.com/v1/moderations", {
      method: "POST",
      signal: AbortSignal.timeout(15000),
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({ input: body.text }),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error("Provider failure");
    }
    const data = await response.json();
    const result = data.results?.[0];
    if (
      typeof result?.flagged !== "boolean" || !result.categories ||
      typeof result.categories !== "object"
    ) throw new Error("Invalid moderation result");
    const categories = Object.entries(result.categories).filter(([, flagged]) =>
      flagged === true
    ).map(([category]) => category);
    return {
      is_safe: !result.flagged,
      reason: categories.length
        ? `Content flagged for: ${categories.join(", ")}`
        : null,
      categories: result.categories,
    };
  },
}));
