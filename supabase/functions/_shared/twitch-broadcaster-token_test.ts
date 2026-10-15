import assert from 'node:assert/strict';
import { getTwitchBroadcasterToken } from './twitch-broadcaster-token.ts';
function fixture(options:any={}) {
 const calls:any[]=[];let current:any=options.absent?null:{client_id:'client',broadcaster_id:'47221283',access_token:'old-access',refresh_token:'refresh',revision:1,expires_at:new Date(Date.now()+(options.valid?3600000:-60000)).toISOString()};
 const deps={clientId:'client',clientSecret:'secret',broadcasterId:'47221283',legacyToken:'legacy',sleep:async()=>{},
  rpc:async(name:string,args:any)=>{calls.push({name,args});
   if(name==='get_twitch_broadcaster_credentials')return {data:current,error:null};
   if(name==='claim_twitch_broadcaster_refresh'){
    if(options.concurrent){current={...current,revision:2,access_token:'other-worker-access',expires_at:new Date(Date.now()+3600000).toISOString()};return {data:false,error:null};}
    return {data:true,error:null};
   }
   return {data:true,error:options.saveFailure&&name==='save_twitch_broadcaster_refresh'?{}:null};
  },request:async(input:any)=>{calls.push({url:String(input)});
   if(String(input).endsWith('/token'))return new Response(JSON.stringify({access_token:'fresh-access',refresh_token:'fresh-refresh',expires_in:3600}),{status:options.providerFailure?401:200});
   return new Response(JSON.stringify({client_id:'client',user_id:options.wrongOwner?'other':'47221283',scopes:['channel:read:subscriptions'],expires_in:3500}));
  }};return {deps,calls};
}
Deno.test('legacy compatibility is retained before owner approval; fresh stored tokens do not refresh',async()=>{
 const legacy=fixture({absent:true});assert.equal(await getTwitchBroadcasterToken(legacy.deps),'legacy');assert.equal(legacy.calls.some(c=>c.url),false);
 await assert.rejects(()=>getTwitchBroadcasterToken(legacy.deps,true));
 const valid=fixture({valid:true});assert.equal(await getTwitchBroadcasterToken(valid.deps),'old-access');assert.equal(valid.calls.some(c=>c.url),false);
});
Deno.test('expired token renewal is leased, identity-verified, and saved with both new tokens',async()=>{
 const f=fixture();assert.equal(await getTwitchBroadcasterToken(f.deps),'fresh-access');const saved=f.calls.find(c=>c.name==='save_twitch_broadcaster_refresh');assert.equal(saved.args.p_refresh_token,'fresh-refresh');assert.equal(saved.args.p_revision,1);assert.ok(f.calls.some(c=>c.name==='release_twitch_broadcaster_refresh'));
});
Deno.test('another worker refresh is reused without a second provider exchange',async()=>{
 const f=fixture({concurrent:true});assert.equal(await getTwitchBroadcasterToken(f.deps),'other-worker-access');assert.equal(f.calls.some(c=>c.url),false);
});
Deno.test('provider, identity or storage errors fail closed and release the lease',async()=>{
 for(const options of [{providerFailure:true},{wrongOwner:true},{saveFailure:true}]){
  const f=fixture(options);await assert.rejects(()=>getTwitchBroadcasterToken(f.deps));assert.ok(f.calls.some(c=>c.name==='release_twitch_broadcaster_refresh'));
 }
});
Deno.test('unauthorized token can refresh once even before its recorded expiration',async()=>{
 const f=fixture({valid:true});assert.equal(await getTwitchBroadcasterToken(f.deps,true),'fresh-access');
});
