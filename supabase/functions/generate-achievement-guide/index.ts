import { quotaResponse } from "../_shared/provider-quota.ts";
import { providerHeaders } from "../_shared/limited-provider-handler.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { createGuideHandler } from "./handler.ts";

const client = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  {
    auth: { persistSession: false, autoRefreshToken: false },
  },
);
async function rpc(name: string, args: Record<string, unknown>) {
  const { data, error } = await client.rpc(name, args);
  if (error || !data) throw new Error("Credit transaction failed");
  return data;
}
serve(createGuideHandler({
  admit: (user) => quotaResponse(user, "ai", providerHeaders),
  getUser: async (token) => {
    const { data, error } = await client.auth.getUser(token);
    return error ? null : data.user?.id ?? null;
  },
  reserve: (user, request, hash) =>
    rpc("reserve_ai_guide", {
      p_user_id: user,
      p_request_id: request,
      p_input_hash: hash,
    }),
  finish: (user, request, guide) =>
    rpc("finish_ai_guide", {
      p_user_id: user,
      p_request_id: request,
      p_guide: guide,
    }),
  generate: async (
    { gameTitle, achievementName, achievementDescription, platform },
  ) => {
    const key = Deno.env.get("OPENAI_API_KEY");
    if (!key) throw new Error("Generation unavailable");
    const platformText = platform ? ` (${platform})` : "";
    const prompt = `Game: ${gameTitle}${platformText}
Trophy/Achievement: ${achievementName}
Requirements: ${achievementDescription}

Respond EXACTLY in this format with these sections:

Obtainable?
[State if it's still obtainable, if it's missable, requires DLC, or has any restrictions]

Method:
[Provide clear, numbered steps on how to unlock this]
[Be specific with locations, button combinations, requirements]
[Mention if it's unmissable or story-related]

Keep it concise and actionable. No fluff.`;

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      signal: AbortSignal.timeout(45000),
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "You are a helpful gaming assistant that provides concise, actionable guides for unlocking achievements and trophies. Keep responses under 200 words.",
          },
          { role: "user", content: prompt },
        ],
        temperature: 0.7,
        max_tokens: 300,
        stream: false,
      }),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error("Generation failed");
    }
    const body = await response.json();
    const choice = body.choices?.[0];
    if (
      !["stop", "length"].includes(choice?.finish_reason) ||
      choice?.message?.refusal
    ) throw new Error("Generation refused");
    return choice?.message?.content;
  },
}));
