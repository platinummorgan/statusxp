// Provider data is evidence, never an instruction or an automatic day-one claim.
export const REVIEW_VERSION = 3;
const textKey = value => String(value ?? '').trim().toLowerCase();
export const titleKey = value => textKey(value).replace(/[™®©]/g, '').replace(/\s+/g, ' ');

function descriptionKey(value) {
  return textKey(value)
    .replace(/[’‘]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/(\d)[,\s](?=\d{3}(?:\D|$))/g, '$1')
    .replace(/\s+/g, ' ');
}

export function parseSteamReviewSchema(html, appId) {
  const match = html.match(/<script[^>]+id="valve-ssr-data"[^>]*>([\s\S]*?)<\/script>/);
  if (!match) throw new Error('Steam achievement page format unavailable');
  const payload = JSON.parse(match[1]);
  const queries = JSON.parse(payload.renderContext.queryData).queries;
  const schema = queries.find(q => Array.isArray(q.queryKey)
    && q.queryKey.includes('schema_v2'))?.state?.data;
  if (!schema || String(schema.appid) !== String(appId) || !Array.isArray(schema.groups)) {
    throw new Error('Steam achievement schema unavailable');
  }
  const rows = schema.groups.flatMap(group => {
    if (!Array.isArray(group.achievements)) throw new Error('Incomplete Steam achievement group');
    return group.achievements.map(a => ({ ...a, groupid: group.id }));
  });
  if (!rows.length || rows.some(a => !a.api_name || !a.name)
    || new Set(rows.map(a => a.api_name)).size !== rows.length) {
    throw new Error('Incomplete Steam achievement schema');
  }
  return { schema, rows };
}

function matchReference(steamRows, reference) {
  const xbox = [10,11,12].includes(reference.platform_id);
  if (xbox && (!reference.verified_at || !reference.base_ids?.length)) return null;
  const groupOf = a => xbox ? (reference.base_ids.includes(a.platform_achievement_id) ? 'default' : 'xbox_non_base')
    : a.metadata?.trophy_group_id;
  const base = reference.definitions.filter(a => groupOf(a) === 'default'
    && a.metadata?.psn_trophy_type !== 'platinum');
  if (xbox && base.length !== reference.base_ids.length) return null;
  if (!base.length) return null;
  const used = new Set();
  const mapping = [];
  const issues = [];
  for (const a of steamRows) {
    let candidates = reference.definitions.filter(b => textKey(b.name) === textKey(a.name));
    let matchMethod = 'name';
    const requirement = descriptionKey(a.description);
    if (candidates.length === 0 && requirement) {
      candidates = reference.definitions.filter(b => descriptionKey(b.description) === requirement);
      matchMethod = 'unique_description';
    }
    if (candidates.length !== 1) {
      if (candidates.length === 0) {
        mapping.push({ steam_api_name: a.api_name, name: a.name,
          classification: 'outside_console_completion_set', match_method: null });
        issues.push({ id: a.api_name, reason: 'outside_console_completion_set' });
        continue;
      }
      const ambiguousReason = matchMethod === 'name' ? 'ambiguous_name' : 'ambiguous_description';
      issues.push({ id: a.api_name, reason: ambiguousReason });
      continue;
    }
    const b = candidates[0];
    if (used.has(b.platform_achievement_id)) {
      issues.push({ id: a.api_name, reason: 'duplicate_reference_match' });
      continue;
    }
    used.add(b.platform_achievement_id);
    const group = groupOf(b);
    const isPlatinum = b.metadata?.psn_trophy_type === 'platinum';
    // Missing descriptions cannot establish equivalent requirements automatically.
    const sameDescription = Boolean(requirement) && requirement === descriptionKey(b.description);
    if (!sameDescription) issues.push({ id: a.api_name, reason: 'description_requires_review' });
    if (!group) issues.push({ id: a.api_name, reason: 'reference_group_missing' });
    mapping.push({ steam_api_name: a.api_name, name: a.name, match_method: matchMethod,
      reference_achievement_id: b.platform_achievement_id, reference_group_id: group,
      classification: group === 'default' && !isPlatinum ? 'base_candidate' : 'outside_console_completion_set',
      native_all_achievements_award: isPlatinum, same_description: sameDescription });
  }
  const missingBase = base.filter(a => !used.has(a.platform_achievement_id));
  if (missingBase.length) issues.push({ reason: 'missing_reference_base_achievements',
    ids: missingBase.map(a => a.platform_achievement_id) });
  return { platform_id: reference.platform_id, platform_game_id: reference.platform_game_id,
    name: reference.name, required_ids: mapping.filter(m => m.classification === 'base_candidate').map(m => m.steam_api_name).sort(),
    excluded_ids: mapping.filter(m => m.classification === 'outside_console_completion_set').map(m => m.steam_api_name).sort(),
    mapping, issues, mapping_complete: mapping.length === steamRows.length
      && issues.every(i => ['description_requires_review','outside_console_completion_set'].includes(i.reason)),
    complete_match: mapping.length === steamRows.length
      && issues.every(i => i.reason === 'outside_console_completion_set') };
}

