import assert from 'node:assert/strict';
import { createBroadcasterAuthorizationHandler } from './handler.ts';
function fixture(options:any={}) {
 const calls:any[]=[];
 const deps={env:(name:string)=>({SUPABASE_URL:'https://project.invalid',SUPABASE_SERVICE_ROLE_KEY:'service-fixture',TWITCH_CLIENT_ID:'app-fixture',TWITCH_CLIENT_SECRET:'secret-fixture',TWITCH_BROADCASTER_ID:'47221283'} as any)[name],
  rpc:async(name:string,args:any)=>{calls.push({name,args});return {data:name==='claim_twitch_broadcaster_authorization'?!options.claimDenied:null,error:options.saveFailure&&name==='save_verified_twitch_broadcaster_authorization'?{}:null};},
  request:async(input:any,init:any)=>{
   const url=String(input);calls.push({url,init});const response=(body:any,status=200)=>new Response(JSON.stringify(body),{status});
   if(url.endsWith('/oauth2/token'))return response({access_token:'new-access',refresh_token:'new-refresh',expires_in:3600});
   if(url.endsWith('/oauth2/validate'))return response({client_id:options.wrongApp?'other':'app-fixture',user_id:options.wrongOwner?'other':'47221283',scopes:options.missingScope?[]:['channel:read:subscriptions'],expires_in:3500});
   if(url.includes('/helix/subscriptions'))return response({data:[]},options.readDenied?403:200);
   if(url.endsWith('/oauth2/revoke'))return response({});
   throw new Error('Unexpected provider request');
  },
 };
 return {deps,calls};
}
const callback=(extra='')=>new Request(`https://project.invalid/functions/v1/twitch-broadcaster-authorize?state=${'a'.repeat(64)}&code=single-use-code${extra}`);
Deno.test('only server administrator can create approval links; only the hash is persisted',async()=>{
 const f=fixture();const handler=createBroadcasterAuthorizationHandler(f.deps);
 assert.equal((await handler(new Request('https://project.invalid',{method:'POST'}))).status,401);assert.equal(f.calls.length,0);
 const response=await handler(new Request('https://project.invalid',{method:'POST',headers:{Authorization:'Bearer service-fixture'}}));assert.equal(response.status,200);
 const data=await response.json();const url=new URL(data.authorization_url);assert.equal(url.origin,'https://id.twitch.tv');assert.equal(url.searchParams.get('scope'),'channel:read:subscriptions');assert.equal(url.searchParams.get('redirect_uri'),'https://project.invalid/functions/v1/twitch-broadcaster-authorize');
 const state=url.searchParams.get('state')!;assert.equal(state.length,64);assert.notEqual(f.calls[0].args.p_state_hash,state);assert.equal(f.calls[0].args.p_state_hash.length,64);
 assert.equal(JSON.stringify(data).includes('secret-fixture'),false);
});
Deno.test('invalid or consumed state never exchanges a provider code',async()=>{
 for(const invalid of [new Request('https://project.invalid'),callback()]){
  const f=fixture({claimDenied:true});assert.equal((await createBroadcasterAuthorizationHandler(f.deps)(invalid)).status,400);assert.equal(f.calls.some(c=>c.url),false);
 }
});
Deno.test('only the expected channel owner and subscriber-read permission can be stored',async()=>{
 for(const options of [{wrongOwner:true},{wrongApp:true},{missingScope:true},{readDenied:true},{saveFailure:true}]){
  const f=fixture(options);const response=await createBroadcasterAuthorizationHandler(f.deps)(callback());assert.ok(response.status>=400);
  assert.equal(f.calls.some(c=>c.url?.endsWith('/oauth2/revoke')),true);
  if(!options.saveFailure)assert.equal(f.calls.some(c=>c.name==='save_verified_twitch_broadcaster_authorization'),false);
  const text=await response.text();assert.equal(/new-access|new-refresh|single-use-code/.test(text),false);
 }
});
Deno.test('successful authorization verifies subscription access and stores renewable credentials privately',async()=>{
 const f=fixture();const response=await createBroadcasterAuthorizationHandler(f.deps)(callback());assert.equal(response.status,200);
 const saved=f.calls.find(c=>c.name==='save_verified_twitch_broadcaster_authorization');assert.equal(saved.args.p_broadcaster_id,'47221283');assert.equal(saved.args.p_refresh_token,'new-refresh');assert.ok(Date.parse(saved.args.p_expires_at)>Date.now());
 const html=await response.text();assert.equal(html.includes('Connected successfully'),true);assert.equal(/new-access|new-refresh|single-use-code/.test(html),false);assert.equal(response.headers.get('Referrer-Policy'),'no-referrer');assert.equal(response.headers.get('Cache-Control'),'no-store');assert.equal(f.calls.some(c=>c.url?.endsWith('/oauth2/revoke')),false);
});
Deno.test('declined approval does not exchange a token or change saved credentials',async()=>{
 const f=fixture();const response=await createBroadcasterAuthorizationHandler(f.deps)(callback('&error=access_denied'));assert.equal(response.status,400);assert.equal(f.calls.some(c=>c.url||c.name==='save_verified_twitch_broadcaster_authorization'),false);
});
