import assert from 'node:assert/strict';
import { limitedProviderHandler } from './limited-provider-handler.ts';
function fixture(options: {deny?: boolean; fail?: boolean} = {}) {
  const calls: string[]=[];
  const handler=limitedProviderHandler({
    getUser: async token=>token==='valid'?'verified-user':null,
    validate: body=>typeof body.text==='string' && body.text.length<=5000,
    admit: async user=> {assert.equal(user,'verified-user'); calls.push('admit'); return options.deny ? new Response('{}',{status:429,headers:{'Retry-After':'30'}}) : null;},
    execute: async()=> { calls.push('execute'); if(options.fail) throw new Error('provider key secret'); return {is_safe:true}; },
  });
  const request=(body: unknown={text:'hello'},token='valid',method='POST')=>handler(new Request('https://local/test',{method,headers:{Authorization:`Bearer ${token}`},...(method==='POST'?{body:JSON.stringify(body)}:{})}));
  return {calls,request};
}
Deno.test('provider rejects invalid identity and method without spending quota',async()=>{
  const f=fixture(); assert.equal((await f.request({},'invalid')).status,401); assert.equal((await f.request({},'valid','GET')).status,405); assert.deepEqual(f.calls,[]);
});
Deno.test('provider bounds bytes and input before admission',async()=>{
  const f=fixture(); assert.equal((await f.request({text:'x'.repeat(24001)})).status,413); assert.equal((await f.request({text:12})).status,400); assert.equal((await f.request({text:'x'.repeat(5001)})).status,400); assert.deepEqual(f.calls,[]);
});
Deno.test('provider quota denial never calls upstream and carries retry hint',async()=>{
  const f=fixture({deny:true}); const response=await f.request(); assert.equal(response.status,429); assert.equal(response.headers.get('Retry-After'),'30'); assert.deepEqual(f.calls,['admit']);
});
Deno.test('provider admits before execution and ignores submitted identity',async()=>{
  const f=fixture(); assert.equal((await f.request({text:'hello',userId:'someone-else'})).status,200); assert.deepEqual(f.calls,['admit','execute']);
});
Deno.test('provider errors fail closed without leaking secret data',async()=>{
  const f=fixture({fail:true}); const response=await f.request(); assert.equal(response.status,503); assert.ok(!(await response.text()).includes('secret')); assert.equal(response.headers.get('Access-Control-Allow-Origin'),'*');
});
