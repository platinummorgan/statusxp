export type Event = {
  id: string;
  type: string;
  data: {
    object: {
      id: string;
      mode?: string;
      subscription?: string | { id: string } | null;
    };
  };
};
export type WebhookDependencies = {
  verify: (body: string, signature: string) => Promise<Event>;
  claim: (
    event: Event,
    resource: string,
  ) => Promise<{ state: string; token?: string }>;
  resolve: (event: Event) => Promise<Record<string, unknown>>;
  finish: (
    id: string,
    token: string,
    data: Record<string, unknown>,
  ) => Promise<void>;
};
export function createStripeWebhook(deps: WebhookDependencies) {
  const response = (status: number) =>
    new Response(JSON.stringify({ received: status === 200 }), {
      status,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    });
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return response(405);
    const signature = req.headers.get("stripe-signature");
    if (!signature) return response(400);
    let event: Event;
    try {
      const reader = req.body?.getReader();
      if (!reader) return response(400);
      const decoder = new TextDecoder();
      let body = "", size = 0;
      try {
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          size += value.length;
          if (size > 512000) {
            await reader.cancel();
            return response(413);
          }
          body += decoder.decode(value, { stream: true });
        }
        body += decoder.decode();
      } finally {
        reader.releaseLock();
      }
      event = await deps.verify(body, signature);
    } catch {
      return response(400);
    }
    try {
      const object = event.data.object;
      const sub = typeof object.subscription === "string"
        ? object.subscription
        : object.subscription?.id;
      const resource = event.type.startsWith("customer.subscription.")
        ? `subscription:${object.id}`
        : event.type.startsWith("checkout.session.") &&
            object.mode === "subscription" && sub
        ? `subscription:${sub}`
        : event.type.startsWith("checkout.session.")
        ? `checkout:${object.id}`
        : `event:${event.id}`;
      const claim = await deps.claim(event, resource);
      if (claim.state === "done") return response(200);
      if (claim.state !== "claimed" || !claim.token) return response(503);
      // Current Stripe state is fetched only while owning the resource lease.
      const data = await deps.resolve(event);
      await deps.finish(event.id, claim.token, data);
      return response(200);
    } catch {
      return response(503);
    }
  };
}
