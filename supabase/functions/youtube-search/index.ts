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
  admit: (user) => quotaResponse(user, "youtube", providerHeaders),
  validate: (body) =>
    typeof body.query === "string" && body.query.trim().length > 0 &&
    body.query.length <= 500 &&
    (body.maxResults === undefined ||
      (Number.isInteger(body.maxResults) && Number(body.maxResults) >= 1 &&
        Number(body.maxResults) <= 5)),
  execute: async (body) => {
    const key = Deno.env.get("YOUTUBE_API_KEY");
    if (!key) throw new Error("Unavailable");
    const url = new URL("https://www.googleapis.com/youtube/v3/search");
    url.search = new URLSearchParams({
      part: "snippet",
      type: "video",
      q: String(body.query),
      maxResults: String(body.maxResults ?? 1),
      key,
    }).toString();
    const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error("Provider failure");
    }
    return await response.json();
  },
}));
