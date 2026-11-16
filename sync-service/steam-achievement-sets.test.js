import test from 'node:test';
import assert from 'node:assert/strict';
import { ensureSteamCompletionPolicy, refreshSteamCompletionPolicies, steamSchemaSignature } from './steam-achievement-sets.js';
import { recordSteamCompletion } from './steam-completions.js';

const now = Date.parse('2026-11-16T19:00:00Z');
function mockClient(cached = null, apply = true) {
  const calls = [];
  const client = { calls, from(table) {
    assert.equal(table, 'steam_completion_catalog');
    return { select() { return this; }, eq() { return this; },
      maybeSingle: async () => ({ data: cached, error: null }) };
  }, async rpc(name, params) { calls.push({ name, params }); return { data: apply, error: null }; } };
  return client;
}
const cache = overrides => ({ policy_version: 1, observed_ids: ['A','DLC'], required_ids: ['A'],
  completion_policy: 'official_base_game', policy_next_check_at: new Date(now+1000).toISOString(),
  evidence: { scope: 'official_base_game', review_method: 'automatic_native_steam_sets' }, ...overrides });
const page = groups => ({ ok: true, text: async () => `<script id="valve-ssr-data">${JSON.stringify({
  renderContext: { queryData: JSON.stringify({ queries: [{ queryKey:['achievements',42,'schema_v2'],
    state:{data:{appid:42,groups}} }] }) },
})}</script>` });
const group = (id, ids) => ({id,dlcappid:id?123:0,ispublic:true,developeronly:false,archived:false,
  achievements:ids.map(api_name=>({api_name,name:api_name,groupid:id,archived:false}))});

test('definition replacement is detected even when the achievement count stays the same', () => {
  assert.equal(steamSchemaSignature(['A','B']),steamSchemaSignature(['B','A']));
  assert.notEqual(steamSchemaSignature(['A','B']),steamSchemaSignature(['A','NEW']));
});

test('fresh shared cache avoids public requests and redundant writes', async () => {
  const client=mockClient(cache());
  const result=await ensureSteamCompletionPolicy(client,42,['DLC','A'],{now,fetcher:()=>{throw Error('unexpected request');}});
  assert.equal(result.completion_policy,'official_base_game');
  assert.equal(client.calls.length,0);
});
test('native set IDs are persisted once and DLC requirements stay excluded', async () => {
  const client=mockClient();
  await ensureSteamCompletionPolicy(client,42,['A','DLC'],{now,fetcher:async()=>page([group(0,['A']),group(1,['DLC'])])});
  const p=client.calls[0].params;
  assert.equal(p.p_policy,'official_base_game');
  assert.deepEqual(p.p_required_ids,['A']);
  assert.equal(p.p_expected_observed_ids,null);
  assert.equal(p.p_retry,false);
});
test('new games use all achievements during page outages and retry in thirty minutes', async () => {
  const client=mockClient();
  const result=await ensureSteamCompletionPolicy(client,42,['A','DLC'],{now,fetcher:async()=>({ok:false})});
  assert.deepEqual(client.calls[0].params.p_required_ids,['A','DLC']);
  assert.equal(client.calls[0].params.p_retry,true);
  assert.equal(result.policy_next_check_at,new Date(now+30*60_000).toISOString());
});
test('outage preserves previously verified requirements instead of changing a completion', async () => {
  const cached=cache({policy_next_check_at:new Date(now-1).toISOString()});
  const client=mockClient(cached);
  await ensureSteamCompletionPolicy(client,42,['A','DLC'],{now,fetcher:async()=>{throw Error('provider outage');}});
  assert.equal(client.calls[0].params.p_policy,'official_base_game');
  assert.deepEqual(client.calls[0].params.p_required_ids,['A']);
  assert.equal(client.calls[0].params.p_retry,true);
});
test('changed schema cannot reuse old exclusions when page is unavailable', async () => {
  const client=mockClient(cache());
  await ensureSteamCompletionPolicy(client,42,['A','DLC','NEW'],{now,fetcher:async()=>({ok:false})});
  assert.equal(client.calls[0].params.p_policy,'all_achievements');
  assert.deepEqual(client.calls[0].params.p_required_ids,['A','DLC','NEW']);
});
test('parallel owners share a single pending per-AppID provider request', async () => {
  const client=mockClient();let requests=0;
  const fetcher=async()=>{requests++;return page([group(0,['A']),group(1,['DLC'])]);};
  await Promise.all([ensureSteamCompletionPolicy(client,42,['A','DLC'],{now,fetcher}),
    ensureSteamCompletionPolicy(client,42,['A','DLC'],{now,fetcher})]);
  assert.equal(requests,1);assert.equal(client.calls.length,1);
});
test('stale catalog races are retried then fail rather than reporting a false successful policy', async () => {
  const client=mockClient(null,false);
  await assert.rejects(ensureSteamCompletionPolicy(client,42,['A'],{now,fetcher:async()=>page([group(0,['A'])])}),/concurrently/);
  assert.equal(client.calls.length,2);
});
test('normal sync establishes membership before saving native earned state', async () => {
  const events=[];
  const client={rpc:async(name)=>{events.push(name);return{data:{review_state:'verified'},error:null};}};
  await recordSteamCompletion(client,{userId:'owner',steamId:'native',logId:1,appId:42,
    schema:[{name:'A'}],playerAchievements:[{apiname:'A',achieved:1}]},
  {ensurePolicy:async()=>events.push('membership')});
  assert.deepEqual(events,['membership','record_steam_completion']);
});
test('incomplete native states cannot change membership or grant a completion', async () => {
  let touched=false;
  await assert.rejects(recordSteamCompletion({}, {userId:'owner',steamId:'native',logId:1,appId:42,
    schema:[{name:'A'},{name:'DLC'}],playerAchievements:[{apiname:'A',achieved:1}]},
  {ensurePolicy:async()=>{touched=true;}}),/progress is incomplete/);
  assert.equal(touched,false);
});
test('worker refreshes shared definitions without recording any player unlocks', async () => {
  const client=mockClient();
  client.from=()=>({select(){return this;},lte(){return this;},order(){return this;},
    limit:async()=>({data:[{platform_game_id:'42',observed_ids:['A']}],error:null}),
    eq(){return this;},maybeSingle:async()=>({data:null,error:null})});
  await refreshSteamCompletionPolicies(client,{fetcher:async()=>page([group(0,['A'])])});
  assert.deepEqual(client.calls.map(c=>c.name),['apply_steam_completion_policy']);
});
