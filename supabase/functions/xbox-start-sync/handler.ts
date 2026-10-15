import { XboxHandlerDeps, xboxClients, xboxCorsHeaders, xboxJson } from '../_shared/xbox-handler.ts';
export interface XboxStartDeps extends XboxHandlerDeps {
  quotaResponse: (userId: string, provider: string, headers: Record<string, string>) => Promise<Response | null>;
}
export function createXboxStartHandler(deps: XboxStartDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: xboxCorsHeaders });
    if (req.method !== 'POST') return xboxJson({ error: 'Use POST.' }, 405);
    let admin: any; let owner: string | undefined; let logId: number | undefined;
    try {
      const clients = await xboxClients(req, deps);
      if (!clients) return xboxJson({ error: 'Unauthorized' }, 401);
      admin = clients.admin; owner = clients.user.id;
      const result = await admin.from('profiles').select('xbox_refresh_token,xbox_xuid,xbox_user_hash,xbox_access_token,xbox_sync_status').eq('id', owner).single();
      if (result.error) return xboxJson({ error: 'Could not load the Xbox connection. Try again.' }, 503);
      const profile = result.data;
      if (!profile?.xbox_xuid || !profile?.xbox_refresh_token) return xboxJson({ error: 'Reconnect your Xbox account to sync.' }, 400);
      if (['syncing', 'cancelling'].includes(profile.xbox_sync_status)) return xboxJson({ error: 'Xbox sync already in progress.' }, 409);
      const denied = await deps.quotaResponse(owner!, 'sync_xbox', xboxCorsHeaders);
      if (denied) return denied;
      const started = await admin.rpc('begin_verified_xbox_sync', { p_user_id: owner, p_expected_xuid: profile.xbox_xuid });
      if (started.error) return xboxJson({ error: started.error.code === '55000' ? started.error.message : 'Could not start Xbox sync. Try again.' }, started.error.code === '55000' ? 409 : 503);
      logId = started.data;
      const secret = deps.env('SYNC_SERVICE_SECRET');
      if (!secret) throw new Error('Sync service authentication unavailable');
      const response = await deps.fetch('https://statusxp-production.up.railway.app/sync/xbox', {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${secret}` },
        body: JSON.stringify({ userId: owner, xuid: profile.xbox_xuid, userHash: profile.xbox_user_hash,
          accessToken: profile.xbox_access_token, refreshToken: profile.xbox_refresh_token,
          syncLogId: logId, batchSize: 5, maxConcurrent: 1 }), signal: AbortSignal.timeout(20000),
      });
      if (!response.ok) throw new Error('Sync dispatch failed');
      return xboxJson({ success: true, message: 'Xbox sync started', syncLogId: logId });
    } catch {
      if (admin && owner && logId != null) {
        await admin.rpc('finish_platform_sync', { p_user_id: owner, p_platform: 'xbox', p_log_id: logId,
          p_outcome: 'failed', p_error: 'Xbox sync could not reach the sync service. Try again.' });
      }
      return xboxJson({ error: 'Xbox sync could not start. Try again.' }, 503);
    }
  };
}
