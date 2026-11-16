import test from 'node:test';
import assert from 'node:assert/strict';
import { selectRequirements, evaluateCompletion } from './steam-achievement-sets-poc.js';

function group(id, ids, overrides = {}) {
  return { id, name: id ? 'Custom' : '', dlcappid: id ? 123 : 0,
    archived: false, ispublic: true, developeronly: false,
    achievements: ids.map(api_name => ({ api_name, groupid: id, archived: false })), ...overrides };
}

test('explicit DLC grouping uses only the built-in base set and retains Steam exclusives', () => {
  const schema = { groups: [group(0,['BASE','STEAM_EXCLUSIVE']), group(1,['DLC'])] };
  const choice = selectRequirements(schema,['BASE','STEAM_EXCLUSIVE','DLC']);
  assert.equal(choice.mode,'official_base_game');
  assert.deepEqual(choice.required_ids,['BASE','STEAM_EXCLUSIVE']);
  assert.deepEqual(choice.excluded_ids,['DLC']);
});
test('one default group falls back to all achievements', () => {
  const choice = selectRequirements({groups:[group(0,['A','B'])]},['A','B']);
  assert.equal(choice.mode,'all_achievements');
  assert.equal(choice.fallback_reason,'single_default_group_no_usable_separation');
  assert.deepEqual(choice.required_ids,['A','B']);
});
test('multiple unrestricted mode sets do not become separate game completions', () => {
  const choice = selectRequirements({groups:[group(1,['SOLO'],{dlcappid:0}),group(2,['COOP'],{dlcappid:0})]},['SOLO','COOP']);
  assert.equal(choice.mode,'all_achievements');
  assert.deepEqual(choice.required_ids,['COOP','SOLO']);
  const result = evaluateCompletion(choice.required_ids,new Map([['SOLO',1],['COOP',1]]),new Map([['SOLO',50],['COOP',20]]));
  assert.equal(result.count,1);
  assert.equal(result.estimated_rarity,20);
  assert.equal(result.xp_1x,6.39);
});
test('unrestricted custom sets are an explicit conservative full-base ambiguity', () => {
  const schema = {groups:[group(0,['BASE']),group(1,['FREE_UPDATE'],{dlcappid:0}),group(2,['DLC'])]};
  const choice = selectRequirements(schema,['BASE','FREE_UPDATE','DLC']);
  assert.equal(choice.fallback_reason,'unrestricted_custom_sets_ambiguous_full_base_scope');
  assert.equal(choice.literal_builtin_base_count,1);
  assert.deepEqual(choice.required_ids,['BASE','DLC','FREE_UPDATE']);
});
test('rarity and qualification use the identical required set at one-times weight', () => {
  const ids = selectRequirements({groups:[group(0,['A','B']),group(1,['DLC'])]},['A','B','DLC']).required_ids;
  const result = evaluateCompletion(ids,new Map([['A',1],['B',1],['DLC',0]]),new Map([['A',50],['B',20],['DLC',0]]));
  assert.equal(result.complete,true);
  assert.equal(result.estimated_rarity,20);
  assert.equal(result.xp_1x,6.39);
});
test('archived achievements and sets are excluded, spoilers remain required', () => {
  const base = group(0,['ACTIVE','ARCHIVED']);
  base.achievements[0].hidden=true;
  base.achievements[1].archived=true;
  const choice=selectRequirements({groups:[base,group(1,['OLD_SET'],{archived:true}),group(2,['DLC'])]},['ACTIVE','ARCHIVED','OLD_SET','DLC']);
  assert.deepEqual(choice.required_ids,['ACTIVE']);
  assert.deepEqual(choice.archived_or_unavailable_ids,['ARCHIVED','OLD_SET']);
});
test('no empty set grants a completion', () => {
  const choice=selectRequirements({groups:[group(0,[])]},[]);
  assert.equal(choice.eligible,false);
  assert.equal(evaluateCompletion([],new Map(),new Map()).count,0);
});
test('missing page, duplicate IDs and unmatched API IDs use the fallback', () => {
  for(const schema of [null,{groups:[group(0,['A']),group(1,['A'])]},{groups:[group(0,['A']),group(1,['DLC'])]}]){
    const choice=selectRequirements(schema,['A','DLC','NEW']);
    assert.equal(choice.mode,'all_achievements');
    assert.ok(choice.required_ids.includes('NEW'));
  }
});
test('missing native unlock states stay unknown', () => {
  const result=evaluateCompletion(['A','B'],new Map([['A',1]]),new Map([['A',0],['B',1]]));
  assert.equal(result.complete,null);
  assert.equal(result.count,0);
  assert.equal(result.xp_1x,null);
});
test('valid zero rarity is twelve XP and unavailable rarity stays unknown', () => {
  const states=new Map([['A',1]]);
  assert.equal(evaluateCompletion(['A'],states,new Map([['A','0']])).xp_1x,12);
  const missing=evaluateCompletion(['A'],states,new Map());
  assert.equal(missing.estimated_rarity,null);
  assert.equal(missing.xp_1x,null);
});

test('untrusted archive metadata cannot silently remove fallback requirements', () => {
  const malformed=group(0,['A']);
  malformed.achievements[0].archived='false';
  const choice=selectRequirements({groups:[malformed]},['A']);
  assert.deepEqual(choice.required_ids,['A']);
});
