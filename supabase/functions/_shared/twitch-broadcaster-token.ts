export interface BroadcasterTokenDeps {
 rpc:(name:string,args?:Record<string,unknown>)=>PromiseLike<{data:any;error:any}>;
 request:typeof fetch;
 clientId:string;
 clientSecret:string;
 broadcasterId:string;
 legacyToken?:string;
 sleep?:(ms:number)=>Promise<void>;
}
export async function getTwitchBroadcasterToken(deps:BroadcasterTokenDeps,forceRefresh=false):Promise<string> {
 const read=async()=>{
  const result=await deps.rpc('get_twitch_broadcaster_credentials');
  if(result.error)throw new Error('Twitch connection unavailable');
  return result.data;
 };
 let current=await read();
 if(!current){
  if(deps.legacyToken&&!forceRefresh)return deps.legacyToken;
  throw new Error('Twitch channel authorization must be renewed');
 }
 const startingRevision=current.revision;
 for(let attempt=0;attempt<6;attempt++){
  if(current.client_id!==deps.clientId||current.broadcaster_id!==deps.broadcasterId)throw new Error('Twitch connection identity mismatch');
  if((!forceRefresh||current.revision!==startingRevision)&&Date.parse(current.expires_at)>Date.now()+60000)return current.access_token;
  if(!deps.clientSecret||!current.refresh_token)throw new Error('Twitch channel authorization must be renewed');
  const lease=crypto.randomUUID();
  const claimed=await deps.rpc('claim_twitch_broadcaster_refresh',{p_revision:current.revision,p_lease:lease});
  if(claimed.error)throw new Error('Twitch token renewal unavailable');
  if(claimed.data===true){
   try{
    const response=await deps.request('https://id.twitch.tv/oauth2/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'refresh_token',refresh_token:current.refresh_token,client_id:deps.clientId,client_secret:deps.clientSecret}),signal:AbortSignal.timeout(15000)});
    if(!response.ok)throw new Error('Twitch token renewal failed');
    const tokens=await response.json();
    if(typeof tokens.access_token!=='string'||!tokens.access_token||typeof tokens.refresh_token!=='string'||!tokens.refresh_token)throw new Error('Twitch returned an incomplete token renewal');
    const validation=await deps.request('https://id.twitch.tv/oauth2/validate',{headers:{Authorization:`OAuth ${tokens.access_token}`},signal:AbortSignal.timeout(15000)});
    if(!validation.ok)throw new Error('Twitch token renewal could not be verified');
    const info=await validation.json();
    const lifetime=Math.min(Number(tokens.expires_in),Number(info.expires_in));
    if(info.client_id!==deps.clientId||info.user_id!==deps.broadcasterId||!Array.isArray(info.scopes)||!info.scopes.includes('channel:read:subscriptions')||!Number.isSafeInteger(lifetime)||lifetime<60)throw new Error('Twitch token renewal identity or permissions mismatch');
    const saved=await deps.rpc('save_twitch_broadcaster_refresh',{p_revision:current.revision,p_lease:lease,p_access_token:tokens.access_token,p_refresh_token:tokens.refresh_token,p_expires_at:new Date(Date.now()+lifetime*1000).toISOString()});
    if(saved.error)throw new Error('Twitch token renewal could not be saved');
    if(saved.data===true)return tokens.access_token;
    const latest=await read();
    if(latest&&latest.revision!==current.revision&&latest.client_id===deps.clientId&&latest.broadcaster_id===deps.broadcasterId&&Date.parse(latest.expires_at)>Date.now()+60000)return latest.access_token;
    throw new Error('Twitch connection changed during renewal');
   }finally{
    await deps.rpc('release_twitch_broadcaster_refresh',{p_revision:current.revision,p_lease:lease});
   }
  }
  await (deps.sleep??((ms)=>new Promise(resolve=>setTimeout(resolve,ms))))(200);
  current=await read();if(!current)throw new Error('Twitch channel authorization must be renewed');
 }
 throw new Error('Twitch connection renewal is in progress');
}
