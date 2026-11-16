// Export a collected proposal for a human original-scope review; never grants awards.
import 'dotenv/config';
import fs from 'node:fs';
import { createServiceClient } from './supabase-client.js';
const [appId,filename] = process.argv.slice(2);
if (!/^\d+$/.test(appId ?? '') || !filename) throw new Error('Usage: node export-steam-completion-review.js APPID OUTPUT.json');
const { data,error } = await createServiceClient().from('steam_completion_review_jobs')
  .select('proposal,status').eq('platform_game_id',appId).single();
if (error || !data?.proposal) throw new Error('No collected review is available yet');
fs.writeFileSync(filename,JSON.stringify(data.proposal.proposed_review ?? data.proposal,null,2)+'\n',{ flag:'wx' });
console.log(JSON.stringify({ app_id:appId,status:data.status,exported:true,original_scope_review_required:true }));
