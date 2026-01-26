import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const PLATFORM_ID = 4; // Steam

function computeBaseStatusXP(rarityPercent) {
  if (rarityPercent == null || Number.isNaN(Number(rarityPercent))) {
    return 0.5;
  }
  const r = Number(rarityPercent);
  const floor = 0.5;
  const cap = 12;
  const p = 3;
  const inv = Math.max(0, Math.min(1, 1 - (r / 100)));
  const base = floor + (cap - floor) * Math.pow(inv, p);
  return Math.round(Math.max(floor, Math.min(cap, base)) * 100) / 100;
}

async function fetchSteamRarityMap(appId) {
  try {
    const response = await fetch(
      `https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=${appId}&format=json`
    );

    const contentType = response.headers.get('content-type');
    if (!response.ok || !contentType?.includes('application/json')) {
      console.warn(`[STEAM] Global stats unavailable for app ${appId}`);
      return new Map();
    }

    const data = await response.json();
    const achievements = data?.achievementpercentages?.achievements || [];
    const map = new Map();
    for (const ach of achievements) {
      if (ach?.name != null && ach?.percent != null) {
        map.set(String(ach.name), Number(ach.percent));
      }
    }
    return map;
  } catch (error) {
    console.error('[STEAM] Failed to fetch rarity data:', error);
    return new Map();
  }
}

const DEFAULT_PAGE_SIZE = 1000;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function fetchUniqueAppIds({ maxTitles } = {}) {
  const uniqueTitles = new Set();
  let offset = 0;

  while (true) {
    const { data: rows, error } = await supabase
      .from('achievements')
      .select('platform_game_id')
      .eq('platform_id', PLATFORM_ID)
      .is('rarity_global', null)
      .not('platform_game_id', 'is', null)
      .order('platform_game_id', { ascending: true })
      .range(offset, offset + DEFAULT_PAGE_SIZE - 1);

    if (error) {
      throw new Error(`Failed to fetch Steam achievements with null rarity: ${error.message}`);
    }

    if (!rows || rows.length === 0) break;

    for (const row of rows) {
      uniqueTitles.add(row.platform_game_id);
      if (maxTitles && uniqueTitles.size >= maxTitles) {
        return Array.from(uniqueTitles).slice(0, maxTitles);
      }
    }

    if (rows.length < DEFAULT_PAGE_SIZE) break;
    offset += rows.length;
  }

  return Array.from(uniqueTitles);
}

export async function backfillSteamRarity({ limitTitles = 20, dryRun = false, sleepMs } = {}) {
  const maxTitles = limitTitles && limitTitles > 0 ? limitTitles : undefined;
  const delayMs = Number.isFinite(Number(sleepMs)) ? Number(sleepMs) : 200;

  console.log(`Starting Steam rarity backfill. limitTitles=${limitTitles} dryRun=${dryRun} sleepMs=${delayMs}`);

  const uniqueTitles = await fetchUniqueAppIds({ maxTitles });
  console.log(`Found ${uniqueTitles.length} appIds with null rarity to process.`);

  let totalUpdated = 0;
  let titlesWithNoData = 0;
  let titlesAttempted = 0;

  for (const appId of uniqueTitles) {
    titlesAttempted += 1;
    const rarityMap = await fetchSteamRarityMap(appId);
    if (!rarityMap.size) {
      console.log(`[STEAM] No rarity data for app ${appId}`);
      titlesWithNoData += 1;
      continue;
    }

    const { data: existingRows, error: existingError } = await supabase
      .from('achievements')
      .select('platform_game_id, platform_achievement_id, rarity_global')
      .eq('platform_id', PLATFORM_ID)
      .eq('platform_game_id', appId);

    if (existingError) {
      console.warn(`Failed to fetch existing achievements for app ${appId}: ${existingError.message}`);
      continue;
    }

    const updates = [];
    for (const row of existingRows || []) {
      const rarity = rarityMap.get(String(row.platform_achievement_id));
      if (rarity === undefined) continue;
      if (row.rarity_global !== null && row.rarity_global === rarity) continue;

      updates.push({
        platform_game_id: row.platform_game_id,
        platform_achievement_id: row.platform_achievement_id,
        rarity_global: rarity,
        base_status_xp: computeBaseStatusXP(rarity),
        rarity_multiplier: 1.0,
      });
    }

    if (!updates.length) {
      console.log(`[STEAM] No updates needed for app ${appId}`);
      continue;
    }

    if (dryRun) {
      console.log(`[DRY RUN] Would update ${updates.length} achievements for app ${appId}`);
      totalUpdated += updates.length;
      continue;
    }

    let titleUpdated = 0;
    for (const update of updates) {
      const { error: updateError } = await supabase
        .from('achievements')
        .update({
          rarity_global: update.rarity_global,
          base_status_xp: update.base_status_xp,
          rarity_multiplier: update.rarity_multiplier,
        })
        .eq('platform_id', PLATFORM_ID)
        .eq('platform_game_id', update.platform_game_id)
        .eq('platform_achievement_id', update.platform_achievement_id);

      if (updateError) {
        console.warn(`Failed to update achievement ${update.platform_achievement_id} for app ${appId}: ${updateError.message}`);
        continue;
      }
      titleUpdated += 1;
    }

    totalUpdated += titleUpdated;
    console.log(`Updated ${titleUpdated} achievements for app ${appId}`);

    if (delayMs > 0) {
      await sleep(delayMs);
    }
  }

  console.log(`Backfill complete. Total achievements updated: ${totalUpdated}`);
  return {
    updated: totalUpdated,
    titlesProcessed: uniqueTitles.length,
    titlesAttempted,
    titlesWithNoData,
  };
}

if (process.argv[1] && process.argv[1].includes('backfill-steam-rarity.js')) {
  const limitTitles = Number(process.env.BACKFILL_LIMIT_TITLES || '20');
  const dryRun = process.env.BACKFILL_DRY_RUN === 'true';
  backfillSteamRarity({ limitTitles, dryRun })
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