export function analyzeSteamCompletion({ appId, gameName, schema, rows, definitions, references = [], news = [], store = null }) {
  const stored = definitions.map(a => a.platform_achievement_id).sort();
  const native = rows.map(a => a.api_name).sort();
  const coverage = stored.length === native.length && stored.every((id, i) => id === native[i]);
  const candidates = references.filter(r => titleKey(r.name) === titleKey(gameName))
    .map(r => matchReference(rows, r)).filter(Boolean);
  const complete = candidates.filter(c => c.complete_match);
  const aligned = candidates.filter(c => c.mapping_complete);
  const signatures = new Set(aligned.map(c => JSON.stringify([c.required_ids, c.excluded_ids])));
  const groups = schema.groups.map(g => ({ id: g.id, name: g.name, dlcappid: g.dlcappid,
    archived: g.archived, ids: g.achievements.map(a => a.api_name).sort() }));
  const officialNews = news.filter(n => ['steam_community_announcements', 'steam_updates'].includes(n.feedname));
  const findings = officialNews.filter(n => /achiev|troph|1\.0|full release|early access/i.test(`${n.title} ${n.contents}`))
    .map(n => ({ title: n.title, date: n.date, url: n.url,
      // Keep bounded provider text for a reviewer, not an LLM-controlled decision.
      achievement_excerpts: (n.contents.match(/.{0,80}(?:achievement|troph|1\.0).{0,160}/ig) ?? []).slice(0,8) }));
  const reasons = [];
  if (!coverage) reasons.push('native_and_stored_schema_differ');
  if (!candidates.length) reasons.push('no_exact_console_title_reference');
  if (signatures.size > 1) reasons.push('conflicting_console_classifications');
  const ready = coverage && complete.length > 0 && signatures.size === 1;
  if (!ready) reasons.push('console_requirements_or_membership_require_review');
  const result = { version: REVIEW_VERSION, app_id: String(appId), name: gameName,
    status: ready ? 'ready_for_review' : 'needs_review', coverage_complete: coverage,
    observed_ids: native,
    native_definitions: rows.map(a=>({id:a.api_name,name:a.name,description:a.description ?? ''})),
    schema_hash: schema.schema_hash, schema_version: schema.schema_version,
    groups, references: candidates, release: store?.release_date ?? null,
    early_access: store?.genres?.some(g => g.id === '70') ?? null,
    news_findings: findings, reasons,
    sources: [`https://steamcommunity.com/achievements/${appId}/?l=english`,
      `https://store.steampowered.com/app/${appId}/`,
      ...candidates.map(c=>`${[10,11,12].includes(c.platform_id)?'xbox':'psn'}:${c.platform_id}:${c.platform_game_id}`),
      ...officialNews.map(n => n.url)] };
  if (coverage && aligned.length && signatures.size === 1) result.proposed_review = { app_id: String(appId), name: gameName,
    required_ids: aligned[0].required_ids, excluded_ids: aligned[0].excluded_ids,
    evidence: { scope: 'console_equivalent_base_game', sources: result.sources,
      membership_policy: 'verified_console_completion_equivalent',
      automated_proposal: true, base_scope_confirmed: false,
      reference_candidates: aligned.map(c => ({ platform_id: c.platform_id, platform_game_id: c.platform_game_id })),
      reference_issues: aligned.flatMap(c => c.issues) },
    mapping: aligned[0].mapping };
  return result;
}

export async function fetchReviewJson(url, fetcher = fetch) {
  const response = await fetcher(url, { signal: AbortSignal.timeout(20_000) });
  if (!response.ok) throw new Error('Steam public evidence request failed');
  return response.json();
}

export async function readAll(queryFactory) {
  const rows = [];
  for (let offset = 0; ; offset += 1000) {
    const { data, error } = await queryFactory().range(offset, offset + 999);
    if (error || !Array.isArray(data)) throw new Error('Steam review catalog read failed');
    rows.push(...data);
    if (data.length < 1000) return rows;
  }
}

