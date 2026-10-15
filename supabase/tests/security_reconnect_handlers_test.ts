import { createVerifySecurityReconnectHandler } from '../functions/verify-security-reconnect/handler.ts';
import { completeSecurityReconnect } from '../functions/_shared/security-reconnect.ts';
function equal(a:unknown,b:unknown) {if(JSON.stringify(a)!==JSON.stringify(b))throw new Error(`Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);}
function fixture(options:any={}) {
 const calls:any[]=[];const factories:any[]=[];
 const caller={auth:{getUser:async()=>({data:{user:options.unauthorized?null:{id:'owner'}},error:null})},from:()=>{throw new Error('Caller read private credentials');}};
 const admin={from:()=>{const q:any={select:()=>q,eq:(_key:string,value:any)=>{calls.push({owner:value});return q;},single:async()=>({data:options.missing?{}:{steam_id:'76561198999999991',steam_api_key:'A'.repeat(32)},error:null})};return q;},
  rpc:async(name:string,args:any)=>{calls.push({name,args});return {data:true,error:options.rpcError||null};}};
 const deps={env:(name:string)=>({SUPABASE_URL:'https://database.invalid',SUPABASE_ANON_KEY:'anon',SUPABASE_SERVICE_ROLE_KEY:'server'} as any)[name],
  createClient:(_url:string,key:string,config:any)=>{factories.push({key,config});return key==='server'?admin:caller;},
  fetch:async()=>new Response(JSON.stringify({response:{players:[{steamid:options.mismatch?'other':'76561198999999991'}]}}),{status:options.providerFailure?403:200}),
 };
 return {deps,calls,factories};
}
const request=()=>new Request('https://edge.invalid',{method:'POST',headers:{Authorization:'Bearer fixture'},body:JSON.stringify({userId:'victim',apiKey:'forged'})});
Deno.test('Steam security verification uses only authenticated owner and server credential',async()=>{
 const f=fixture();const response=await createVerifySecurityReconnectHandler(f.deps)(request());equal(response.status,200);
 equal(f.calls[0].owner,'owner');const completed=f.calls.find(c=>c.name);equal(completed.args.p_user_id,'owner');equal(completed.args.p_platform,'steam');
 equal(typeof completed.args.p_verified_credential_hash,'string');equal(completed.args.p_verified_credential_hash.length,64);
 equal(f.factories.find(c=>c.key==='server').config.global,undefined);
 equal(await response.json(),{success:true,reconnected:true});
});
Deno.test('Steam security verification rejects missing auth, invalid keys and mismatched provider profile',async()=>{
 for(const [options,status] of [[{unauthorized:true},401],[{missing:true},400],[{providerFailure:true},400],[{mismatch:true},400]] as const){
  const f=fixture(options);equal((await createVerifySecurityReconnectHandler(f.deps)(request())).status,status);equal(f.calls.some(c=>c.name),false);
 }
});
Deno.test('reused key, stale verification and incomplete provider steps cannot clear gate',async()=>{
 for(const message of ['Use a new sign-in session or replacement Steam key to reconnect.','Your connection changed during verification. Try reconnecting again.','Complete the provider security steps before reconnecting.']) {
  const f=fixture({rpcError:{code:'55000',message}});const response=await createVerifySecurityReconnectHandler(f.deps)(request());equal(response.status,409);equal((await response.json()).error,message);
 }
});
Deno.test('verified hash is case-normalized only for Steam, never exposed as raw credentials',async()=>{
 const calls:any[]=[];const admin={rpc:async(_name:string,args:any)=>{calls.push(args);return {data:true,error:null};}};
 await completeSecurityReconnect(admin,'owner','steam','id','ABC');await completeSecurityReconnect(admin,'owner','steam','id','abc');
 equal(calls[0].p_verified_credential_hash,calls[1].p_verified_credential_hash);
 await completeSecurityReconnect(admin,'owner','psn','id','ABC');await completeSecurityReconnect(admin,'owner','psn','id','abc');
 if(calls[2].p_verified_credential_hash===calls[3].p_verified_credential_hash)throw new Error('PSN credential normalized incorrectly');
 equal(Object.keys(calls[0]).sort(),['p_platform','p_user_id','p_verified_account_id','p_verified_credential_hash']);
});
