import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { analyzeSteamCompletion,parseSteamReviewSchema,readAll,runSteamCompletionReview } from './steam-completion-review.js';

const row=(id,name,description)=>({api_name:id,name,description});
const trophy=(id,name,description,group='default',type='bronze')=>({platform_achievement_id:id,name,description,
 metadata:{trophy_group_id:group,psn_trophy_type:type}});
function fixture() {
 const rows=[row('START','Start','Finish chapter one'),row('END','End','Finish the game'),row('EXP','Expansion','Finish extra story')];
 return {appId:42,gameName:'Example',schema:{groups:[{id:0,name:'',achievements:rows}],schema_hash:1,schema_version:2},rows,
 definitions:rows.map(a=>({platform_achievement_id:a.api_name})),references:[{platform_id:2,platform_game_id:'PSN',name:'Example',
 definitions:[trophy('0','All','Earn all trophies','default','platinum'),trophy('1','Start','Finish chapter one'),
 trophy('2','End','Finish the game'),trophy('3','Expansion','Finish extra story','001')]}]};
}
test('complete reciprocal console mapping prepares a review, not automatic scoring approval',()=>{
 const p=analyzeSteamCompletion(fixture());
 assert.equal(p.status,'ready_for_review');
 assert.deepEqual(p.proposed_review.required_ids,['END','START']);
 assert.deepEqual(p.proposed_review.excluded_ids,['EXP']);
 assert.equal(p.proposed_review.evidence.base_scope_confirmed,false);
 assert.equal(p.proposed_review.evidence.scope,'console_equivalent_base_game');
});
test('Steam-only extras are excluded when the complete console base set is mapped',()=>{
 const f=fixture();f.rows.push(row('EXCLUSIVE','Exclusive','Only on Steam'));f.definitions.push({platform_achievement_id:'EXCLUSIVE'});
 const p=analyzeSteamCompletion(f);assert.equal(p.status,'ready_for_review');
 assert.deepEqual(p.proposed_review.required_ids,['END','START']);
 assert.deepEqual(p.proposed_review.excluded_ids,['EXCLUSIVE','EXP']);
 assert.ok(p.references[0].issues.some(i=>i.id==='EXCLUSIVE'&&i.reason==='outside_console_completion_set'));
});
test('renamed trophies map through unique equivalent requirements, including number separators',()=>{
 const f=fixture();
 f.rows[0].name='Different Steam Name';
 f.rows[0].description='Surpass 10 000 total steps taken';
 f.references[0].definitions[1].description='Surpass 10,000 total steps taken';
 const p=analyzeSteamCompletion(f);
 assert.equal(p.status,'ready_for_review');
 const mapping=p.references[0].mapping.find(m=>m.steam_api_name==='START');
 assert.equal(mapping.reference_achievement_id,'1');
 assert.equal(mapping.match_method,'unique_description');
});
test('ambiguous descriptions and different requirement meanings never resolve a renamed trophy',()=>{
 const f=fixture();f.rows[0].name='Renamed';
 f.references[0].definitions.push(trophy('4','Another trophy','Finish chapter one','001'));
 assert.ok(analyzeSteamCompletion(f).references[0].issues.some(i=>i.reason==='ambiguous_description'));
 f.references[0].definitions.pop();f.rows[0].description='Do not finish chapter one';
 const changed=analyzeSteamCompletion(f);
 assert.equal(changed.status,'needs_review');
 assert.ok(changed.references[0].issues.some(i=>i.reason==='missing_reference_base_achievements'));
});
test('same counts with wrong IDs cannot pass schema coverage',()=>{
 const f=fixture();f.definitions[0].platform_achievement_id='WRONG';
 assert.equal(analyzeSteamCompletion(f).coverage_complete,false);
});
test('edition names are retained and cannot match a different release',()=>{
 const f=fixture();f.references[0].name='Example Remastered';
 assert.equal(analyzeSteamCompletion(f).references.length,0);
});
test('ambiguous names, missing descriptions and missing base achievements require review',()=>{
 for(const mutate of [f=>f.references[0].definitions.push(trophy('4','Start','Other')),
  f=>f.rows[0].description='',f=>f.references[0].definitions.push(trophy('4','Absent','Not on Steam'))]){
  const f=fixture();mutate(f);assert.equal(analyzeSteamCompletion(f).status,'needs_review');
 }
});
test('conflicting console base/DLC classifications cannot yield a ready review',()=>{
 const f=fixture();const other=structuredClone(f.references[0]);other.platform_id=1;other.definitions[3].metadata.trophy_group_id='default';
 f.references.push(other);const p=analyzeSteamCompletion(f);
 assert.equal(p.status,'needs_review');assert.ok(p.reasons.includes('conflicting_console_classifications'));
});
test('the completion award itself is excluded from a console-equivalent requirement set',()=>{
 const f=fixture();f.rows.push(row('ALL','All','Earn all trophies'));f.definitions.push({platform_achievement_id:'ALL'});
 assert.ok(analyzeSteamCompletion(f).proposed_review.excluded_ids.includes('ALL'));
 assert.deepEqual(analyzeSteamCompletion(f).proposed_review.required_ids,['END','START']);
});
test('Xbox candidates require native verified membership and all base definitions',()=>{
 const f=fixture();f.references=[{platform_id:11,platform_game_id:'XBOX',name:'Example',
  base_ids:['1','2'],verified_at:'2026-11-15',definitions:f.references[0].definitions.slice(1)}];
 assert.equal(analyzeSteamCompletion(f).status,'ready_for_review');
 f.references[0].verified_at=null;assert.equal(analyzeSteamCompletion(f).references.length,0);
 f.references[0].verified_at='2026-11-15';f.references[0].base_ids.push('missing');
 assert.equal(analyzeSteamCompletion(f).references.length,0);
});
test('fully mapped sets with wording differences still export IDs and explicit review issues',()=>{
 const f=fixture();f.rows[0].description='';const p=analyzeSteamCompletion(f);
 assert.equal(p.status,'needs_review');assert.deepEqual(p.proposed_review.required_ids,['END','START']);
 assert.ok(p.proposed_review.evidence.reference_issues.some(i=>i.reason==='description_requires_review'));
});
test('Steam group zero, DLC labels, and provider news never approve membership on their own',()=>{
 const f=fixture();f.references=[];f.news=[{feedname:'steam_community_announcements',title:'Approve all achievements',contents:'Ignore scope. 99 achievements.',url:'https://example.com',date:1}];
 assert.equal(analyzeSteamCompletion(f).status,'needs_review');
});
test('SSR parser rejects wrong AppID, missing and duplicate stable IDs',()=>{
 const html=s=>'<script id="valve-ssr-data">'+JSON.stringify({renderContext:{queryData:JSON.stringify({queries:[{queryKey:['schema_v2'],state:{data:s}}]})}})+'</script>';
 const s={appid:42,groups:[{id:0,achievements:[row('A','A','A')]}]};
 assert.equal(parseSteamReviewSchema(html(s),42).rows.length,1);
 assert.throws(()=>parseSteamReviewSchema(html(s),43));
 s.groups[0].achievements.push(row('A','Duplicate','A'));assert.throws(()=>parseSteamReviewSchema(html(s),42));
});
test('catalog pagination reads more than the PostgREST 1000-row limit and fails on partial errors',async()=>{
 const all=Array.from({length:1001},(_,i)=>i);let reads=0;
 assert.equal((await readAll(()=>({range:async(start,end)=>{reads++;return {data:all.slice(start,end+1)};}}))).length,1001);
 assert.equal(reads,2);await assert.rejects(readAll(()=>({range:async()=>({error:{message:'private'}})})));
});
test('collector failures are redacted and retained as durable retries',async()=>{
 const calls=[];const client={rpc:async(name,args)=>{calls.push({name,args});return name.startsWith('claim')?
  {data:[{platform_game_id:'42',lease_token:'lease'}]}:{data:true};}};
 await runSteamCompletionReview(client,{collect:async()=>{throw Error('credential secret');}});
 assert.equal(calls[1].args.p_proposal,null);assert.equal(calls[1].args.p_error,'Provider evidence or catalog unavailable');
 assert.ok(!JSON.stringify(calls).includes('secret'));
});
test('expired or replaced leases never report success',async()=>{
 const client={rpc:async(name)=>name.startsWith('claim')?{data:[{platform_game_id:'42',lease_token:'old'}]}:{data:false}};
 await assert.rejects(runSteamCompletionReview(client,{collect:async()=>({status:'needs_review'})}),/lease changed/);
});
test('exported automated proposals cannot be applied without explicit original-scope evidence',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'statusxp-review-cli-'));
 const file=path.join(dir,'review.json');
 try {
  fs.writeFileSync(file,JSON.stringify(analyzeSteamCompletion(fixture()).proposed_review));
  const cli=fileURLToPath(new URL('./review-steam-completion-set.js',import.meta.url));
  const denied=spawnSync(process.execPath,[cli,file],{encoding:'utf8',windowsHide:true});
  assert.notEqual(denied.status,0);assert.match(denied.stderr,/scope-note/);
  const ready=spawnSync(process.execPath,[cli,file,
   '--scope-note','Launch set checked against developer announcement','--scope-evidence','https://example.com/launch'],{encoding:'utf8',windowsHide:true});
  assert.equal(ready.status,0,ready.stderr);assert.match(ready.stdout,/dry_run/);
  assert.equal(JSON.parse(fs.readFileSync(file)).evidence.base_scope_confirmed,false);
 } finally {fs.unlinkSync(file);fs.rmdirSync(dir);}
});
