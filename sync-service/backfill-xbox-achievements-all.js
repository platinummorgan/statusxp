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
  const { data: logRow, error: logError } = await supabase
    .from('xbox_sync_logs')
    .insert({
      user_id: user.id,
      sync_type: 'full',
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
    await runWithConcurrency(users);
  } catch (error) {
    console.error('Backfill failed:', error?.message || error);
    process.exit(1);
  }
})();
