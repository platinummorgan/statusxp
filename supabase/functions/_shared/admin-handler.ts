import { timingSafeEqual } from "node:crypto";

export interface AdminAuthOptions {
  serviceRoleKey: string;
  adminUserIds: string[];
  // Verify with Supabase Auth; never trust a decoded JWT or user metadata.
  getUser: (token: string) => Promise<{
    data: { user: { id: string } | null };
    error: unknown;
  }>;
}

export function createAdminHandler(options: {
  method: "GET" | "POST";
  auth: AdminAuthOptions;
  execute: (req: Request) => Promise<unknown>;
}): (req: Request) => Promise<Response> {
  const headers = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": `${options.method}, OPTIONS`,
    "Cache-Control": "no-store",
  };
  const json = (body: unknown, status: number) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...headers, "Content-Type": "application/json" },
    });

  return async (req) => {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers });
    }
    if (req.method !== options.method) {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: {
          ...headers,
          "Content-Type": "application/json",
          Allow: `${options.method}, OPTIONS`,
        },
      });
    }

    const token = /^Bearer ([^\s]+)$/i.exec(
      req.headers.get("Authorization") ?? "",
    )?.[1];
    if (!token) return json({ error: "Unauthorized" }, 401);
    if (!options.auth.serviceRoleKey.trim()) {
      return json({ error: "Administrative access is not configured" }, 503);
    }

    const encoder = new TextEncoder();
    const received = encoder.encode(token);
    const expected = encoder.encode(options.auth.serviceRoleKey);
    const isService = received.length === expected.length &&
      timingSafeEqual(received, expected);
    if (!isService) {
      if (options.auth.adminUserIds.length === 0) {
        return json({ error: "Forbidden" }, 403);
      }
      try {
        const { data, error } = await options.auth.getUser(token);
        if (error || !data.user) return json({ error: "Unauthorized" }, 401);
        if (!options.auth.adminUserIds.includes(data.user.id)) {
          return json({ error: "Forbidden" }, 403);
        }
      } catch {
        return json({ error: "Unable to verify administrative access" }, 503);
      }
    }

    try {
      const result = await options.execute(req);
      // Legacy handlers can retain their response while sharing the auth gate.
      if (result instanceof Response) {
        const responseHeaders = new Headers(result.headers);
        for (const [key, value] of Object.entries(headers)) {
          responseHeaders.set(key, value);
        }
        return new Response(result.body, {
          status: result.status,
          headers: responseHeaders,
        });
      }
      return json(result, 200);
    } catch {
      console.error("Administrative operation failed");
      return json({ error: "Administrative operation failed" }, 500);
    }
  };
}
