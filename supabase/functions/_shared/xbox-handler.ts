export const xboxCorsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
export interface XboxHandlerDeps {
  createClient: (url: string, key: string, options?: any) => any;
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
}
export function xboxJson(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...xboxCorsHeaders, 'Content-Type': 'application/json' } });
}
export async function xboxClients(req: Request, deps: XboxHandlerDeps) {
  const authorization = req.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return null;
  const url = deps.env('SUPABASE_URL')!;
  const caller = deps.createClient(url, deps.env('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await caller.auth.getUser();
  if (error || !data?.user) return null;
  // The caller verifies identity; only the server client reads/writes credentials.
  const admin = deps.createClient(url, deps.env('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return { user: data.user, admin };
}
