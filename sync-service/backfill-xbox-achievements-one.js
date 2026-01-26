import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
import { syncXboxAchievements } from './xbox-sync.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

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

run().catch((error) => {
  console.error('Backfill failed:', error?.message || error);
  process.exit(1);
});
