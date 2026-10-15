import { XboxHandlerDeps, xboxClients, xboxCorsHeaders as cors, xboxJson as json } from '../_shared/xbox-handler.ts';
import { completeSecurityReconnect } from '../_shared/security-reconnect.ts';
export function createVerifySecurityReconnectHandler(deps: XboxHandlerDeps) {
 return async (req: Request): Promise<Response> => {
  if (req.method==='OPTIONS') return new Response('ok',{headers:cors});
  if (req.method!=='POST') return json({error:'Use POST.'},405);
  try {
   const clients=await xboxClients(req,deps);
   if (!clients) return json({error:'Unauthorized'},401);
   const {admin,user}=clients;
   const loaded=await admin.from('profiles').select('steam_id,steam_api_key').eq('id',user.id).single();
   if (loaded.error || !loaded.data?.steam_id || !loaded.data?.steam_api_key) return json({error:'Save your replacement Steam key first.'},400);
   const {steam_id,steam_api_key}=loaded.data;
   const url=new URL('https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/');
   url.search=new URLSearchParams({key:steam_api_key,steamids:steam_id}).toString();
   const response=await deps.fetch(url,{signal:AbortSignal.timeout(15000)});
   if(!response.ok) return json({error:'Steam could not verify that key. Check your replacement key and try again.'},400);
   const data=await response.json();
   if(!data.response?.players?.some((player:any)=>String(player.steamid)===String(steam_id))) return json({error:'Steam could not verify this account. Reconnect the same Steam account.'},400);
   const saved=await completeSecurityReconnect(admin,user.id,'steam',steam_id,steam_api_key);
   if(saved.error) return json({error:saved.error.code==='55000'?saved.error.message:'Could not save your reconnect. Try again.'},saved.error.code==='55000'?409:503);
   return json({success:true,reconnected:saved.data===true});
  }catch{return json({error:'Steam verification is temporarily unavailable. Try again.'},503);}
 };
}
