import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const PLATFORM_IDS = [10, 11, 12];

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
  return Math.max(floor, Math.min(cap, base));
}

async function fetchOpenXblRarityMap(titleId) {
  const openXBLKey = process.env.OPENXBL_API_KEY;
  if (!openXBLKey) {
    console.warn('[OPENXBL] OPENXBL_API_KEY not set; skipping rarity fetch.');
    return new Map();
  }

  try {
    const rarityResponse = await fetch(
      `https://xbl.io/api/v2/achievements/title/${titleId}`,
      { headers: { 'x-authorization': openXBLKey } }
    );

    if (!rarityResponse.ok) {
      console.warn(`[OPENXBL] Title endpoint failed (${rarityResponse.status}) for ${titleId}`);
      return new Map();
    }

    const rarityData = await rarityResponse.json();
    const achievementsWithRarity = rarityData?.achievements || [];
    const map = new Map();

    for (const ach of achievementsWithRarity) {
      if (ach?.rarity?.currentPercentage !== undefined) {
        map.set(String(ach.id), ach.rarity.currentPercentage);
      }
    }

    return map;
  } catch (error) {
    console.error('[OPENXBL] Failed to fetch rarity data:', error);
    return new Map();
  }
}

export async function backfillXboxRarity({ limitTitles = 50, dryRun = false } = {}) {
  console.log(`Starting Xbox rarity backfill. limitTitles=${limitTitles} dryRun=${dryRun}`);

  const { data: rarityRows, error } = await supabase
    .from('achievements')
    .select('platform_game_id')
    .in('platform_id', PLATFORM_IDS)
    .is('rarity_global', null)
    .not('platform_game_id', 'is', null)
    .limit(2000);

  if (error) {
    throw new Error(`Failed to fetch achievements with null rarity: ${error.message}`);
  }

  const uniqueTitles = [...new Set((rarityRows || []).map(r => r.platform_game_id))]
    .slice(0, limitTitles);

  console.log(`Found ${uniqueTitles.length} titleIds with null rarity to process.`);

  let totalUpdated = 0;
  for (const titleId of uniqueTitles) {
    const rarityMap = await fetchOpenXblRarityMap(titleId);
    if (!rarityMap.size) {
      console.log(`[OPENXBL] No rarity data for title ${titleId}`);
      continue;
    }

    const { data: existingRows, error: existingError } = await supabase
      .from('achievements')
      .select('platform_id, platform_game_id, platform_achievement_id, rarity_global')
      .in('platform_id', PLATFORM_IDS)
      .eq('platform_game_id', titleId);

    if (existingError) {
      console.warn(`Failed to fetch existing achievements for ${titleId}: ${existingError.message}`);
      continue;
    }

    const updates = [];
    for (const row of existingRows || []) {
      const rarity = rarityMap.get(String(row.platform_achievement_id));
      if (rarity === undefined) continue;
      if (row.rarity_global !== null && row.rarity_global === rarity) continue;

      updates.push({
        platform_id: row.platform_id,
        platform_game_id: row.platform_game_id,
        platform_achievement_id: row.platform_achievement_id,
        rarity_global: rarity,
        base_status_xp: computeBaseStatusXP(rarity),
        rarity_multiplier: 1.0,
      });
    }

    if (!updates.length) {
      console.log(`[OPENXBL] No updates needed for ${titleId}`);
      continue;
    }

    if (dryRun) {
      console.log(`[DRY RUN] Would update ${updates.length} achievements for ${titleId}`);
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
        .eq('platform_id', update.platform_id)
        .eq('platform_game_id', update.platform_game_id)
        .eq('platform_achievement_id', update.platform_achievement_id);

      if (updateError) {
        console.warn(`Failed to update achievement ${update.platform_achievement_id} for ${titleId}: ${updateError.message}`);
        continue;
      }
      titleUpdated += 1;
    }

    totalUpdated += titleUpdated;
    console.log(`Updated ${titleUpdated} achievements for title ${titleId}`);
  }

  console.log(`Backfill complete. Total achievements updated: ${totalUpdated}`);
  return { updated: totalUpdated, titlesProcessed: uniqueTitles.length };
}

if (process.argv[1] && process.argv[1].includes('backfill-xbox-rarity.js')) {
  const limitTitles = Number(process.env.BACKFILL_LIMIT_TITLES || '50');
  const dryRun = process.env.BACKFILL_DRY_RUN === 'true';
  backfillXboxRarity({ limitTitles, dryRun })
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}