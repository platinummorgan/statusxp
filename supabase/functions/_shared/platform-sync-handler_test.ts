import { strict as assert } from 'node:assert';
import { createPlatformStartHandler } from './platform-sync-handler.ts';

function fixture(options: {authFails?:boolean; admissionFails?:boolean; deny?:'pre'|'auth'|'consume'; unauthorized?:boolean; platform?:'psn'|'steam'} = {}) {
 const calls:string[]=[];
 const admin={from(){let updating=false; const q={select(){return q;},eq(){return q;},update(){updating=true;calls.push('save');return q;},async single(){return updating?{data:{id:'owner'}}:{data:{psn_account_id:'psn-id',psn_refresh_token:'old-refresh',psn_sync_status:'success',steam_id:'steam-id',steam_api_key:'key',steam_sync_status:'success'}};}};return q;},async rpc(name:string){calls.push(name);return name==='begin_verified_platform_sync'?(options.admissionFails?{error:{code:'55000',message:'Reconnect this account'}}:{data:44}):{data:'failed'};}};
 const handler=createPlatformStartHandler(options.platform??'psn',{
  env:n=>n,
  createClient:(_,key)=>key==='SUPABASE_SERVICE_ROLE_KEY'?admin:{auth:{async getUser(){return options.unauthorized?{error:{message:'invalid'}}:{data:{user:{id:'owner'}}};}}},
  async quotaResponse(_,provider,__,consume=true){calls.push(`${provider}:${consume?'consume':'peek'}`);if(options.deny===(provider==='psn_auth'?'auth':consume?'consume':'pre'))return new Response(JSON.stringify({error:'Request limit',retry_after:10}),{status:429,headers:{'Retry-After':'10'}});return null;},
  async refreshPsn(){calls.push('refresh');if(options.authFails)throw new Error('invalid_grant');return{accessToken:'new-access',refreshToken:'new-refresh'};},
  fetch:async()=>{calls.push('dispatch');return new Response('{}',{status:200});},
 });
 return {calls,run:()=>handler(new Request('https://test.invalid/start',{method:'POST',headers:{Authorization:'Bearer test'}}))};
}
Deno.test('expired PSN authentication does not spend the sync allowance',async()=>{
 const f=fixture({authFails:true});const r=await f.run();assert.equal(r.status,400);assert.equal((await r.json()).requiresRelink,true);
 assert.deepEqual(f.calls,['sync_psn:peek','psn_auth:consume','begin_verified_platform_sync','refresh','finish_platform_sync']);
});
Deno.test('fresh PSN connection spends sync allowance only after verification and saving',async()=>{
 const f=fixture();assert.equal((await f.run()).status,200);
 assert.deepEqual(f.calls,['sync_psn:peek','psn_auth:consume','begin_verified_platform_sync','refresh','save','sync_psn:consume','dispatch']);
});
Deno.test('reconnect admission failure never spends sync allowance or contacts Sony',async()=>{
 const f=fixture({admissionFails:true});assert.equal((await f.run()).status,409);
 assert.deepEqual(f.calls,['sync_psn:peek','psn_auth:consume','begin_verified_platform_sync']);
});
Deno.test('existing sync cooldown denies before authentication and admission',async()=>{
 const f=fixture({deny:'pre'});assert.equal((await f.run()).status,429);assert.deepEqual(f.calls,['sync_psn:peek']);
});
Deno.test('short Sony authentication throttle remains enforced',async()=>{
 const f=fixture({deny:'auth'});assert.equal((await f.run()).status,429);assert.deepEqual(f.calls,['sync_psn:peek','psn_auth:consume']);
});
Deno.test('late quota denial finishes the pending job without dispatch',async()=>{
 const f=fixture({deny:'consume'});const r=await f.run();assert.equal(r.status,429);assert.equal(r.headers.get('Retry-After'),'10');
 assert.equal(f.calls.includes('dispatch'),false);assert.equal(f.calls.at(-1),'finish_platform_sync');
});
Deno.test('Steam retains its quota and never uses the Sony authentication budget',async()=>{
 const f=fixture({platform:'steam'});assert.equal((await f.run()).status,200);
 assert.deepEqual(f.calls,['sync_steam:peek','begin_verified_platform_sync','sync_steam:consume','dispatch']);
});
Deno.test('unauthenticated calls cannot check or consume quota',async()=>{
 const f=fixture({unauthorized:true});assert.equal((await f.run()).status,401);assert.deepEqual(f.calls,[]);
});
