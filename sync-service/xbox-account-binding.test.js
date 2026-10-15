import test from 'node:test';
import assert from 'node:assert/strict';
import { assertXboxIdentity, assertXboxSyncJob } from './xbox-account-binding.js';
test('identity must match the linked Xbox account before a refresh or import',()=>{
 assert.doesNotThrow(()=>assertXboxIdentity('123','123'));
 for (const actual of [null,'456']) assert.throws(()=>assertXboxIdentity('123',actual),/account changed/);
});
function client(data,error=null) { return {from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data,error})})})})}; }
test('only the owner tracked active sync job can write',async()=>{
 await assertXboxSyncJob(client({user_id:'owner',status:'pending'}),'owner',1);
 await assertXboxSyncJob(client({user_id:'owner',status:'syncing'}),'owner',1);
 for(const data of [null,{user_id:'other',status:'syncing'},{user_id:'owner',status:'completed'},{user_id:'owner',status:'failed'},{user_id:'owner',status:'cancelled'}]) await assert.rejects(assertXboxSyncJob(client(data),'owner',1),/ended or changed/);
 await assert.rejects(assertXboxSyncJob(client(null),'owner',null),/no tracked job/);
});
