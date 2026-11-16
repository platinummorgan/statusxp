import test from 'node:test';
import assert from 'node:assert/strict';
import { recordSteamCompletion, markSteamCompletionsSynced } from './steam-completions.js';

const args={userId:'owner',steamId:'linked-account',logId:7,appId:42,
 schema:[{name:'ORIGINAL'},{name:'DAY_ONE_EXCLUSIVE'},{name:'DLC'}],
 playerAchievements:[{apiname:'ORIGINAL',achieved:1,unlocktime:0},
 {apiname:'DAY_ONE_EXCLUSIVE',achieved:1,unlocktime:123},{apiname:'DLC',achieved:0}]};
test('Steam completion sends authoritative stable IDs and real states, retaining unknown dates',async()=>{
 let saved;const client={rpc:async(name,params)=>{saved={name,params};return {data:{review_state:'verified'},error:null};}};
 const result=await recordSteamCompletion(client,args,{ensurePolicy:async()=>{}});
 assert.equal(saved.name,'record_steam_completion');assert.equal(saved.params.p_steam_id,'linked-account');
 assert.deepEqual(saved.params.p_schema_names,['ORIGINAL','DAY_ONE_EXCLUSIVE','DLC']);
 assert.equal(saved.params.p_player_state[0].unlocktime,0);
 assert.equal(saved.params.p_player_state[2].achieved,0);assert.equal(result.review_state,'verified');
});
test('empty/duplicate schemas and malformed player states never reach completion storage',async()=>{
 const client={rpc:()=>{throw Error('must not be called');}};
 for(const schema of [[],[{name:'X'},{name:'X'}],[{name:null}]])
  await assert.rejects(recordSteamCompletion(client,{...args,schema}),/schema is incomplete/);
 for(const playerAchievements of [[{apiname:'X',achieved:'1'}],[{apiname:'X',achieved:1},{apiname:'X',achieved:1}]])
  await assert.rejects(recordSteamCompletion(client,{...args,playerAchievements}),/progress is incomplete/);
});
test('completion write and sync-state errors propagate instead of reporting a completed import',async()=>{
 const client={rpc:async()=>({error:{message:'failed'}})};
 await assert.rejects(recordSteamCompletion(client,args,{ensurePolicy:async()=>{}}),/could not be saved/);
 await assert.rejects(markSteamCompletionsSynced(client,{userId:'owner',steamId:'linked',logId:7}),/could not be saved/);
});
