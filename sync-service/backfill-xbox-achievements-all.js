import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
import { syncXboxAchievements } from './xbox-sync.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const USER_CONCURRENCY = Number(process.env.BACKFILL_USER_CONCURRENCY || 1);
const BATCH_SIZE = process.env.BATCH_SIZE;
const MAX_CONCURRENT = process.env.MAX_CONCURRENT;
const ONLY_MISSING = (process.env.BACKFILL_ONLY_MISSING || 'true') === 'true';

async function getXboxUsers() {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, xbox_xuid, xbox_user_hash, xbox_access_token, xbox_refresh_token')
    .not('xbox_xuid', 'is', null)
    .not('xbox_user_hash', 'is', null)
    .not('xbox_access_token', 'is', null)
    .not('xbox_refresh_token', 'is', null);

  if (error) throw error;
  return data || [];
}

async function startSyncForUser(user) {
  if (ONLY_MISSING) {
    const needsBackfill = await needsXboxBackfill(user.id);
    if (!needsBackfill) {
      console.log(`⏭️  Skip user ${user.id} - no missing Xbox data detected`);
      return;
    }
  }

  const { data: logRow, error: logError } = await supabase
    .from('xbox_sync_logs')
    .insert({
      user_id: user.id,
      sync_type: ONLY_MISSING ? 'delta' : 'full',
      status: 'syncing',
      started_at: new Date().toISOString(),
    })
    .select('id')
    .single();

  if (logError || !logRow?.id) {
    throw new Error(`Failed to create xbox_sync_logs for ${user.id}: ${logError?.message || 'unknown error'}`);
  }

  await supabase
    .from('profiles')
    .update({ xbox_sync_status: 'syncing', xbox_sync_progress: 0, xbox_sync_error: null })
    .eq('id', user.id);

  await syncXboxAchievements(
    user.id,
    user.xbox_xuid,
    user.xbox_user_hash,
    user.xbox_access_token,
    user.xbox_refresh_token,
    logRow.id,
    { batchSize: BATCH_SIZE, maxConcurrent: MAX_CONCURRENT }
  );
}

async function needsXboxBackfill(userId) {
  // If no Xbox user_progress rows exist, this is a new user => backfill
  const { count: progressCount, error: progressError } = await supabase
    .from('user_progress')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .in('platform_id', [10, 11, 12]);

  if (progressError) {
    console.error(`⚠️ needsXboxBackfill progress check failed for ${userId}:`, progressError.message);
    return true; // fail open
  }

  if ((progressCount || 0) === 0) return true;

  // Any sync_failed rows => needs backfill
  const { count: failedCount, error: failedError } = await supabase
    .from('user_progress')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .in('platform_id', [10, 11, 12])
    .filter('metadata->>sync_failed', 'eq', 'true');

  if (failedError) {
    console.error(`⚠️ needsXboxBackfill sync_failed check failed for ${userId}:`, failedError.message);
    return true; // fail open
  }

  if ((failedCount || 0) > 0) return true;

  // Missing earned dates (achievements earned but no timestamp)
  const { count: missingDatesCount, error: missingDatesError } = await supabase
    .from('user_progress')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .in('platform_id', [10, 11, 12])
    .gt('achievements_earned', 0)
    .is('last_achievement_earned_at', null);

  if (missingDatesError) {
    console.error(`⚠️ needsXboxBackfill missing dates check failed for ${userId}:`, missingDatesError.message);
    return true; // fail open
  }

  if ((missingDatesCount || 0) > 0) return true;

  // Missing achievement definitions (score exists but total achievements is zero)
  const { count: missingDefsCount, error: missingDefsError } = await supabase
    .from('user_progress')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .in('platform_id', [10, 11, 12])
    .eq('total_achievements', 0)
    .gt('current_score', 0);

  if (missingDefsError) {
    console.error(`⚠️ needsXboxBackfill missing defs check failed for ${userId}:`, missingDefsError.message);
    return true; // fail open
  }

  return (missingDefsCount || 0) > 0;
}

async function runWithConcurrency(users) {
  let index = 0;
  let completed = 0;
  const total = users.length;

  const workers = Array.from({ length: USER_CONCURRENCY }, async () => {
    while (index < total) {
      const currentIndex = index++;
      const user = users[currentIndex];
      console.log(`\n[${currentIndex + 1}/${total}] Backfilling user ${user.id}`);
      try {
        await startSyncForUser(user);
        completed++;
      } catch (error) {
        console.error(`Backfill failed for user ${user.id}:`, error?.message || error);
      }
    }
  });

  await Promise.all(workers);
  console.log(`\nBackfill finished. Completed ${completed}/${total}.`);
}

(async () => {
  try {
    const users = await getXboxUsers();
    console.log(`Found ${users.length} Xbox users to backfill.`);
    if (!users.length) return;
    if (ONLY_MISSING) {
      console.log('Backfill mode: delta (skip users without missing Xbox data)');
    }
    await runWithConcurrency(users);
  } catch (error) {
    console.error('Backfill failed:', error?.message || error);
    process.exit(1);
  }
})();
