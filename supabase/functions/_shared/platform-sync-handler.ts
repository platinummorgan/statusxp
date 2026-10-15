import { XboxHandlerDeps, xboxClients, xboxCorsHeaders as cors, xboxJson as json } from './xbox-handler.ts';
export interface PlatformSyncDeps extends XboxHandlerDeps {
  quotaResponse: (owner: string, provider: string, headers: Record<string,string>) => Promise<Response|null>;
  refreshPsn?: (token: string) => Promise<{accessToken: string;refreshToken?: string}>;
}
export function createPlatformStartHandler(platform: 'psn'|'steam', deps: PlatformSyncDeps) {
 return async (req: Request): Promise<Response> => {
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
  if(req.method!=='POST') return json({error:'Use POST.'},405);
  let admin:any; let owner:string|undefined; let logId:number|undefined;
  let message='Sync could not start. Try again.'; let requiresRelink=false;
  try {
   const clients=await xboxClients(req,deps);
   if(!clients) return json({error:'Unauthorized'},401);
   admin=clients.admin; owner=clients.user.id;
   const fields=platform==='psn'?'psn_account_id,psn_access_token,psn_refresh_token,psn_sync_status':'steam_id,steam_api_key,steam_sync_status';
   const result=await admin.from('profiles').select(fields).eq('id',owner).single();
   if(result.error) return json({error:'Could not load the connection. Try again.'},503);
   const p=result.data; const account=platform==='psn'?p?.psn_account_id:p?.steam_id;
   if(!account || (platform==='psn'&&!p.psn_refresh_token)) return json({error:'Reconnect your account to sync.',requiresRelink:true},400);
   if(['syncing','cancelling'].includes(p[`${platform}_sync_status`])) return json({error:'Sync already in progress.'},409);
   const denied=await deps.quotaResponse(owner!,`sync_${platform}`,cors); if(denied) return denied;
   const started=await admin.rpc('begin_verified_platform_sync',{p_user_id:owner,p_platform:platform,p_expected_account_id:account});
   if(started.error) return json({error:started.error.code==='55000'?started.error.message:'Could not start sync. Try again.'},started.error.code==='55000'?409:503);
   logId=started.data;
   let payload:any={userId:owner,syncLogId:logId,batchSize:5,maxConcurrent:1};
   if(platform==='psn') {
    let tokens;
    try { tokens=await deps.refreshPsn!(p.psn_refresh_token); }
    catch(e) {
     requiresRelink=/invalid_grant|invalid_client|unauthorized|expired|\b401\b|\b403\b/i.test(e instanceof Error?e.message:String(e));
     message=requiresRelink?'PlayStation session expired. Reconnect PlayStation in Settings, then sync again.':'PlayStation could not refresh your session. Try again.';
     throw new Error(message);
    }
    if(!tokens.accessToken) throw new Error('Missing refreshed token');
    const refresh=tokens.refreshToken||p.psn_refresh_token;
    const saved=await admin.from('profiles').update({psn_access_token:tokens.accessToken,psn_refresh_token:refresh})
     .eq('id',owner).eq('psn_account_id',account).select('id').single();
    if(saved.error||!saved.data) throw new Error('Could not save refreshed session');
    payload={...payload,accountId:account,accessToken:tokens.accessToken,refreshToken:refresh};
   } else payload={...payload,steamId:account,...(p.steam_api_key?{apiKey:p.steam_api_key}:{})};
   const secret=deps.env('SYNC_SERVICE_SECRET'); if(!secret) throw new Error('Service authentication unavailable');
   const sent=await deps.fetch(`https://statusxp-production.up.railway.app/sync/${platform}`,{
    method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${secret}`},body:JSON.stringify(payload),signal:AbortSignal.timeout(20000)});
   if(!sent.ok) throw new Error('Dispatch failed');
   return json({success:true,message:platform==='psn'?'PSN sync started':'Steam sync started',syncLogId:logId});
  } catch {
   if(admin&&owner&&logId!=null) await admin.rpc('finish_platform_sync',{p_user_id:owner,p_platform:platform,p_log_id:logId,p_outcome:'failed',p_error:message});
   return json({error:message,requiresRelink},requiresRelink?400:503);
  }
 };
}
export function createPlatformStopHandler(platform:'psn'|'steam',deps:XboxHandlerDeps) {
 return async(req:Request):Promise<Response>=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
  if(req.method!=='POST') return json({error:'Use POST.'},405);
  try {
   const clients=await xboxClients(req,deps); if(!clients) return json({error:'Unauthorized'},401);
   const result=await clients.admin.rpc('request_sync_cancellation',{p_user_id:clients.user.id,p_platform:platform});
   if(result.error) throw new Error('Cancellation unavailable');
   return json({success:true,message:result.data==='cancelling'?'Sync stop requested successfully':'No active sync'});
  }catch{return json({error:'Could not request cancellation. Try again.'},503);}
 };
}
