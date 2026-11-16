import { parseSteamReviewSchema } from './steam-completion-review.js';
import { createHash } from 'node:crypto';

export const STEAM_COMPLETION_POLICY_VERSION = 1;
const DAY = 86_400_000;
const flights = new Map();
const sameIds = (a, b) => Array.isArray(a) && a.length === b.length && a.every(id => b.includes(id));
export const steamSchemaSignature = ids => createHash('sha256').update(JSON.stringify([...ids].sort())).digest('hex');
export function selectRequirements(schema, apiIds) {
  const all = [...new Set(apiIds)].sort();
  const groups = schema?.groups ?? [];
  const rows = groups.flatMap(group => group.achievements.map(achievement => ({ group, achievement })));
  const publicIds = rows.map(row => row.achievement.api_name);
  const apiSet = new Set(all);
  const schemaSet = new Set(publicIds);
  const missingFromApi = publicIds.filter(id => !apiSet.has(id));
  const missingFromPage = all.filter(id => !schemaSet.has(id));
  const duplicateIds = publicIds.filter((id, index) => publicIds.indexOf(id) !== index);
  const visible = groups.filter(group => !group.archived && !group.developeronly && group.ispublic === true);
  const base = visible.filter(group => group.id === 0 && group.dlcappid === 0);
  const custom = visible.filter(group => group.id !== 0 && group.achievements.length > 0);
  const validFlags = groups.every(group => Number.isInteger(group.id) && Number.isInteger(group.dlcappid)
    && typeof group.archived === 'boolean' && typeof group.ispublic === 'boolean'
    && typeof group.developeronly === 'boolean'
    && group.achievements.every(achievement => typeof achievement.archived === 'boolean'
      && achievement.groupid === group.id));
  const cleanCoverage = !missingFromApi.length && !missingFromPage.length && !duplicateIds.length;
  // Do not remove requirements using malformed or incompletely joined metadata.
  const unavailable = new Set(validFlags && cleanCoverage ? rows.filter(({ group, achievement }) => group.archived
    || group.developeronly || group.ispublic === false || achievement.archived)
    .map(row => row.achievement.api_name) : []);
  const active = all.filter(id => !unavailable.has(id));
  let reason = null;
  if (!schema) reason = 'public_schema_unavailable';
  else if (missingFromApi.length || missingFromPage.length || duplicateIds.length) reason = 'schema_coverage_mismatch';
  else if (!validFlags) reason = 'unrecognized_group_metadata';
  else if (base.length !== 1 || !base[0].achievements.some(a => !a.archived)) reason = 'no_nonempty_builtin_base_set';
  else if (!custom.length) reason = 'single_default_group_no_usable_separation';
  // The payload cannot distinguish a free update set from original mode/class sets.
  // Keep the literal Steam base set visible in the report, but use the requested
  // conservative fallback when "full base game" would require that distinction.
  else if (custom.some(group => group.dlcappid === 0)) reason = 'unrestricted_custom_sets_ambiguous_full_base_scope';
  const required = reason ? active : base[0].achievements.filter(a => !a.archived).map(a => a.api_name).sort();
  return {
    mode: reason ? 'all_achievements' : 'official_base_game', fallback_reason: reason,
    required_ids: required, excluded_ids: all.filter(id => !required.includes(id)),
    archived_or_unavailable_ids: [...unavailable].filter(id => apiSet.has(id)).sort(),
    missing_from_api: missingFromApi, missing_from_page: missingFromPage, duplicate_ids: duplicateIds,
    id_join_complete: missingFromApi.length === 0 && missingFromPage.length === 0 && duplicateIds.length === 0,
    literal_builtin_base_count: base.length === 1 ? base[0].achievements.filter(a => !a.archived).length : null,
    eligible: required.length > 0,
  };
}

