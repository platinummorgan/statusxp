import { XboxHandlerDeps, xboxClients, xboxCorsHeaders, xboxJson } from '../_shared/xbox-handler.ts';
import { completeSecurityReconnect } from '../_shared/security-reconnect.ts';

export function createXboxLinkHandler(deps: XboxHandlerDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: xboxCorsHeaders });
    if (req.method !== 'POST') return xboxJson({ error: 'Use POST.' }, 405);
    try {
      const clients = await xboxClients(req, deps);
      if (!clients) return xboxJson({ error: 'Unauthorized' }, 401);
      const { user, admin } = clients;
      let body: any;
      try { body = await req.json(); } catch { return xboxJson({ error: 'Invalid request.' }, 400); }
      const code = typeof body?.authCode === 'string' ? body.authCode : '';
      let microsoftAccess = typeof body?.accessToken === 'string' ? body.accessToken : '';
      let microsoftRefresh = '';
      if (!code && !microsoftAccess) return xboxJson({ error: 'Microsoft authorization code required.' }, 400);
      const getJson = async (url: string, init: RequestInit, message: string) => {
        const response = await deps.fetch(url, { ...init, signal: AbortSignal.timeout(20000) });
        if (!response.ok) throw new Error(message);
        return await response.json();
      };
      if (code) {
        const token = await getJson('https://login.live.com/oauth20_token.srf', {
          method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ client_id: deps.env('XBOX_CLIENT_ID') || '000000004C12AE6F',
            code, grant_type: 'authorization_code', redirect_uri: 'https://login.live.com/oauth20_desktop.srf' }),
        }, 'Microsoft sign-in could not be completed. Sign in again.');
        microsoftAccess = token.access_token;
        microsoftRefresh = token.refresh_token;
        if (!microsoftAccess || !microsoftRefresh) return xboxJson({ error: 'Microsoft sign-in did not grant offline access. Reconnect your Xbox account.' }, 400);
      }
      const post = (url: string, payload: unknown, message: string) => getJson(url, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
      }, message);
      const xbl = await post('https://user.auth.xboxlive.com/user/authenticate', {
        RelyingParty: 'http://auth.xboxlive.com', TokenType: 'JWT',
        Properties: { AuthMethod: 'RPS', SiteName: 'user.auth.xboxlive.com', RpsTicket: `d=${microsoftAccess}` },
      }, 'Xbox sign-in failed. Sign in again.');
      const xsts = await post('https://xsts.auth.xboxlive.com/xsts/authorize', {
        RelyingParty: 'http://xboxlive.com', TokenType: 'JWT',
        Properties: { UserTokens: [xbl.Token], SandboxId: 'RETAIL' },
      }, 'Xbox authorization failed. Check your Microsoft account and sign in again.');
      const claim = xsts.DisplayClaims?.xui?.[0];
      const xuid = String(claim?.xid ?? '');
      const userHash = claim?.uhs;
      const expires = new Date(xsts.NotAfter);
      if (!/^\d{1,20}$/.test(xuid) || !userHash || !xsts.Token || !Number.isFinite(expires.getTime()) || expires.getTime() <= Date.now()) {
        throw new Error('Xbox returned an invalid connection. Sign in again.');
      }
      const xboxHeaders = { Authorization: `XBL3.0 x=${userHash};${xsts.Token}`, 'x-xbl-contract-version': '2', 'Accept-Language': 'en-US' };
      const profile = await getJson(`https://profile.xboxlive.com/users/xuid(${xuid})/profile/settings?settings=Gamertag,Gamerscore`,
        { headers: xboxHeaders }, 'Could not verify your Xbox profile. Try again.');
      const profileUser = profile.profileUsers?.find((p: any) => String(p.id) === xuid);
      const settings = profileUser?.settings;
      const gamertag = settings?.find((s: any) => s.id === 'Gamertag')?.value;
      const score = settings?.find((s: any) => s.id === 'Gamerscore')?.value;
      const gamerscore = Number(score);
      if (!gamertag || !/^\d+$/.test(String(score)) || !Number.isSafeInteger(gamerscore)) throw new Error('Could not verify your Xbox profile. Try again.');
      const linked = await admin.rpc('link_verified_xbox_account', {
        p_user_id: user.id, p_xuid: xuid, p_gamertag: gamertag, p_user_hash: userHash,
        p_access_token: xsts.Token, p_refresh_token: microsoftRefresh,
        p_expires_at: expires.toISOString(), p_gamerscore: gamerscore,
      });
      if (linked.error) {
        const code = linked.error.code;
        return xboxJson({ error: ['55000', '23505', '22023', 'P0002'].includes(code)
          ? linked.error.message : 'Could not save the Xbox connection. Try again.' }, ['55000', '23505'].includes(code) ? 409 : 400);
      }
      // Only a fresh Microsoft authorization-code grant completes the security
      // reconnect; ordinary access-token refreshes must leave it required.
      if (code && microsoftRefresh) {
        const securityReconnect = await completeSecurityReconnect(admin,user.id,'xbox',xuid,microsoftRefresh);
        if (securityReconnect.error) return xboxJson({error:securityReconnect.error.code==='55000'
          ?securityReconnect.error.message:'Could not save your reconnect. Try again.'},securityReconnect.error.code==='55000'?409:503);
      }
      // Keep the installed app's response contract. Count current title summaries
      // only when the complete paginated history is available.
      let totalAchievements = 0;
      let totalAchievementsKnown = false;
      try {
        const base = `https://titlehub.xboxlive.com/users/xuid(${xuid})/titles/titlehistory/decoration/achievement`;
        const summaryDeadline = Date.now() + 3000;
        let url = base; const titles = new Set<string>(); const tokens = new Set<string>();
        for (let page = 0; page < 80 && Date.now() < summaryDeadline; page++) {
          const response = await deps.fetch(url, { headers: xboxHeaders, signal: AbortSignal.timeout(Math.max(1, summaryDeadline - Date.now())) });
          if (!response.ok) break;
          const data = await response.json();
          if (!Array.isArray(data.titles)) break;
          for (const title of data.titles) {
            const id = String(title.titleId);
            if (titles.has(id)) continue;
            titles.add(id);
            const count = Number(title.achievement?.currentAchievements);
            if (Number.isSafeInteger(count) && count > 0) totalAchievements += count;
          }
          const token = data.pagingInfo?.continuationToken || response.headers.get('x-continuation-token');
          if (!token) { totalAchievementsKnown = true; break; }
          if (tokens.has(token)) break;
          tokens.add(token); url = `${base}?continuationToken=${encodeURIComponent(token)}`;
        }
      } catch { /* Linking remains successful if the optional summary is unavailable. */ }
      if (!totalAchievementsKnown) totalAchievements = 0;
      return xboxJson({ success: true, xuid, gamertag, gamerscore, totalAchievements, totalAchievementsKnown });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Xbox connection failed. Try again.';
      // Upstream bodies, tokens, other users' identities and credentials are never returned.
      return xboxJson({ error: message.startsWith('Xbox ') || message.startsWith('Microsoft ') || message.startsWith('Could not verify')
        ? message : 'Xbox connection failed. Try again.' }, 400);
    }
  };
}
