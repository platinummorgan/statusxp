// Usage: node review-steam-completion-set.js <reviewed-catalog.json> [--apply]
// A file must classify every current definition and record original-content evidence.
import 'dotenv/config';
import fs from 'node:fs';
import { createServiceClient } from './supabase-client.js';

const filename=process.argv[2];
if (!filename) throw new Error('Provide a reviewed Steam completion catalog JSON file.');
const record=JSON.parse(fs.readFileSync(filename,'utf8'));
if (record.evidence?.automated_proposal
  && !(record.evidence?.original_scope_confirmed || record.evidence?.base_scope_confirmed)) {
 const noteIndex=process.argv.indexOf('--scope-note');
 const sourceIndex=process.argv.indexOf('--scope-evidence');
 const note=noteIndex>=0?process.argv[noteIndex+1]:null;
 const source=sourceIndex>=0?process.argv[sourceIndex+1]:null;
 if (!note || note.startsWith('--') || !source || !/^https:\/\//.test(source)) {
  throw new Error('Automated proposals require --scope-note and --scope-evidence https://... confirming the base completion set before approval.');
 }
 record.evidence={...record.evidence,base_scope_confirmed:true,base_scope_review:note,
  sources:[...record.evidence.sources,source]};
}
if (!record.app_id || !Array.isArray(record.required_ids) || !record.required_ids.length
  || !Array.isArray(record.excluded_ids)
  || !['day_one_base_game','console_equivalent_base_game'].includes(record.evidence?.scope)
  || !record.evidence.sources?.length) throw new Error('Review file lacks exhaustive classification or source evidence.');
const summary={app_id:record.app_id,required:record.required_ids.length,excluded:record.excluded_ids.length};
if (process.argv.includes('--apply')) {
 const {error}=await createServiceClient().rpc('review_steam_completion_set',{
  p_app_id:String(record.app_id),p_required_ids:record.required_ids,
  p_excluded_ids:record.excluded_ids,p_evidence:record.evidence,
 });
 if(error) throw new Error('Reviewed membership could not be applied. Check schema coverage and source evidence.');
 console.log(JSON.stringify({...summary,applied:true}));
} else console.log(JSON.stringify({...summary,dry_run:true}));