export async function collectSteamCompletionReview(client, appId, { fetcher = fetch } = {}) {
  if (!/^\d+$/.test(String(appId))) throw new Error('Invalid Steam AppID');
  const { data: game, error } = await client.from('games').select('name')
    .eq('platform_id', 4).eq('platform_game_id', String(appId)).single();
  if (error || !game?.name) throw new Error('Steam review game unavailable');
  const page = await fetcher(`https://steamcommunity.com/achievements/${appId}/?l=english`,
    { signal: AbortSignal.timeout(20_000) });
  if (!page.ok) throw new Error('Steam achievement page unavailable');
  const { schema, rows } = parseSteamReviewSchema(await page.text(), appId);
  const definitions = await readAll(() => client.from('achievements')
    .select('platform_achievement_id,name,description,metadata').eq('platform_id',4)
    .eq('platform_game_id',String(appId)).order('platform_achievement_id'));
  // An exact title lookup deliberately retains edition words and punctuation.
  // Escape SQL wildcard characters; a full normalized equality check follows.
  const pattern = game.name.replace(/[%_\\]/g, '\\$&').replace(/[™®©]/g, '%');
  const titles = await readAll(() => client.from('games').select('platform_id,platform_game_id,name')
    .in('platform_id',[1,2,5,9,10,11,12]).ilike('name',pattern)
    .order('platform_id').order('platform_game_id'));
  const references = [];
  for (const title of titles.filter(t => titleKey(t.name) === titleKey(game.name))) {
    const referenceDefinitions = await readAll(() => client.from('achievements')
      .select('platform_achievement_id,name,description,metadata')
      .eq('platform_id',title.platform_id).eq('platform_game_id',title.platform_game_id)
      .order('platform_achievement_id'));
    let membership = {};
    if ([10,11,12].includes(title.platform_id)) {
      const {data,error} = await client.from('xbox_mythic_catalog')
        .select('required_achievement_ids,verified_at').eq('platform_id',title.platform_id)
        .eq('platform_game_id',title.platform_game_id).maybeSingle();
      if (error) throw new Error('Xbox original membership unavailable');
      membership = { base_ids:data?.required_achievement_ids,verified_at:data?.verified_at };
    }
    references.push({ ...title, ...membership, definitions: referenceDefinitions });
  }
  const [storeResult, newsResult] = await Promise.all([
    fetchReviewJson(`https://store.steampowered.com/api/appdetails?appids=${appId}&l=english`,fetcher),
    fetchReviewJson(`https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=100&maxlength=0&feeds=steam_community_announcements,steam_updates`,fetcher),
  ]);
  const store = storeResult?.[appId]?.data ?? null;
  let news = newsResult?.appnews?.newsitems ?? [];
  // Pull the launch window too: a busy game's latest 100 posts may cover only weeks.
  const launch = Date.parse(store?.release_date?.date);
  if (Number.isFinite(launch)) {
    const end = Math.floor(launch / 1000) + 100*86400;
    const launchNews = await fetchReviewJson(`https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=100&maxlength=0&feeds=steam_community_announcements,steam_updates&enddate=${end}`,fetcher);
    news = [...new Map([...news,...(launchNews?.appnews?.newsitems ?? [])].map(n=>[n.gid,n])).values()];
  }
  return analyzeSteamCompletion({ appId, gameName:game.name, schema, rows, definitions, references, news, store });
}

export async function runSteamCompletionReview(client, { collect = collectSteamCompletionReview } = {}) {
  const { data: jobs, error } = await client.rpc('claim_steam_completion_review_job');
  if (error) throw new Error('Steam review queue unavailable');
  if (!jobs?.length) return false;
  const job = jobs[0];
  let proposal = null;
  try { proposal = await collect(client,job.platform_game_id); }
  catch { /* A durable, bounded retry stores only a generic error category. */ }
  const finished = await client.rpc('finish_steam_completion_review_job',{
    p_app_id:job.platform_game_id,p_lease_token:job.lease_token,
    p_proposal:proposal,p_error:proposal ? null : 'Provider evidence or catalog unavailable',
  });
  if (finished.error || !finished.data) throw new Error('Steam review lease changed; result not published');
  return true;
}

export function startSteamCompletionReviewWorker(createClient) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const client = createClient();
      for (let i=0;i<3;i++) if (!await runSteamCompletionReview(client)) break;
    } catch { console.warn('Steam membership evidence retry pending'); }
    finally { running = false; }
  };
  const timer = setInterval(tick,60_000);
  timer.unref();
  void tick();
  return () => clearInterval(timer);
}
