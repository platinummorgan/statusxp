// Public-page read-only repeatability check; no database or authenticated API access.
import fs from 'node:fs';
import { parseSteamReviewSchema } from '../steam-completion-review.js';
import { selectRequirements } from './steam-achievement-sets-poc.js';

const root = '.railway-upload/steam-sets-poc-20261116';
const signature = schema => JSON.stringify(schema.groups.map(group => ({
  id: group.id, dlcappid: group.dlcappid, archived: group.archived,
  ispublic: group.ispublic, developeronly: group.developeronly,
  achievements: group.achievements.map(a => ({ id: a.api_name, groupid: a.groupid, archived: a.archived }))
    .sort((a,b) => a.id.localeCompare(b.id)),
})).sort((a,b) => a.id-b.id));
const results=[];
for (const appId of ['2968420','1794680','620','440','291650']) {
  const original=JSON.parse(fs.readFileSync(`${root}/pilot/${appId}-schema.json`));
  const checks=[];
  for (const language of ['english','english','french']) {
    const response=await fetch(`https://steamcommunity.com/achievements/${appId}/?l=${language}`, {
      signal: AbortSignal.timeout(25_000),
    });
    if (!response.ok) throw new Error(`Public request failed for ${appId}: ${response.status}`);
    const {schema}=parseSteamReviewSchema(await response.text(),appId);
    checks.push({language,status:response.status,membership_matches:signature(original)===signature(schema)});
  }
  const api=JSON.parse(fs.readFileSync(`${root}/pilot/${appId}-api.json`));
  const selection=selectRequirements(original,api.availableGameStats.achievements.map(a=>a.name));
  results.push({app_id:appId,checks,mode:selection.mode,required:selection.required_ids.length,
    archived_ids:selection.archived_or_unavailable_ids,join:selection.id_join_complete});
}
fs.writeFileSync(`${root}/stability.json`,JSON.stringify({checked_at:new Date().toISOString(),results},null,2));
console.log(JSON.stringify(results,null,2));
