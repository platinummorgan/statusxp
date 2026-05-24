import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const STEAM_OPENID_URL = 'https://steamcommunity.com/openid/login';
const DEFAULT_RETURN_TO = 'https://statusxp.com/steam-callback';
const SESSION_TTL_MS = 10 * 60 * 1000; // 10 minutes

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type StartLinkBody = {
  returnTo?: string;
};

function normalizePath(pathname: string): string {
  const trimmed = pathname.replace(/\/+$/, '');
  return trimmed.length > 0 ? trimmed : '/';
}

function isAllowedReturnTo(url: URL): boolean {
  const hostname = url.hostname.toLowerCase();
  const protocol = url.protocol.toLowerCase();
  const path = normalizePath(url.pathname.toLowerCase());

  const isProd = hostname === 'statusxp.com' || hostname === 'www.statusxp.com';
  const isLocal = hostname === 'localhost' || hostname === '127.0.0.1';

  if (!isProd && !isLocal) return false;
  if (path !== '/steam-callback') return false;

  if (isProd) {
    return protocol === 'https:';
  }
  return protocol === 'http:' || protocol === 'https:';
}

function buildOpenIdAuthUrl(returnTo: string): string {
  const returnToUrl = new URL(returnTo);
  const realm = `${returnToUrl.protocol}//${returnToUrl.host}/`;

  const authUrl = new URL(STEAM_OPENID_URL);
  authUrl.searchParams.set('openid.ns', 'http://specs.openid.net/auth/2.0');
  authUrl.searchParams.set('openid.mode', 'checkid_setup');
  authUrl.searchParams.set('openid.return_to', returnTo);
  authUrl.searchParams.set('openid.realm', realm);
  authUrl.searchParams.set(
    'openid.identity',
    'http://specs.openid.net/auth/2.0/identifier_select',
  );
  authUrl.searchParams.set(
    'openid.claimed_id',
    'http://specs.openid.net/auth/2.0/identifier_select',
  );
  return authUrl.toString();
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceRoleKey =
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: { Authorization: req.headers.get('Authorization') ?? '' },
      },
    });

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body: StartLinkBody = await req.json().catch(() => ({}));
    const requestedReturnTo = body.returnTo?.trim();

    let returnTo = DEFAULT_RETURN_TO;
    if (requestedReturnTo) {
      try {
        const parsed = new URL(requestedReturnTo);
        if (!isAllowedReturnTo(parsed)) {
          return new Response(
            JSON.stringify({
              error: 'Invalid callback URL',
            }),
            {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            },
          );
        }
        returnTo = parsed.toString();
      } catch (_) {
        return new Response(
          JSON.stringify({ error: 'Invalid callback URL format' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        );
      }
    }

    const state = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + SESSION_TTL_MS).toISOString();
    const returnToUrl = new URL(returnTo);
    returnToUrl.searchParams.set('steam_state', state);

    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);
    const { error: insertError } = await adminClient
      .from('steam_link_sessions')
      .insert({
        state,
        user_id: user.id,
        return_to: returnToUrl.toString(),
        expires_at: expiresAt,
      });

    if (insertError) {
      throw new Error(`Failed to create Steam link session: ${insertError.message}`);
    }

    const authUrl = buildOpenIdAuthUrl(returnToUrl.toString());

    return new Response(
      JSON.stringify({
        success: true,
        authUrl,
        returnTo: returnToUrl.toString(),
        expiresAt,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (error) {
    console.error('steam-start-link error:', error);
    return new Response(
      JSON.stringify({
        error:
          error instanceof Error
            ? error.message
            : 'Failed to start Steam linking',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
