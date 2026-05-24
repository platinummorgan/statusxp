import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const STEAM_OPENID_URL = 'https://steamcommunity.com/openid/login';
const STEAM_CLAIMED_ID_PREFIX = 'https://steamcommunity.com/openid/id/';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type LinkBody = {
  callbackUrl?: string;
};

function extractSteamId(claimedId: string | null): string | null {
  if (!claimedId) return null;
  if (!claimedId.startsWith(STEAM_CLAIMED_ID_PREFIX)) return null;
  const candidate = claimedId.substring(STEAM_CLAIMED_ID_PREFIX.length);
  if (!/^\d{17,25}$/.test(candidate)) return null;
  return candidate;
}

async function verifySteamOpenIdAssertion(callbackUrl: URL): Promise<boolean> {
  const params = new URLSearchParams(callbackUrl.searchParams);
  params.set('openid.mode', 'check_authentication');

  const response = await fetch(STEAM_OPENID_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params.toString(),
  });

  if (!response.ok) {
    return false;
  }

  const text = await response.text();
  return /is_valid\s*:\s*true/i.test(text);
}

async function fetchSteamDisplayProfile(steamId: string): Promise<{
  displayName: string | null;
  avatarUrl: string | null;
}> {
  const key =
    Deno.env.get('STEAM_WEB_API_KEY') ?? Deno.env.get('STEAM_API_KEY') ?? null;

  if (!key) {
    return { displayName: null, avatarUrl: null };
  }

  try {
    const url = new URL(
      'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/',
    );
    url.searchParams.set('key', key);
    url.searchParams.set('steamids', steamId);

    const response = await fetch(url.toString());
    if (!response.ok) {
      return { displayName: null, avatarUrl: null };
    }
    const data = await response.json();
    const player = data?.response?.players?.[0];
    return {
      displayName: player?.personaname ?? null,
      avatarUrl: player?.avatarfull ?? player?.avatarmedium ?? player?.avatar ?? null,
    };
  } catch (_) {
    return { displayName: null, avatarUrl: null };
  }
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

    const body: LinkBody = await req.json().catch(() => ({}));
    const callbackUrlRaw = body.callbackUrl?.trim();
    if (!callbackUrlRaw) {
      return new Response(
        JSON.stringify({ error: 'callbackUrl is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    let callbackUrl: URL;
    try {
      callbackUrl = new URL(callbackUrlRaw);
    } catch (_) {
      return new Response(
        JSON.stringify({ error: 'Invalid callbackUrl format' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    if (callbackUrl.searchParams.get('openid.mode') === 'cancel') {
      return new Response(
        JSON.stringify({ error: 'Steam sign-in was cancelled' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const state = callbackUrl.searchParams.get('steam_state');
    if (!state) {
      return new Response(
        JSON.stringify({ error: 'Missing Steam link state' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    const { data: session, error: sessionError } = await adminClient
      .from('steam_link_sessions')
      .select('state, user_id, return_to, expires_at, consumed_at')
      .eq('state', state)
      .maybeSingle();

    if (sessionError || !session) {
      return new Response(
        JSON.stringify({ error: 'Steam link session not found or expired' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    if (session.user_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Steam link session belongs to another user' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    if (session.consumed_at) {
      return new Response(
        JSON.stringify({ error: 'Steam link session already used' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const expiresAt = new Date(session.expires_at);
    if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() < Date.now()) {
      return new Response(
        JSON.stringify({ error: 'Steam link session expired' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const callbackReturnTo = callbackUrl.searchParams.get('openid.return_to');
    if (!callbackReturnTo || callbackReturnTo !== session.return_to) {
      return new Response(
        JSON.stringify({ error: 'Steam callback return URL mismatch' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const validAssertion = await verifySteamOpenIdAssertion(callbackUrl);
    if (!validAssertion) {
      return new Response(
        JSON.stringify({ error: 'Invalid Steam OpenID response' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const claimedId = callbackUrl.searchParams.get('openid.claimed_id');
    const steamId = extractSteamId(claimedId);
    if (!steamId) {
      return new Response(
        JSON.stringify({ error: 'Could not extract Steam ID from callback' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const { data: existingOwner } = await adminClient
      .from('profiles')
      .select('id')
      .eq('steam_id', steamId)
      .neq('id', user.id)
      .maybeSingle();

    if (existingOwner?.id) {
      return new Response(
        JSON.stringify({
          error: 'Steam account already linked',
          message:
            'This Steam account is already connected to another StatusXP account.',
        }),
        {
          status: 409,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const steamProfile = await fetchSteamDisplayProfile(steamId);

    const profileUpdates: Record<string, unknown> = {
      steam_id: steamId,
      steam_api_key: null,
      steam_sync_status: 'never_synced',
      steam_sync_error: null,
      steam_sync_progress: 0,
    };

    if (steamProfile.displayName) {
      profileUpdates.steam_display_name = steamProfile.displayName;
    }
    if (steamProfile.avatarUrl) {
      profileUpdates.steam_avatar_url = steamProfile.avatarUrl;
    }

    const { error: updateError } = await adminClient
      .from('profiles')
      .update(profileUpdates)
      .eq('id', user.id);

    if (updateError) {
      throw new Error(`Failed to update Steam profile: ${updateError.message}`);
    }

    await adminClient
      .from('steam_link_sessions')
      .update({ consumed_at: new Date().toISOString() })
      .eq('state', state);

    return new Response(
      JSON.stringify({
        success: true,
        steamId,
        steamDisplayName: steamProfile.displayName,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (error) {
    console.error('steam-link-account error:', error);
    return new Response(
      JSON.stringify({
        error:
          error instanceof Error ? error.message : 'Failed to link Steam account',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
