import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
import { syncXboxAchievements } from './xbox-sync.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const ONLY_MISSING = (process.env.BACKFILL_ONLY_MISSING || 'true') === 'true';

function isUuid(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

async function findUser(identifier) {
  if (isUuid(identifier)) {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, xbox_xuid, xbox_user_hash, xbox_access_token, xbox_refresh_token, xbox_gamertag')
      .eq('id', identifier)
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  const { data, error } = await supabase
    .from('profiles')
    .select('id, xbox_xuid, xbox_user_hash, xbox_access_token, xbox_refresh_token, xbox_gamertag')
    .ilike('xbox_gamertag', identifier)
    .maybeSingle();

  if (error) throw error;
  return data;
}

async function run() {
  const identifier = process.argv[2];
  if (!identifier) {
    console.error('Usage: node sync-service/backfill-xbox-achievements-one.js <xbox_gamertag|user_id>');
    process.exit(1);
  }

  const user = await findUser(identifier);
  if (!user) {
    console.error(`No user found for: ${identifier}`);
    process.exit(1);
  }

  if (!user.xbox_xuid || !user.xbox_user_hash || !user.xbox_access_token || !user.xbox_refresh_token) {
    console.error(`User ${user.id} is missing Xbox auth fields.`);
    process.exit(1);
  }

  if (ONLY_MISSING) {
    const needsBackfill = await needsXboxBackfill(user.id);
    if (!needsBackfill) {
      console.log(`⏭️  Skip ${user.xbox_gamertag || user.id} - no missing Xbox data detected`);
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

  console.log(`Starting backfill for ${user.xbox_gamertag || user.id} (${user.id})`);

  await syncXboxAchievements(
    user.id,
    user.xbox_xuid,
    user.xbox_user_hash,
    user.xbox_access_token,
    user.xbox_refresh_token,
    logRow.id,
    { batchSize: process.env.BATCH_SIZE, maxConcurrent: process.env.MAX_CONCURRENT }
  );
}

async function needsXboxBackfill(userId) {
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

run().catch((error) => {
  console.error('Backfill failed:', error?.message || error);
  process.exit(1);
});
