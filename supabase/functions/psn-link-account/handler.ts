import type { AuthorizationPayload, PSNUserProfile, UserTrophyProfileSummary } from '../_shared/psn-api.ts';
import type { XboxHandlerDeps } from '../_shared/xbox-handler.ts';
import { completeSecurityReconnect } from '../_shared/security-reconnect.ts';
export interface PsnLinkDeps extends XboxHandlerDeps {
 exchangeNpssoForAccessCode:(token:string)=>Promise<string>;
 exchangeAccessCodeForAuthTokens:(code:string)=>Promise<AuthorizationPayload>;
 extractAccountIdFromAccessToken:(token:string)=>string|null;
 getUserProfile:(auth:AuthorizationPayload,id:string)=>Promise<PSNUserProfile>;
 getUserTrophyProfileSummary:(auth:AuthorizationPayload,id:string)=>Promise<UserTrophyProfileSummary>;
 uploadExternalAvatar:(client:any,url:string,owner:string,platform:'psn'|'xbox'|'steam')=>Promise<string|null>;
}
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface LinkAccountRequest {
  npssoToken: string;
}

function extractErrorMessage(error: unknown): string {
  if (!error) return '';
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;

  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

function normalizeAccountId(accountId: string | null | undefined): string | null {
  const normalized = accountId?.trim();
  if (!normalized || normalized.toLowerCase() === 'me') return null;
  return normalized;
}

function getTotalTrophies(profile: UserTrophyProfileSummary | null): number {
  if (!profile) return 0;

  return (
    Number(profile.earnedTrophies?.bronze || 0) +
    Number(profile.earnedTrophies?.silver || 0) +
    Number(profile.earnedTrophies?.gold || 0) +
    Number(profile.earnedTrophies?.platinum || 0)
  );
}

function isInvalidSonyGrant(error: unknown): boolean {
  const message = extractErrorMessage(error).toLowerCase();
  return message.includes('invalid_grant') || message.includes('invalid login');
}

export function createPsnLinkHandler(deps: PsnLinkDeps) {
 return async (req: Request): Promise<Response> => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') return new Response(JSON.stringify({error:'Use POST.'}),{status:405,headers:{...corsHeaders,'Content-Type':'application/json'}});
  try {
    // Get user from auth header
    const supabase = deps.createClient(
      deps.env('SUPABASE_URL') ?? '',
      deps.env('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Parse request body
    const { npssoToken }: LinkAccountRequest = await req.json();

    if (!npssoToken) {
      return new Response(JSON.stringify({ error: 'NPSSO token required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log('Exchanging NPSSO for access code...');
    let accessCode = await deps.exchangeNpssoForAccessCode(npssoToken);

    console.log('Exchanging access code for auth tokens...');
    let authorization: AuthorizationPayload;
    try {
      authorization = await deps.exchangeAccessCodeForAuthTokens(accessCode);
    } catch (tokenError) {
      if (!isInvalidSonyGrant(tokenError)) throw tokenError;

      // Authorization codes are short-lived and single-use. Request one new
      // code from the same NPSSO and retry exactly once; never reuse a code
      // Sony has already rejected.
      console.warn('Sony rejected the first access code; requesting one fresh code and retrying once.');
      accessCode = await deps.exchangeNpssoForAccessCode(npssoToken);
      authorization = await deps.exchangeAccessCodeForAuthTokens(accessCode);
    }

    console.log('Fetching PSN user profile (onlineId, avatar, Plus status)...');
    let userProfile: PSNUserProfile | null = null;
    try {
      userProfile = await deps.getUserProfile(authorization, 'me');
    } catch (profileError) {
      console.warn('Failed to fetch PSN user profile:', extractErrorMessage(profileError));
    }

    let accountId =
      normalizeAccountId(userProfile?.accountId) ||
      deps.extractAccountIdFromAccessToken(authorization.accessToken);

    console.log('Fetching PSN trophy profile summary...');
    let trophyProfile: UserTrophyProfileSummary | null = null;
    let trophySummaryError: string | null = null;
    try {
      trophyProfile = await deps.getUserTrophyProfileSummary(authorization, accountId || 'me');
      accountId = normalizeAccountId(trophyProfile.accountId) || accountId;
    } catch (summaryError) {
      trophySummaryError = extractErrorMessage(summaryError);
      console.warn('Failed to fetch PSN trophy profile summary; continuing link:', trophySummaryError);
    }

    if (!accountId) {
      throw new Error(
        trophySummaryError
          ? `Failed to resolve PSN account ID after authentication. Trophy summary error: ${trophySummaryError}`
          : 'Failed to resolve PSN account ID after authentication.'
      );
    }

    if (!userProfile) {
      // Keep link behavior compatible with the previous fallback when profile
      // details are private or temporarily unavailable.
      userProfile = {
        onlineId: accountId,
        accountId,
        npId: '',
        avatarUrls: [],
        plus: 0,
        isPlus: false,
        aboutMe: '',
        languagesUsed: [],
        isOfficiallyVerified: false,
      };
    }

    const onlineId = userProfile.onlineId || accountId;

    console.log('Storing PSN credentials...');

    const supabaseAdmin = deps.createClient(deps.env('SUPABASE_URL')!, deps.env('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false, autoRefreshToken: false } });
    const current = await supabaseAdmin.from('profiles').select('psn_account_id,psn_sync_status').eq('id', user.id).single();
    if (current.error) throw new Error('Could not load your PlayStation connection. Try again.');
    if (['syncing','cancelling'].includes(current.data.psn_sync_status)) return new Response(
      JSON.stringify({error:'Stop the PlayStation sync before reconnecting.'}),
      {status:409,headers:{...corsHeaders,'Content-Type':'application/json'}});
    const duplicate = await supabaseAdmin.from('profiles').select('id').eq('psn_account_id',accountId).neq('id',user.id).limit(1);
    if (duplicate.error) throw new Error('Could not verify your PlayStation connection. Try again.');
    if (duplicate.data?.length) return new Response(JSON.stringify({error:'This PlayStation account is already connected to another app account.'}),
      {status:409,headers:{...corsHeaders,'Content-Type':'application/json'}});

    // Calculate token expiry
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + (authorization.expiresIn || 3600));

    // Download and upload PSN avatar to Supabase Storage to avoid CORS issues
    const externalAvatarUrl = userProfile.avatarUrls?.find(a => a.size === 'm')?.avatarUrl || userProfile.avatarUrls?.[0]?.avatarUrl;
    let avatarUrl = null;

    if (externalAvatarUrl) {
      console.log('Proxying PSN avatar through Supabase Storage...');
      // Use service role client for storage operations
      const serviceSupabase = deps.createClient(
        deps.env('SUPABASE_URL') ?? '',
        deps.env('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      );
      const proxiedUrl = await deps.uploadExternalAvatar(serviceSupabase, externalAvatarUrl, user.id, 'psn');
      if (proxiedUrl) {
        avatarUrl = proxiedUrl;
        console.log('Successfully proxied PSN avatar:', proxiedUrl);
      } else {
        console.warn('Failed to proxy PSN avatar');
      }
    }

    // Update user profile with PSN credentials
    const { data: updated, error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({
        psn_account_id: accountId,
        psn_online_id: onlineId,
        psn_avatar_url: avatarUrl,
        psn_is_plus: userProfile.isPlus,
        psn_npsso_token: npssoToken, // In production, this should be encrypted
        psn_access_token: authorization.accessToken,
        psn_refresh_token: authorization.refreshToken,
        psn_token_expires_at: expiresAt.toISOString(),
        psn_sync_status: 'never_synced',
        psn_sync_error: null,
        psn_sync_progress: 0,
      })
      .eq('id', user.id).not('psn_sync_status','in','(syncing,cancelling)').select('id').single();

    if (updateError || !updated) {
      if (updateError?.code === '23505' || updateError?.code === '55000' || updateError?.code === 'PGRST116') return new Response(
        JSON.stringify({error:updateError.code==='23505'?'This PlayStation account is already connected to another app account.':'Stop the PlayStation sync before reconnecting.'}),
        {status:409,headers:{...corsHeaders,'Content-Type':'application/json'}});
      throw new Error('Could not save your PlayStation connection. Try again.');
    }

    const securityReconnect = await completeSecurityReconnect(supabaseAdmin,user.id,'psn',accountId,npssoToken);
    if (securityReconnect.error) return new Response(JSON.stringify({error:
      securityReconnect.error.code==='55000'?securityReconnect.error.message:'Could not save your reconnect. Try again.'}),
      {status:securityReconnect.error.code==='55000'?409:503,headers:{...corsHeaders,'Content-Type':'application/json'}});

    // Store PSN trophy profile when Sony returned it. Linking should still
    // succeed if this optional summary endpoint is temporarily unavailable.
    if (trophyProfile) {
      const summarySave = await supabaseAdmin
        .from('psn_user_trophy_profile')
        .upsert({
          user_id: user.id,
          psn_trophy_level: parseInt(trophyProfile.trophyLevel.toString()),
          psn_trophy_progress: trophyProfile.progress,
          psn_trophy_tier: trophyProfile.tier,
          psn_earned_bronze: trophyProfile.earnedTrophies.bronze,
          psn_earned_silver: trophyProfile.earnedTrophies.silver,
          psn_earned_gold: trophyProfile.earnedTrophies.gold,
          psn_earned_platinum: trophyProfile.earnedTrophies.platinum,
          last_fetched_at: new Date().toISOString(),
        });
      if (summarySave.error) trophyProfile = null;
    }

    return new Response(
      JSON.stringify({
        success: true,
        accountId,
        onlineId,
        avatarUrl: avatarUrl || externalAvatarUrl || null,
        isPlus: userProfile.isPlus,
        trophyLevel: trophyProfile ? parseInt(trophyProfile.trophyLevel.toString()) : 0,
        totalTrophies: getTotalTrophies(trophyProfile),
        trophySummaryAvailable: !!trophyProfile,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error linking PSN account:', error);
    const errorMessage = isInvalidSonyGrant(error)
      ? 'PlayStation rejected this sign-in session. Return to PlayStation sign-in and try again with a fresh session.'
      : extractErrorMessage(error) || 'Failed to link PSN account';
    return new Response(
      JSON.stringify({
        error: errorMessage,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
 };
}
