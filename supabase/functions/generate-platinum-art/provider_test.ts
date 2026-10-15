import { generatePlatinumArtwork } from "./provider.ts";
const assert = (x: unknown) => {
  if (!x) throw new Error("assertion failed");
};
Deno.test("provider uses one fixed-size background and never sends player statistics", async () => {
  const request: typeof fetch = async (url, options) => {
    assert(url === "https://api.openai.com/v1/images/generations");
    const body = JSON.parse(options!.body as string);
    assert(
      body.n === 1 && body.size === "1024x1536" && body.quality === "medium",
    );
    assert(body.model === "gpt-image-2.5-flare");
    assert(body.prompt.includes("No text, letters, numbers"));
    assert(!body.prompt.includes("player_name"));
    return new Response(
      JSON.stringify({
        data: [{
          b64_json: btoa(String.fromCharCode(137, 80, 78, 71, 13, 10, 26, 10)),
        }],
      }),
    );
  };
  const bytes = await generatePlatinumArtwork({
    key: "fixture-key",
    game: "Verified game",
    style: "cinematic",
    request,
  });
  assert(bytes[0] === 137);
});
Deno.test("upstream errors are redacted", async () => {
  let message = "";
  try {
    await generatePlatinumArtwork({
      key: "fixture-key",
      game: "Game",
      style: "painted",
      request: async () =>
        new Response("sensitive-provider-message", { status: 403 }),
    });
  } catch (e) {
    message = String(e);
  }
  assert(
    message.includes("Artwork unavailable") &&
      !message.includes("sensitive-provider-message"),
  );
});
Deno.test("malformed or non-PNG images are never stored", async () => {
  for (
    const body of [{ data: [] }, { data: [{ b64_json: btoa("not an image") }] }]
  ) {
    let failed = false;
    try {
      await generatePlatinumArtwork({
        key: "fixture-key",
        game: "Game",
        style: "cosmic",
        request: async () => new Response(JSON.stringify(body)),
      });
    } catch {
      failed = true;
    }
    assert(failed);
  }
});
