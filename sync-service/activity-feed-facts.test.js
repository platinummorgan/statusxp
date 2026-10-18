import test from 'node:test';
import assert from 'node:assert/strict';
import { buildVerifiedChange, readAllPages, readSyncUnlockRows } from './activity-feed-facts.js';
const before = { platinum_count: 4253, psn_gold_count: 10, psn_silver_count: 20, psn_bronze_count: 30, synced_at: '2026-09-20T08:00:00Z' };
const after = { ...before, platinum_count: 4255, synced_at: '2026-09-20T09:00:00Z' };
const games = [1, 2].map(id => ({ platform_id: 1, platform_game_id: String(id), name: 'PAINT BALL' }));
const rows = games.map(game => ({ ...game, platform_achievement_id: '0', earned_at: '2026-09-19T12:00:00Z', achievements: { name: 'PAINT BALL', is_platinum: true } }));
test('two distinct lists keep their title and actual platinum gain', () => {
 const change = buildVerifiedChange('psn', before, after, rows, games);
 assert.equal(change.platinumChange, 2); assert.equal(change.gameTitle, 'PAINT BALL'); assert.equal(change.gameCount, 2); assert.equal(change.isImport, false);
});
test('false zero baseline cannot announce a whole collection', () => {
 assert.equal(buildVerifiedChange('psn', { ...before, platinum_count: 0 }, after, rows, games), null);
});
test('unchanged re-sync and incomplete context produce no story', () => {
 assert.equal(buildVerifiedChange('psn', after, after, rows, games), null);
 assert.equal(buildVerifiedChange('psn', before, after, rows.slice(0, 1), games), null);
 assert.equal(buildVerifiedChange('psn', before, after, rows, []), null);
});
test('historical trophies are explicitly imports', () => {
 assert.equal(buildVerifiedChange('psn', before, after, rows.map(row => ({ ...row, earned_at: '2012-01-01T00:00:00Z' })), games).isImport, true);
});
test('Steam reports all contributing games, not just the latest', () => {
 const change = buildVerifiedChange('steam', { steam_achievement_count: 10 }, { steam_achievement_count: 12, synced_at: after.synced_at }, rows, games.map((g, i) => ({ ...g, name: i ? 'Hades' : 'Portal' })));
 assert.equal(change.gameTitle, 'Portal, Hades');
});
test('Xbox cannot invent a new total from repeated scored rows', () => {
 assert.equal(buildVerifiedChange('xbox', { gamerscore: 100 }, { gamerscore: 110 }, rows.map(row => ({ ...row, achievements: { score_value: 10 } })), games), null);
});
test('rarity uses actual rarity_global and rejects missing rarity', () => {
 const change = buildVerifiedChange('psn', before, after, rows.map((row, i) => ({ ...row, achievements: { ...row.achievements, rarity_global: i ? null : 0.8 } })), games);
 assert.equal(change.rareTrophies.length, 1); assert.equal(change.rareTrophies[0].rarity, 0.8);
});
test('pagination covers every row and fails closed on query errors', async () => {
 const records = Array.from({ length: 1001 }, (_, id) => ({ id }));
 assert.equal((await readAllPages(() => ({ range: async (a, b) => ({ data: records.slice(a, b + 1) }) }))).length, 1001);
 await assert.rejects(readAllPages(() => ({ range: async () => ({ error: { message: 'timeout' } }) })), /timeout/);
});

test('ordinary unlocks provide a named highlight and objective without requiring rarity', () => {
 const change = buildVerifiedChange('steam', { steam_achievement_count: 5 }, { steam_achievement_count: 6, synced_at: after.synced_at }, [{ ...rows[0], achievements: { name: 'Guildmaster', description: 'Completed the guild questline' } }], games);
 assert.equal(change.highlight.name, 'Guildmaster');
 assert.equal(change.highlight.description, 'Completed the guild questline');
 assert.deepEqual(change.rareTrophies, []);
});


test('Xbox feed includes confirmed undated imports, never fabricates dates or double counts promotion', async () => {
 const dated = { platform_id: 10, platform_game_id: 'g', platform_achievement_id: 'a', earned_at: '2026-10-10T12:00:00Z', achievements: { name: 'First', score_value: 10 } };
 const undated = { ...dated, platform_achievement_id: 'b', earned_at: undefined, achievements: { name: 'Second', score_value: 20 } };
 const calls = [];
 const client = { from(table) {
  const q = { select(){ return q; }, eq(field,value){ assert.equal(field,'user_id'); assert.equal(value,'owner'); return q; },
   in(field,value){ assert.equal(field,'platform_id'); assert.deepEqual(value,[10,11,12]); return q; },
   gte(field,value){ calls.push([table,field,'start',value]); return q; },
   lte(field,value){ calls.push([table,field,'end',value]); return q; }, order(){ return q; },
   async range(){ return { data: table==='user_achievements' ? [dated] : [undated,{...dated,earned_at:undefined}] }; } };
  return q;
 } };
 const result = await readSyncUnlockRows(client,{userId:'owner',platformIds:[10,11,12],start:'start',end:'end',includeUndated:true});
 assert.equal(result.length,2);
 assert.equal(result.find(r=>r.platform_achievement_id==='a').earned_at,dated.earned_at);
 assert.equal(result.find(r=>r.platform_achievement_id==='b').earned_at,null);
 assert.deepEqual(calls,[['user_achievements','synced_at','start','start'],['user_achievements','synced_at','end','end'],['user_undated_achievements','confirmed_at','start','start'],['user_undated_achievements','confirmed_at','end','end']]);
 const namedGames=[{platform_id:10,platform_game_id:'g',name:'Example'}];
 assert.equal(buildVerifiedChange('xbox',{gamerscore:0},{gamerscore:30,synced_at:'2026-10-18T12:00:00Z'},[dated],namedGames),null);
 const change=buildVerifiedChange('xbox',{gamerscore:0},{gamerscore:30,synced_at:'2026-10-18T12:00:00Z'},result,namedGames);
 assert.equal(change.change,30); assert.equal(change.isImport,true); assert.equal(change.changeType,'import');
 assert.equal(buildVerifiedChange('xbox',{gamerscore:30},{gamerscore:30},result,namedGames),null);
});

test('PSN and Steam feed queries do not read undated Xbox data; failed undated reads reject', async () => {
 const makeClient = fail => ({from(table){
  if (!fail) assert.equal(table,'user_achievements');
  const q={select(){return q;},eq(){return q;},in(){return q;},gte(){return q;},lte(){return q;},order(){return q;},async range(){return table==='user_undated_achievements'?{error:{message:'timeout'}}:{data:[]};}};return q;
 }});
 assert.deepEqual(await readSyncUnlockRows(makeClient(false),{userId:'owner',platformIds:[4],start:'start',end:'end'}),[]);
 await assert.rejects(readSyncUnlockRows(makeClient(true),{userId:'owner',platformIds:[10],start:'start',end:'end',includeUndated:true}),/timeout/);
});
