import { createXboxLinkHandler } from '../functions/xbox-link-account/handler.ts';
import { createXboxStartHandler } from '../functions/xbox-start-sync/handler.ts';
import { createXboxStopHandler } from '../functions/xbox-stop-sync/handler.ts';
function equal(a: unknown,b: unknown) { if (JSON.stringify(a)!==JSON.stringify(b)) throw new Error(`Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`); }
function fixture(options: any = {}) {
 const calls: any[]=[];const queries: any[]=[];const factories: any[]=[];
 const caller={auth:{getUser:async()=>options.unauthorized?{data:{user:null},error:{}}:{data:{user:{id:'owner'}},error:null}},from:()=>{throw new Error('Caller tried to read protected credentials');}};
 const admin={from:(table:string)=>({select:()=>({eq:(column:string,value:string)=>{queries.push({table,column,value});return {single:async()=>({data:{xbox_xuid:'2533274999999971',xbox_user_hash:'hash',xbox_access_token:'saved-access',xbox_refresh_token:'saved-refresh',xbox_sync_status:options.status||'success'},error:null})};}})}),rpc:async(name:string,args:any)=>{calls.push({name,args});return {data:name==='begin_verified_xbox_sync'?42:name==='request_sync_cancellation'?'cancelling':null,error:options.rpcError?.[name]||null};}};
 const deps={env:(name:string)=>({'SUPABASE_URL':'https://database.invalid','SUPABASE_ANON_KEY':'anon-fixture','SUPABASE_SERVICE_ROLE_KEY':'service-fixture','SYNC_SERVICE_SECRET':'sync-fixture'} as any)[name],
 createClient:(_url:string,key:string,config:any)=>{factories.push({key,config});return key==='service-fixture'?admin:caller;},
 quotaResponse:async()=>options.denied?new Response('{}',{status:429}):null,
 fetch:async(url:any,init:any)=>{
  calls.push({url:String(url),body:init?.body?String(init.body):null,headers:init?.headers});
  const json=(body:any)=>new Response(JSON.stringify(body),{headers:{'Content-Type':'application/json'}});
  if(String(url).includes('oauth20_token'))return options.noRefresh?json({access_token:'ms-access'}):json({access_token:'ms-access',refresh_token:'ms-refresh'});
  if(String(url).includes('user/authenticate'))return json({Token:'xbl-token'});
  if(String(url).includes('xsts/authorize'))return json({Token:'xsts-token',NotAfter:new Date(Date.now()+86400000).toISOString(),DisplayClaims:{xui:[{xid:'2533274999999971',uhs:'hash'}]}});
  if(String(url).includes('profile/settings'))return json({profileUsers:[{id:options.profileMismatch?'different':'2533274999999971',settings:[{id:'Gamertag',value:'Player'},{id:'Gamerscore',value:'100'}]}]});
  if(String(url).includes('titlehistory'))return json({titles:[{titleId:1,achievement:{currentAchievements:5}}]});
  if(String(url).includes('/sync/xbox'))return new Response('{}',{status:options.dispatchFailure?503:200});
  throw new Error('Unexpected request');
 }};return {deps,calls,queries,factories};
}
const request=(body:any={},authenticated=true)=>new Request('https://edge.invalid',{method:'POST',headers:{'Content-Type':'application/json',...(authenticated?{Authorization:'Bearer user-fixture'}:{})},body:JSON.stringify(body)});
Deno.test('all Xbox handlers reject unauthenticated callers before creating the server client',async()=>{
 for(const factory of [createXboxLinkHandler,createXboxStartHandler,createXboxStopHandler]){
  const f=fixture({unauthorized:true});equal((await factory(f.deps)(request({authCode:'code'}))).status,401);equal(f.factories.length,1);equal(f.calls.length,0);
 }
});
Deno.test('link derives identity from Xbox, writes with service privileges and returns no credentials',async()=>{
 const f=fixture();const response=await createXboxLinkHandler(f.deps)(request({authCode:'code',userId:'victim',xuid:'forged'}));equal(response.status,200);
 const rpc=f.calls.find(c=>c.name==='link_verified_xbox_account');equal(rpc.args.p_user_id,'owner');equal(rpc.args.p_xuid,'2533274999999971');equal(rpc.args.p_refresh_token,'ms-refresh');
 const body=await response.json();equal(body.totalAchievements,5);equal(body.success,true);if(JSON.stringify(body).includes('token')||JSON.stringify(body).includes('ms-refresh'))throw new Error('Credential leaked');
 equal(f.factories[1].key,'service-fixture');if(f.factories[1].config.global)throw new Error('Server client inherited user authorization');
});
Deno.test('link requires Microsoft offline access and validates Xbox profile identity',async()=>{
 for(const options of [{noRefresh:true},{profileMismatch:true}]){
  const f=fixture(options);equal((await createXboxLinkHandler(f.deps)(request({authCode:'code'}))).status,400);equal(f.calls.filter(c=>c.name==='link_verified_xbox_account').length,0);
 }
});
Deno.test('access-token-only reconnect asks the database to preserve the existing refresh token',async()=>{
 const f=fixture();equal((await createXboxLinkHandler(f.deps)(request({accessToken:'ms-access'}))).status,200);
 equal(f.calls.find(c=>c.name==='link_verified_xbox_account').args.p_refresh_token,'');
});
Deno.test('account identity conflict is a clear 409 response without exposing another user',async()=>{
 const f=fixture({rpcError:{link_verified_xbox_account:{code:'55000',message:'Reconnect the original Xbox account.'}}});const r=await createXboxLinkHandler(f.deps)(request({authCode:'code'}));equal(r.status,409);equal((await r.json()).error,'Reconnect the original Xbox account.');
});
Deno.test('sync start reads private credentials with server privileges and ignores supplied owner or tokens',async()=>{
 const f=fixture();const r=await createXboxStartHandler(f.deps)(request({userId:'victim',accessToken:'forged'}));equal(r.status,200);equal(f.queries[0].value,'owner');
 const began=f.calls.find(c=>c.name==='begin_verified_xbox_sync');equal(began.args.p_user_id,'owner');const payload=JSON.parse(f.calls.find(c=>c.url?.endsWith('/sync/xbox')).body);equal(payload.userId,'owner');equal(payload.accessToken,'saved-access');equal(payload.syncLogId,42);
 const body=await r.json();equal(body.syncLogId,42);if(JSON.stringify(body).includes('saved-'))throw new Error('Credential leaked');
});
Deno.test('sync start rejects active/cancelling jobs and closes the log after dispatch failure',async()=>{
 for(const status of ['syncing','cancelling']){const f=fixture({status});equal((await createXboxStartHandler(f.deps)(request())).status,409);equal(f.calls.length,0);}
 const f=fixture({dispatchFailure:true});equal((await createXboxStartHandler(f.deps)(request())).status,503);equal(f.calls.find(c=>c.name==='finish_platform_sync').args.p_log_id,42);
});
Deno.test('quota denial does not start a log or dispatch Xbox credentials',async()=>{
 const f=fixture({denied:true});equal((await createXboxStartHandler(f.deps)(request())).status,429);equal(f.calls.length,0);
});
Deno.test('stop uses the authenticated owner and the atomic cancellation RPC',async()=>{
 const f=fixture();equal((await createXboxStopHandler(f.deps)(request({userId:'victim'}))).status,200);equal(f.calls[0].name,'request_sync_cancellation');equal(f.calls[0].args.p_user_id,'owner');
});
Deno.test('only a fresh Microsoft code grant completes a security reconnect',async()=>{
 const fresh=fixture();equal((await createXboxLinkHandler(fresh.deps)(request({authCode:'new-code'}))).status,200);
 const completed=fresh.calls.find(c=>c.name==='complete_verified_security_reconnect');equal(completed.args.p_platform,'xbox');equal(completed.args.p_user_id,'owner');equal(completed.args.p_verified_credential_hash.length,64);
 const accessOnly=fixture();equal((await createXboxLinkHandler(accessOnly.deps)(request({accessToken:'ordinary-refreshed-access'}))).status,200);equal(accessOnly.calls.some(c=>c.name==='complete_verified_security_reconnect'),false);
});
