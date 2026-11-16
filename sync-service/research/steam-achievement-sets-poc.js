// Read-only research. This file is intentionally not imported by the sync service.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import { parseSteamReviewSchema } from '../steam-completion-review.js';

const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

import { selectRequirements } from '../steam-achievement-sets.js';
export { selectRequirements };

export function evaluateCompletion(requiredIds, states, rarities) {
  if (!requiredIds.length) return { complete: false, count: 0, reason: 'no_available_achievements', estimated_rarity: null, xp_1x: null };
  const missingStates = requiredIds.filter(id => !states.has(id));
  const complete = missingStates.length ? null : requiredIds.every(id => states.get(id) === 1);
  const values = requiredIds.map(id => {
    const raw = rarities.get(id);
    if (raw === null || raw === undefined || raw === '' || typeof raw === 'boolean') return null;
    const number = Number(raw);
    return Number.isFinite(number) && number >= 0 && number <= 100 ? number : null;
  });
  const rarity = values.includes(null) ? null : Math.min(...values);
  const points = rarity === null ? null : Math.round((0.5 + 11.5 * (1 - rarity / 100) ** 3) * 100) / 100;
  return { complete, count: complete === true ? 1 : 0, required_count: requiredIds.length,
    earned_required: requiredIds.filter(id => states.get(id) === 1).length,
    missing_states: missingStates, estimated_rarity: rarity, xp_1x: complete === true ? points : null,
    potential_xp_1x: points, rarity_unavailable: rarity === null };
}

async function readAll(buildQuery) {
  const rows = [];
  for (let offset = 0; ; offset += 1000) {
    const result = await buildQuery().range(offset, offset + 999);
    if (result.error) throw new Error('Read-only catalog query failed');
    rows.push(...result.data);
    if (result.data.length < 1000) return rows;
  }
}

async function requestJson(url) {
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(25_000) });
    if (!response.ok) return { ok: false, status: response.status };
    return { ok: true, status: response.status, data: await response.json() };
  } catch { return { ok: false, status: null }; }
}

async function publicSchema(appId, language = 'english') {
  try {
    const response = await fetch(`https://steamcommunity.com/achievements/${appId}/?l=${language}`, { signal: AbortSignal.timeout(25_000) });
    if (!response.ok) return { ok: false, status: response.status };
    const parsed = parseSteamReviewSchema(await response.text(), appId);
    return { ok: true, status: response.status, schema: parsed.schema };
  } catch { return { ok: false, status: null }; }
}

