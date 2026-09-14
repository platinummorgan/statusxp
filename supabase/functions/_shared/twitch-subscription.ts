export async function currentTwitchSubscription(
  userId: string,
  settings = {
    broadcaster: Deno.env.get("TWITCH_BROADCASTER_ID"),
    token: Deno.env.get("TWITCH_BROADCASTER_TOKEN"),
    client: Deno.env.get("TWITCH_CLIENT_ID"),
    request: fetch,
  },
): Promise<boolean> {
  const { broadcaster, token, client } = settings;
  if (!broadcaster || !token || !client) {
    throw new Error("Twitch subscription check unavailable");
  }
  const url = new URL("https://api.twitch.tv/helix/subscriptions");
  url.search = new URLSearchParams({
    broadcaster_id: broadcaster,
    user_id: userId,
  }).toString();
  const response = await settings.request(url, {
    headers: { Authorization: `Bearer ${token}`, "Client-Id": client },
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error("Twitch subscription check failed");
  }
  const data = await response.json();
  if (!Array.isArray(data.data)) {
    throw new Error("Invalid subscription response");
  }
  return data.data.some((row: { user_id?: string; broadcaster_id?: string }) =>
    row.user_id === userId && row.broadcaster_id === broadcaster
  );
}
