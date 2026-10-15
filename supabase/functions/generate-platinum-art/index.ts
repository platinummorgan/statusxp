import { generatePlatinumArtwork } from "./provider.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { createPlatinumArtHandler } from "./handler.ts";
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);
const bucket = db.storage.from("platinum-art");
Deno.serve(createPlatinumArtHandler({
  available: () => !!Deno.env.get("OPENAI_API_KEY"),
  getUser: async (token) => {
    const { data, error } = await db.auth.getUser(token);
    return error ? null : data.user?.id ?? null;
  },
  reserve: async (user, input, hash) => {
    const { data, error } = await db.rpc("reserve_platinum_art", {
      p_user: user,
      p_request: input.requestId,
      p_hash: hash,
      p_platform: input.platformId,
      p_game: input.gameId,
    });
    if (error) throw new Error("Admission unavailable");
    return data;
  },
  finish: async (user, id, path) => {
    const { data, error } = await db.rpc("finish_platinum_art", {
      p_user: user,
      p_request: id,
      p_path: path,
    });
    if (error) throw new Error("Save unavailable");
    return data === true;
  },
  remove: async (path) => {
    await bucket.remove([path]);
  },
  generate: async (user, input, game) => {
    const bytes = await generatePlatinumArtwork({
      key: Deno.env.get("OPENAI_API_KEY")!,
      model: Deno.env.get("PLATINUM_IMAGE_MODEL"),
      game,
      style: input.style,
    });
    const path = `${user}/${input.requestId}.png`;
    const { error } = await bucket.upload(path, bytes, {
      contentType: "image/png",
      upsert: false,
    });
    if (error) throw new Error("Artwork storage unavailable");
    return path;
  },
}));