async function run() {
  const args = process.argv.slice(2);
  const option = name => args.includes(name) ? args[args.indexOf(name) + 1] : null;
  const accountName = option('--account-name');
  const outputDirectory = path.resolve(option('--output') ?? path.join(repository, '.railway-upload/steam-sets-poc-20261116'));
  fs.mkdirSync(outputDirectory, { recursive: true });
  const config = dotenv.parse(fs.readFileSync(path.join(repository, 'sync-service/.env')));
  const client = createClient(config.SUPABASE_URL, config.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { persistSession: false, autoRefreshToken: false } });
  let apiKey = config.STEAM_API_KEY;
  let account = null;
  if (accountName) {
    const result = await client.from('profiles').select('id,steam_id,steam_api_key')
      .eq('psn_online_id', accountName).is('merged_into_user_id', null).single();
    if (result.error) throw new Error('Research account unavailable');
    account = result.data;
    apiKey ||= account.steam_api_key;
  }
  if (!apiKey) throw new Error('A configured Steam key is required for documented API comparison');
  const profiles = await readAll(() => client.from('profiles').select('id').not('steam_id', 'is', null)
    .is('merged_into_user_id', null).order('id'));
  const owners = new Set(profiles.map(profile => profile.id));
  const progress = (await readAll(() => client.from('user_progress')
    .select('user_id,platform_game_id,achievements_earned,total_achievements,last_played_at')
    .eq('platform_id', 4).order('platform_game_id').order('user_id'))).filter(row => owners.has(row.user_id));
  const games = await readAll(() => client.from('games').select('platform_game_id,name')
    .eq('platform_id', 4).order('platform_game_id'));
  const inventory = new Map();
  for (const row of progress) {
    let game = inventory.get(row.platform_game_id);
    if (!game) {
      game = { app_id: row.platform_game_id, name: games.find(g => g.platform_game_id === row.platform_game_id)?.name,
        tracked_entries: 0, earned_entries: 0 };
      inventory.set(row.platform_game_id, game);
    }
    game.tracked_entries++;
    if (row.achievements_earned > 0) game.earned_entries++;
  }
  const prioritized = [...inventory.values()].filter(game => game.earned_entries > 0)
    .sort((a, b) => b.tracked_entries - a.tracked_entries || Number(a.app_id) - Number(b.app_id));
  const mandatory = ['1794680','2968420','2062430','3981100','620','292030','1091500','252490','252330','288160','5037510','440','381210'];
  const sampleIds = [...new Set([...mandatory, ...prioritized.slice(0, 40).map(game => game.app_id)])];
  const requestedIds = option('--app-ids')?.split(',');
  const appIds = requestedIds ?? sampleIds;
  if (appIds.some(id => !/^\d+$/.test(id))) throw new Error('Invalid research AppID');
  const catalogIds = new Set(inventory.keys());
  const results = [];
  let cursor = 0;
  await Promise.all(Array.from({ length: 2 }, async () => {
    while (cursor < appIds.length) {
      const appId = appIds[cursor++];
      const page = await publicSchema(appId);
      const api = await requestJson(`https://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/?key=${encodeURIComponent(apiKey)}&appid=${appId}&l=english`);
      const definitions = api.data?.game?.availableGameStats?.achievements;
      const stored = await readAll(() => client.from('achievements').select('platform_achievement_id')
        .eq('platform_id', 4).eq('platform_game_id', appId).order('platform_achievement_id'));
      const apiIds = Array.isArray(definitions) ? definitions.map(a => a.name) : [];
      const selection = selectRequirements(page.schema, apiIds);
      const rarity = await requestJson(`https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=${appId}`);
      const rarityMap = new Map((rarity.data?.achievementpercentages?.achievements ?? []).map(a => [a.name, a.percent]));
      const row = { app_id: appId, name: inventory.get(appId)?.name ?? api.data?.game?.gameName ?? appId,
        in_tracked_catalog: catalogIds.has(appId), tracked_entries: inventory.get(appId)?.tracked_entries ?? 0,
        page_status: page.status, api_status: api.status, api_definition_count: apiIds.length,
        stored_definition_count: stored.length, api_matches_stored: apiIds.length === stored.length
          && apiIds.every(id => stored.some(a => a.platform_achievement_id === id)),
        api_achievement_fields: definitions?.[0] ? Object.keys(definitions[0]) : [],
        groups: page.schema?.groups.map(group => ({ id: group.id, name: group.name, dlcappid: group.dlcappid,
          archived: group.archived, ispublic: group.ispublic, developeronly: group.developeronly,
          total: group.achievements.length, archived_achievements: group.achievements.filter(a => a.archived).length })) ?? [],
        schema_hash: page.schema?.schema_hash, schema_version: page.schema?.schema_version,
        ...selection, required_rarity_rows: selection.required_ids.filter(id => rarityMap.has(id)).length,
        potential: evaluateCompletion(selection.required_ids, new Map(), rarityMap) };
      if (!Array.isArray(definitions)) row.error = 'documented_schema_api_unavailable';
      if (account && progress.some(p => p.user_id === account.id && p.platform_game_id === appId)) {
        const player = await requestJson(`https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/?key=${encodeURIComponent(apiKey)}&steamid=${account.steam_id}&appid=${appId}&l=english`);
        const states = new Map((player.data?.playerstats?.achievements ?? []).map(a => [a.apiname, a.achieved]));
        row.personal_preview = evaluateCompletion(selection.required_ids, states, rarityMap);
        row.personal_preview.player_response_success = player.data?.playerstats?.success === true;
      }
      fs.writeFileSync(path.join(outputDirectory, `${appId}-schema.json`), JSON.stringify(page.schema ?? null, null, 2));
      fs.writeFileSync(path.join(outputDirectory, `${appId}-api.json`), JSON.stringify(api.data?.game ?? null, null, 2));
      results.push(row);
      console.log(JSON.stringify({ app_id: appId, name: row.name, api_count: apiIds.length,
        mode: row.mode, required: row.required_ids.length, join: row.id_join_complete, error: row.error ?? null }));
    }
  }));
  const supported = await requestJson(`https://api.steampowered.com/ISteamWebAPIUtil/GetSupportedAPIList/v1/?key=${encodeURIComponent(apiKey)}`);
  const relevantMethods = supported.data?.apilist?.interfaces.flatMap(service => service.methods
    .filter(method => /achiev|schema|completion/i.test(method.name) && /UserStats|Achievement|PlayerService|Community/i.test(service.name))
    .map(method => ({ interface: service.name, method: method.name, version: method.version }))) ?? [];
  const summary = { checked_at: new Date().toISOString(), production_mutations: 0, proposed_rarity_weight: 1,
    linked_steam_accounts: owners.size, tracked_games: inventory.size, games_with_earned_achievements: prioritized.length,
    tracked_entries: progress.length, sampled_games: results.length,
    grouped_base_games: results.filter(row => row.mode === 'official_base_game').length,
    fallback_games: results.filter(row => row.mode === 'all_achievements').length,
    clean_id_joins: results.filter(row => row.id_join_complete).length,
    catalog_rows_covered_by_sample: results.reduce((sum,row) => sum + row.tracked_entries, 0),
    supported_api_methods: relevantMethods, results: results.sort((a,b) => Number(a.app_id) - Number(b.app_id)) };
  fs.writeFileSync(path.join(outputDirectory, 'results.json'), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify({ sampled: summary.sampled_games, official_base: summary.grouped_base_games,
    fallback: summary.fallback_games, joins: summary.clean_id_joins, output: path.join(outputDirectory, 'results.json') }));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  run().catch(() => { console.error('Read-only Steam sets research failed; inspect configuration and provider availability.'); process.exitCode = 1; });
}