// Shared per-AppID cache. Steam membership never depends on another platform.
export async function ensureSteamCompletionPolicy(client, appId, apiIds, { fetcher = fetch, now = Date.now() } = {}) {
  appId = String(appId);
  if (!/^\d+$/.test(appId) || !apiIds.length || apiIds.some(id => typeof id !== 'string' || !id)
    || new Set(apiIds).size !== apiIds.length) throw new Error('Invalid Steam membership schema');
  const key = `${appId}:${JSON.stringify([...apiIds].sort())}`;
  if (flights.has(key)) return flights.get(key);
  const work = (async () => {
    for (let attempt = 0; attempt < 2; attempt++) {
      const { data: cached, error } = await client.from('steam_completion_catalog').select('*')
        .eq('platform_game_id', appId).maybeSingle();
      if (error) throw new Error('Steam membership cache unavailable');
      const reusable = cached?.policy_version === STEAM_COMPLETION_POLICY_VERSION
        && sameIds(cached.observed_ids, apiIds) && Array.isArray(cached.required_ids)
        && cached.required_ids.every(id => apiIds.includes(id));
      if (reusable && Date.parse(cached.policy_next_check_at) > now) return cached;
      let schema = null;
      let providerUnavailable = false;
      try {
        const response = await fetcher(`https://steamcommunity.com/achievements/${appId}/?l=english`,
          { signal: AbortSignal.timeout(15_000) });
        if (!response.ok) throw new Error('Unavailable public schema');
        schema = parseSteamReviewSchema(await response.text(), appId).schema;
      } catch { providerUnavailable = true; }
      const selection = selectRequirements(schema, apiIds);
      // A transient page/parser failure must not replace a previously verified
      // native requirement set. New games still have the full-set fallback.
      const retained = providerUnavailable && reusable;
      const mode = retained ? cached.completion_policy : selection.mode;
      const required = retained ? cached.required_ids : selection.required_ids;
      const evidence = retained ? cached.evidence : {
        scope: mode, review_method: 'automatic_native_steam_sets', policy_version: STEAM_COMPLETION_POLICY_VERSION,
        sources: [`https://steamcommunity.com/achievements/${appId}/?l=english`],
        fallback_reason: selection.fallback_reason, schema_hash: schema?.schema_hash ?? null,
        schema_version: schema?.schema_version ?? null,
        groups: schema?.groups.map(g => ({ id: g.id, dlcappid: g.dlcappid, archived: g.archived,
          ispublic: g.ispublic, developeronly: g.developeronly, count: g.achievements.length })) ?? [],
      };
      const retry = providerUnavailable || !selection.id_join_complete
        || selection.fallback_reason === 'unrecognized_group_metadata';
      const { data: applied, error: writeError } = await client.rpc('apply_steam_completion_policy', {
        p_app_id: appId, p_observed_ids: apiIds, p_required_ids: required, p_policy: mode,
        p_evidence: evidence, p_expected_observed_ids: cached?.observed_ids ?? null,
        p_retry: retry,
      });
      if (writeError) throw new Error('Steam membership policy could not be saved');
      if (applied) return { ...cached, completion_policy: mode, required_ids: required,
        policy_next_check_at: new Date(now + (retry ? 30 * 60_000 : 7 * DAY)).toISOString() };
    }
    throw new Error('Steam membership changed concurrently; retry sync');
  })();
  flights.set(key, work);
  try { return await work; } finally { flights.delete(key); }
}

export async function refreshSteamCompletionPolicies(client, { fetcher = fetch } = {}) {
  const { data: due, error } = await client.from('steam_completion_catalog')
    .select('platform_game_id,observed_ids').lte('policy_next_check_at', new Date().toISOString())
    .order('policy_next_check_at').order('platform_game_id').limit(3);
  if (error) throw new Error('Steam membership refresh unavailable');
  for (const row of due ?? []) {
    if (!row.observed_ids.length) continue;
    try { await ensureSteamCompletionPolicy(client, row.platform_game_id, row.observed_ids, { fetcher }); }
    catch { console.warn('Steam membership refresh deferred'); }
  }
}

export function startSteamCompletionPolicyWorker(createClient) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try { await refreshSteamCompletionPolicies(createClient()); }
    catch { console.warn('Steam membership cache refresh pending'); }
    finally { running = false; }
  };
  const timer = setInterval(tick, 60_000);
  timer.unref();
  void tick();
  return () => clearInterval(timer);
}
