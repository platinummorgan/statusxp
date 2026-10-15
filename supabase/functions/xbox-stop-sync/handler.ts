import { XboxHandlerDeps, xboxClients, xboxCorsHeaders, xboxJson } from '../_shared/xbox-handler.ts';
export function createXboxStopHandler(deps: XboxHandlerDeps) {
 return async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: xboxCorsHeaders });
  if (req.method !== 'POST') return xboxJson({ error: 'Use POST.' },405);
  try {
   const clients=await xboxClients(req,deps);
   if (!clients) return xboxJson({error:'Unauthorized'},401);
   const cancelled=await clients.admin.rpc('request_sync_cancellation',{p_user_id:clients.user.id,p_platform:'xbox'});
   if(cancelled.error) return xboxJson({error:'Could not request Xbox cancellation. Try again.'},503);
   return xboxJson({success:true,message:cancelled.data==='cancelling'?'Sync stop requested successfully':'No active Xbox sync'});
  } catch { return xboxJson({error:'Could not request Xbox cancellation. Try again.'},503); }
 };
}
