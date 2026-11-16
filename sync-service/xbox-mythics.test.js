import test from 'node:test';
import assert from 'node:assert/strict';
import { extractXboxMythicDetails, needsXboxMythicRefresh, saveXboxMythic } from './xbox-mythics.js';
import { fetchOpenXblAchievementList } from './openxbl-achievements.js';

const base = [{ titleId: '42', groups: { 0: { groupType: 'BaseGame',
  achievementIds: ['1','2'], isComplete: true, completedTime: '2025-01-02T00:00:00Z' },
  dlc: { groupType: 'DLC', achievementIds: ['3'] } } }];
const achievements = [{ id: '1', rarity: { currentPercentage: 10 } },
  { id: '2', rarity: { currentPercentage: '20' } }, { id: '3', rarity: { currentPercentage: 0 } }];

test('Mythic rarity uses only complete original membership and ignores rarer DLC', () => {
  const details = extractXboxMythicDetails('42', base, achievements);
  assert.equal(details.estimated_rarity, 10);
  assert.deepEqual(details.required_ids, ['1','2']);
  assert.equal(details.completed_at, '2025-01-02T00:00:00.000Z');
  assert.equal(extractXboxMythicDetails('other', base, achievements), null);
  assert.equal(extractXboxMythicDetails('42', base, achievements.slice(1)), null);
});
test('zero rarity is valid; missing or invalid rarity makes the estimate unknown', () => {
  for (const raw of [0, null, undefined, '', -1, 101, 'unknown', false]) {
    const rows = [{ ...achievements[0], rarity: { currentPercentage: raw } }, achievements[1]];
    assert.equal(extractXboxMythicDetails('42',base,rows).estimated_rarity, raw === 0 ? 0 : null);
  }
});
test('incomplete groups and sentinel dates never invent a completion date', () => {
  const groups = structuredClone(base);
  groups[0].groups[0].completedTime = '0001-01-01T00:00:00Z';
  assert.equal(extractXboxMythicDetails('42',groups,achievements).completed_at,null);
  assert.equal(extractXboxMythicDetails('42',[],achievements),null);
});
test('pagination retains completion groups even if the last page omits them', async () => {
  let page=0;
  const result=await fetchOpenXblAchievementList(async()=>({ok:true,data:++page===1
    ? { achievements:[achievements[0]],completion:base,pagingInfo:{continuationToken:'next'} }
    : { achievements:achievements.slice(1) }}),'https://test.invalid/achievements');
  assert.equal(result.data.completion.length,1);
  assert.equal(extractXboxMythicDetails('42',result.data.completion,result.data.achievements).estimated_rarity,10);
});
test('new Mythic fields force imports even when achievement and Gamerscore counts did not change', () => {
  assert.equal(needsXboxMythicRefresh({achievement:{isMythic:true}},{}),true);
  assert.equal(needsXboxMythicRefresh({achievement:{isMythic:true}},
    {mythic_schema_version:1,mythic_last_reported:false}),true);
  assert.equal(needsXboxMythicRefresh({achievement:{}},{}),false);
});
test('only native Mythic fields permit a write and storage errors propagate', async () => {
  const calls=[];
  const client={rpc:async(name,args)=>{calls.push({name,args});return {error:null};}};
  const args={userId:'owner',xuid:'linked',logId:7,platformId:10,title:{titleId:'42',achievement:{}}};
  await saveXboxMythic(client,args);assert.equal(calls.length,0);
  await saveXboxMythic(client,{...args,title:{titleId:'42',achievement:{isMythic:true}}});
  assert.equal(calls[0].args.p_is_mythic,true);assert.equal(calls[0].args.p_xuid,'linked');
  await assert.rejects(saveXboxMythic({rpc:async()=>({error:{message:'failed'}})},
    {...args,title:{titleId:'42',achievement:{isMythic:true}}}),/could not be saved/);
});
