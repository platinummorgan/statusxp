import { createPlatformStartHandler, createPlatformStopHandler } from '../functions/_shared/platform-sync-handler.ts';
import { createPsnLinkHandler } from '../functions/psn-link-account/handler.ts';
function equal(a:unknown,b:unknown){if(JSON.stringify(a)!==JSON.stringify(b))throw new Error(`Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);}
const request=(body:any={})=>new Request('https://edge.invalid',{method:'POST',headers:{Authorization:'Bearer fixture'},body:JSON.stringify(body)});
function fixture(options:any={}) {
 const calls:any[]=[];const factories:any[]=[];
 const caller={auth:{getUser:async()=>({data:{user:options.unauthorized?null:{id:'owner'}},error:null})},from:()=>{throw new Error('Caller accessed private data');}};
 const profile={psn_account_id:'12345',psn_access_token:'saved-access',psn_refresh_token:'saved-refresh',psn_sync_status:options.status||'success',steam_id:'76561198000000001',steam_api_key:'private-steam-key',steam_sync_status:options.status||'success'};
 const admin={from:(table:string)=>{
  let updating=false;
  const query:any={select:()=>query,eq:(key:string,value:any)=>{calls.push({table,key,value});return query;},neq:()=>query,not:()=>query,
   limit:async()=>({data:options.duplicate?[{id:'other'}]:[],error:null}),
   single:async()=>({data:profile,error:options.saveError&&updating?{code:'PGRST116'}:null}),
   update:(values:any)=>{updating=true;calls.push({table,values});return query;},upsert:async(values:any)=>{calls.push({table,values});return {error:null};}};return query;},
  rpc:async(name:string,args:any)=>{calls.push({name,args});return {data:name==='begin_verified_platform_sync'?42:'cancelling',error:null};}};
 const deps:any={env:(name:string)=>({SUPABASE_URL:'https://db.invalid',SUPABASE_ANON_KEY:'anon',SUPABASE_SERVICE_ROLE_KEY:'service',SYNC_SERVICE_SECRET:'server-secret'} as any)[name],
  createClient:(_url:string,key:string,config:any)=>{factories.push({key,config});return key==='service'?admin:caller;},quotaResponse:async()=>options.quota?new Response('{}',{status:429}):null,
  refreshPsn:async(token:string)=>{calls.push({refresh:token});if(options.tokenError)throw new Error('invalid_grant');return {accessToken:'rotated-access',refreshToken:'rotated-refresh'};},
  fetch:async(url:any,init:any)=>{calls.push({url:String(url),payload:JSON.parse(init.body)});return new Response('{}',{status:options.dispatchError?503:200});},
  exchangeNpssoForAccessCode:async()=> 'code',exchangeAccessCodeForAuthTokens:async()=>({accessToken:'sony-access',refreshToken:'sony-refresh',expiresIn:3600}),
  getUserProfile:async()=>({accountId:'12345',onlineId:'NewName',avatarUrls:[],isPlus:false}),extractAccountIdFromAccessToken:()=> '12345',
  getUserTrophyProfileSummary:async()=>{throw new Error('Optional summary unavailable');},uploadExternalAvatar:async()=>null};
 return {deps,calls,factories};
}
for(const platform of ['psn','steam'] as const){
 Deno.test(`${platform} starts only authenticated owner using server credentials`,async()=>{
  const f=fixture();const response=await createPlatformStartHandler(platform,f.deps)(request({userId:'victim',apiKey:'forged',refreshToken:'forged'}));equal(response.status,200);
  const sent=f.calls.find(c=>c.url);equal(sent.payload.userId,'owner');equal(sent.payload.syncLogId,42);
  equal(platform==='psn'?sent.payload.refreshToken:sent.payload.apiKey,platform==='psn'?'rotated-refresh':'private-steam-key');
  const saved=f.factories.find(c=>c.key==='service');equal(saved.config.global,undefined);
  if(JSON.stringify(await response.json()).includes('rotated-'))throw new Error('Credential leak');
 });
 Deno.test(`${platform} blocks active/cancelling and quota denial`,async()=>{
  for(const status of ['syncing','cancelling']){const f=fixture({status});equal((await createPlatformStartHandler(platform,f.deps)(request())).status,409);equal(f.calls.some(c=>c.name),false);}
  const f=fixture({quota:true});equal((await createPlatformStartHandler(platform,f.deps)(request())).status,429);equal(f.calls.some(c=>c.name),false);
 });
 Deno.test(`${platform} dispatch failure is terminal and cancellation uses owner`,async()=>{
  const f=fixture({dispatchError:true});equal((await createPlatformStartHandler(platform,f.deps)(request())).status,503);equal(f.calls.find(c=>c.name==='finish_platform_sync').args.p_outcome,'failed');
  const stop=fixture();equal((await createPlatformStopHandler(platform,stop.deps)(request({userId:'victim'}))).status,200);equal(stop.calls[0].args.p_user_id,'owner');equal(stop.calls[0].args.p_platform,platform);
 });
 Deno.test(`${platform} rejects unauthenticated caller`,async()=>{const f=fixture({unauthorized:true});equal((await createPlatformStartHandler(platform,f.deps)(request())).status,401);equal(f.calls.length,0);});
}
Deno.test('PSN expired refresh fails before dispatch and records failure',async()=>{
 const f=fixture({tokenError:true});const response=await createPlatformStartHandler('psn',f.deps)(request());equal(response.status,400);equal((await response.json()).requiresRelink,true);equal(f.calls.some(c=>c.url),false);equal(f.calls.find(c=>c.name==='finish_platform_sync').args.p_log_id,42);
});
Deno.test('PSN reconnect saves Sony credentials as server and tolerates optional summary failure',async()=>{
 const f=fixture();const response=await createPsnLinkHandler(f.deps)(request({npssoToken:'npsso'}));equal(response.status,200);equal(f.calls.find(c=>c.values).values.psn_account_id,'12345');equal((await response.json()).trophySummaryAvailable,false);
});
Deno.test('PSN reconnect blocks duplicate durable account ID and active sync',async()=>{
 for(const options of [{duplicate:true},{status:'syncing'},{status:'cancelling'},{saveError:true}]){const f=fixture(options);equal((await createPsnLinkHandler(f.deps)(request({npssoToken:'npsso'}))).status,409);}
});
