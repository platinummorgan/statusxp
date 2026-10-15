import {test} from 'node:test';
import assert from 'node:assert/strict';
import {assertPlatformSyncOwner} from './platform-sync-owner.js';
function fixture(platform,options={}) {
 const field=platform==='psn'?'psn_account_id':'steam_id';const queries=[];
 return {queries,from:table=>{const q={select:()=>q,eq:(key,value)=>{queries.push({table,key,value});return q;},single:async()=>table==='profiles'?{data:{[field]:options.mismatch?'different':'expected',[`${platform}_sync_status`]:options.profileStatus||'syncing'},error:options.error||null}:{data:{status:options.logStatus||'pending'},error:null}};return q;}};
}
for(const platform of ['psn','steam']) {
 test(`${platform} validates owner account and active log before provider writes`,async()=>{
  const client=fixture(platform);assert.equal(await assertPlatformSyncOwner(client,'owner',platform,'expected',42),'syncing');
  assert.ok(client.queries.some(q=>q.table===`${platform}_sync_logs`&&q.key==='user_id'&&q.value==='owner'));
 });
 test(`${platform} rejects stale identity, terminal job, profile errors`,async()=>{
  for(const options of [{mismatch:true},{logStatus:'failed'},{profileStatus:'success'},{error:{message:'database unavailable'}}]) await assert.rejects(assertPlatformSyncOwner(fixture(platform,options),'owner',platform,'expected',42));
 });
 test(`${platform} returns cancelling without starting provider work`,async()=>{
  assert.equal(await assertPlatformSyncOwner(fixture(platform,{profileStatus:'cancelling'}),'owner',platform,'expected',42),'cancelling');
 });
}
