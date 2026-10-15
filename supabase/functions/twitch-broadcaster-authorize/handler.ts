export interface BroadcasterAuthorizationDeps {
 env:(name:string)=>string|undefined;
 rpc:(name:string,args?:Record<string,unknown>)=>PromiseLike<{data:any;error:any}>;
 request:typeof fetch;
}
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
async function sha256(value:string) {
 return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))),b=>b.toString(16).padStart(2,'0')).join('');
}
function page(message:string,status=200) {
 const script="history.replaceState(null,'',location.pathname);";
 const nonce=crypto.randomUUID();
 return new Response(`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>StatusXP Twitch connection</title><style>body{font:18px system-ui,sans-serif;background:#0b0c13;color:#f3f5ff;margin:0;padding:40px 24px}main{max-width:560px;margin:40px auto;line-height:1.6}h1{font-size:28px}</style><main><h1>StatusXP Twitch connection</h1><p>${message}</p><p>You can close this tab and return to the conversation. No codes or keys need to be copied.</p></main><script nonce="${nonce}">${script}</script></html>`,{status,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff','X-Frame-Options':'DENY','Content-Security-Policy':`default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'`}});
}
export function createBroadcasterAuthorizationHandler(deps:BroadcasterAuthorizationDeps) {
 return async(req:Request):Promise<Response>=>{
  const id=deps.env('TWITCH_CLIENT_ID'),secret=deps.env('TWITCH_CLIENT_SECRET'),broadcaster=deps.env('TWITCH_BROADCASTER_ID');
  const base=deps.env('SUPABASE_URL');
  if(!id||!secret||!broadcaster||!base)return json({error:'Twitch configuration unavailable'},503);
  const redirect=`${base.replace(/\/$/,'')}/functions/v1/twitch-broadcaster-authorize`;
  if(req.method==='POST') {
   const service=deps.env('SUPABASE_SERVICE_ROLE_KEY');
   if(!service||req.headers.get('Authorization')!==`Bearer ${service}`)return json({error:'Unauthorized'},401);
   const state=Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');
   const saved=await deps.rpc('begin_twitch_broadcaster_authorization',{p_state_hash:await sha256(state)});
   if(saved.error)return json({error:'Could not prepare authorization'},503);
   const url=new URL('https://id.twitch.tv/oauth2/authorize');
   url.search=new URLSearchParams({client_id:id,redirect_uri:redirect,response_type:'code',scope:'channel:read:subscriptions',state,force_verify:'true'}).toString();
   return json({authorization_url:url.toString(),expires_in_seconds:1800});
  }
  if(req.method!=='GET')return json({error:'Use GET or POST'},405);
  const url=new URL(req.url);const state=url.searchParams.get('state');
  if(!state||!/^[a-f0-9]{64}$/.test(state))return page('This authorization link is missing or expired. Request a fresh link in the conversation.',400);
  const stateHash=await sha256(state);
  let token:string|undefined;let saved=false;
  try{
   const claimed=await deps.rpc('claim_twitch_broadcaster_authorization',{p_state_hash:stateHash});
   if(claimed.error||claimed.data!==true)return page('This authorization link has expired or was already used. Request a fresh link in the conversation.',400);
   if(url.searchParams.has('error'))return page('Twitch permission was not granted. Your existing settings have been kept.',400);
   const code=url.searchParams.get('code');if(!code)return page('Twitch did not return an authorization code. Request a fresh link.',400);
   const exchange=await deps.request('https://id.twitch.tv/oauth2/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:id,client_secret:secret,code,grant_type:'authorization_code',redirect_uri:redirect}),signal:AbortSignal.timeout(15000)});
   if(!exchange.ok)return page('Twitch could not complete this sign-in. Request a fresh authorization link.',503);
   const tokens=await exchange.json();token=typeof tokens.access_token==='string'?tokens.access_token:undefined;
   if(!token||typeof tokens.refresh_token!=='string'||!tokens.refresh_token)return page('Twitch did not return a renewable connection. Request a fresh link.',503);
   const validation=await deps.request('https://id.twitch.tv/oauth2/validate',{headers:{Authorization:`OAuth ${token}`},signal:AbortSignal.timeout(15000)});
   if(!validation.ok)return page('Twitch could not verify this sign-in. Request a fresh link.',503);
   const info=await validation.json();
   if(info.client_id!==id||info.user_id!==broadcaster||!Array.isArray(info.scopes)||!info.scopes.includes('channel:read:subscriptions'))return page('Sign in with the Twitch account that owns the StatusXP subscription channel, then approve subscriber access. Request a fresh link before trying again.',403);
   const lifetime=Math.min(Number(tokens.expires_in),Number(info.expires_in));
   if(!Number.isSafeInteger(lifetime)||lifetime<60)return page('Twitch returned an expired connection. Request a fresh link.',503);
   const checkUrl=new URL('https://api.twitch.tv/helix/subscriptions');checkUrl.search=new URLSearchParams({broadcaster_id:broadcaster,first:'1'}).toString();
   const checked=await deps.request(checkUrl,{headers:{Authorization:`Bearer ${token}`,'Client-Id':id},signal:AbortSignal.timeout(15000)});
   if(!checked.ok)return page('Twitch has not granted access to the channel subscription list. Request a fresh link and approve subscriber access.',503);
   const list=await checked.json();if(!Array.isArray(list.data))return page('Twitch could not verify subscriber access. Request a fresh link.',503);
   const stored=await deps.rpc('save_verified_twitch_broadcaster_authorization',{p_state_hash:stateHash,p_broadcaster_id:broadcaster,p_client_id:id,p_access_token:token,p_refresh_token:tokens.refresh_token,p_expires_at:new Date(Date.now()+lifetime*1000).toISOString()});
   if(stored.error)return page('Your connection could not be saved. Request a fresh authorization link.',503);
   saved=true;
   return page('Connected successfully. StatusXP can now check your channel subscriptions. The connection will renew automatically.');
  }catch{return page('Twitch authorization is temporarily unavailable. Your existing settings have been kept. Request a fresh link to retry.',503);}
  finally{
   if(token&&!saved){try{await deps.request('https://id.twitch.tv/oauth2/revoke',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:id,token}),signal:AbortSignal.timeout(10000)});}catch{/* Never disclose an unused token. */}}
  }
 };
}
