import 'dotenv/config';
import express from 'express';
import cors from 'cors';
// Lazy-load sync handlers on-demand to avoid boot-time module errors
// (psn-api & other ESM/CJS modules can crash startup when required at top-level)

const app = express();

// Auth middleware - check for SYNC_SERVICE_SECRET
function checkAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  const expectedSecret = process.env.SYNC_SERVICE_SECRET;
  
  console.log('🔐 Auth check - Header received:', authHeader ? 'Bearer [REDACTED]' : '[MISSING]');
  console.log('🔐 Auth check - Expected secret present:', !!expectedSecret);
  
  if (!expectedSecret) {
    console.warn('⚠️ SYNC_SERVICE_SECRET not configured - endpoints are unsecured!');
    return next(); // Allow request if secret not configured (for backwards compatibility)
  }
  
  if (!authHeader || authHeader !== `Bearer ${expectedSecret}`) {
    console.error('❌ Unauthorized request to sync endpoint');
    console.error('❌ Expected:', expectedSecret ? 'Bearer [REDACTED]' : '[NOT SET]');
    console.error('❌ Received:', authHeader || '[MISSING]');
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  console.log('✅ Auth check passed');
  next();
}

// Validation helper
function validateRequired(fields, body) {
  const missing = [];
  for (const field of fields) {
    if (!body[field]) {
      missing.push(field);
    }
  }
  return missing;
}
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Startup diagnostics
console.log('Starting Sync Service');
console.log('Node version:', process.version);
console.log('SUPABASE_URL present:', !!process.env.SUPABASE_URL);
console.log('SUPABASE_SERVICE_ROLE_KEY present:', !!process.env.SUPABASE_SERVICE_ROLE_KEY);
console.log('XBOX_CLIENT_ID present:', !!process.env.XBOX_CLIENT_ID);
console.log('SYNC_SERVICE_SECRET present:', !!process.env.SYNC_SERVICE_SECRET);
console.log('SYNC_SERVICE_SECRET value:', process.env.SYNC_SERVICE_SECRET ? '[SET]' : '[NOT SET]');

let recoveryRunning = false;

async function resumeStuckSyncs() {
  if (recoveryRunning) return;
  recoveryRunning = true;

  try {
    const { createClient } = await import('@supabase/supabase-js');
    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    const cutoffIso = new Date(Date.now() - 15 * 60 * 1000).toISOString();

    // PSN
    const { data: psnUsers } = await supabase
      .from('profiles')
      .select('id, psn_account_id, psn_access_token, psn_refresh_token, psn_sync_status, updated_at')
      .eq('psn_sync_status', 'syncing')
      .lt('updated_at', cutoffIso)
      .not('psn_account_id', 'is', null)
      .not('psn_refresh_token', 'is', null);

    if (psnUsers?.length) {
      const mod = await import('./psn-sync.js');
      const { syncPSNAchievements } = mod;

      for (const user of psnUsers) {
        const { data: logRow } = await supabase
          .from('psn_sync_logs')
          .insert({
            user_id: user.id,
            sync_type: 'full',
            status: 'syncing',
            started_at: new Date().toISOString(),
          })
          .select('id')
          .single();

        if (!logRow?.id) continue;

        syncPSNAchievements(
          user.id,
          user.psn_account_id,
          user.psn_access_token,
          user.psn_refresh_token,
          logRow.id,
          { batchSize: process.env.BATCH_SIZE, maxConcurrent: process.env.MAX_CONCURRENT }
        ).catch((err) => {
          console.error('PSN recovery sync failed:', err);
        });
      }
    }

    // Xbox
    const { data: xboxUsers } = await supabase
      .from('profiles')
      .select('id, xbox_xuid, xbox_user_hash, xbox_access_token, xbox_refresh_token, xbox_sync_status, updated_at')
      .eq('xbox_sync_status', 'syncing')
      .lt('updated_at', cutoffIso)
      .not('xbox_xuid', 'is', null)
      .not('xbox_user_hash', 'is', null)
      .not('xbox_access_token', 'is', null);

    if (xboxUsers?.length) {
      const mod = await import('./xbox-sync.js');
      const { syncXboxAchievements } = mod;

      for (const user of xboxUsers) {
        const { data: logRow } = await supabase
          .from('xbox_sync_logs')
          .insert({
            user_id: user.id,
            sync_type: 'full',
            status: 'syncing',
            started_at: new Date().toISOString(),
          })
          .select('id')
          .single();

        if (!logRow?.id) continue;

        syncXboxAchievements(
          user.id,
          user.xbox_xuid,
          user.xbox_user_hash,
          user.xbox_access_token,
          user.xbox_refresh_token,
          logRow.id,
          { batchSize: process.env.BATCH_SIZE, maxConcurrent: process.env.MAX_CONCURRENT }
        ).catch((err) => {
          console.error('Xbox recovery sync failed:', err);
        });
      }
    }

    // Steam
    const { data: steamUsers } = await supabase
      .from('profiles')
      .select('id, steam_id, steam_api_key, steam_sync_status, updated_at')
      .eq('steam_sync_status', 'syncing')
      .lt('updated_at', cutoffIso)
      .not('steam_id', 'is', null)
      .not('steam_api_key', 'is', null);

    if (steamUsers?.length) {
      const mod = await import('./steam-sync.js');
      const { syncSteamAchievements } = mod;

      for (const user of steamUsers) {
        const { data: logRow } = await supabase
          .from('steam_sync_logs')
          .insert({
            user_id: user.id,
            sync_type: 'full',
            status: 'syncing',
            started_at: new Date().toISOString(),
          })
          .select('id')
          .single();

        if (!logRow?.id) continue;

        syncSteamAchievements(
          user.id,
          user.steam_id,
          user.steam_api_key,
          logRow.id,
          { batchSize: process.env.BATCH_SIZE, maxConcurrent: process.env.MAX_CONCURRENT }
        ).catch((err) => {
          console.error('Steam recovery sync failed:', err);
        });
      }
    }
  } catch (err) {
    console.error('Recovery sync failed:', err);
  } finally {
    recoveryRunning = false;
  }
}

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'StatusXP Sync Service' });
});

// Ultra-simple OK route for quick connectivity tests (no imports or heavy logic)
app.get('/ok', (req, res) => {
  res.status(200).json({ ok: true, time: new Date().toISOString() });
});

// Lightweight health endpoint for quick checks
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'StatusXP Sync Service',
    node_version: process.version,
    supabase_url_present: !!process.env.SUPABASE_URL,
    supabase_key_present: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
    xbox_client_id_present: !!process.env.XBOX_CLIENT_ID,
  });
});

// Global error handlers to surface runtime errors in logs
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception in sync-service:', err);
});
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection in sync-service:', reason);
});

// Handle termination signals to log and allow graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM - shutting down gracefully');
  // Optionally do cleanups here
  process.exit(0);
});
process.on('SIGINT', () => {
  console.log('Received SIGINT - shutting down gracefully');
  process.exit(0);
});
process.on('SIGHUP', () => {
  console.log('Received SIGHUP - shutting down gracefully');
  process.exit(0);
});

// Heartbeat to ensure the container is alive and provide periodic logs for debugging
setInterval(() => {
  const m = process.memoryUsage();
  const rssMB = Math.round(m.rss / 1024 / 1024);
  const heapUsedMB = Math.round(m.heapUsed / 1024 / 1024);
  const heapTotalMB = Math.round(m.heapTotal / 1024 / 1024);
  const usedPercent = Math.round((m.heapUsed / m.heapTotal) * 100);
  console.log('Heartbeat: sync-service alive at', new Date().toISOString(), `rss=${rssMB}MB`, `heap=${heapUsedMB}/${heapTotalMB}MB (${usedPercent}%)`);
  if (usedPercent > 85) {
    console.warn(`Memory high: heapUsed is ${usedPercent}% of heapTotal - forcing GC`);
    if (global.gc) {
      global.gc();
      console.log('GC completed');
    }
  }
}, 60000);

// Resume stuck syncs after restart (Railway resets)
setTimeout(() => {
  resumeStuckSyncs();
}, 15000);

// Xbox sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/xbox', checkAuth, async (req, res) => {
  const { userId, xuid, userHash, accessToken, refreshToken, syncLogId, batchSize, maxConcurrent } = req.body;

  // Validate required fields
  const missing = validateRequired(['userId', 'xuid', 'userHash', 'accessToken', 'refreshToken', 'syncLogId'], req.body);
  if (missing.length > 0) {
    console.error('❌ Xbox sync validation failed - missing fields:', missing);
    return res.status(400).json({ error: `Missing required fields: ${missing.join(', ')}` });
  }

  // Respond immediately so the client doesn't wait
  res.json({ success: true, message: 'Xbox sync started in background' });

  // Run sync in background - lazy import handler to avoid startup crashes
  (async () => {
    try {
      const mod = await import('./xbox-sync.js');
      const { syncXboxAchievements } = mod;
      await syncXboxAchievements(userId, xuid, userHash, accessToken, refreshToken, syncLogId, { batchSize, maxConcurrent });
      console.log('Xbox sync completed - forcing GC');
      if (global.gc) global.gc();
    } catch (err) {
      console.error('Xbox sync error (lazy import):', err);
      // Report error to sync log
      try {
        const { createClient } = await import('@supabase/supabase-js');
        const supabase = createClient(
          process.env.SUPABASE_URL,
          process.env.SUPABASE_SERVICE_ROLE_KEY
        );
        await supabase
          .from('xbox_sync_logs')
          .update({
            status: 'failed',
            error_message: err.message || String(err),
            completed_at: new Date().toISOString(),
          })
          .eq('id', syncLogId);
        await supabase
          .from('profiles')
          .update({ xbox_sync_status: 'error', xbox_sync_error: err.message || String(err) })
          .eq('id', userId);
      } catch (reportErr) {
        console.error('Failed to report Xbox sync error to DB:', reportErr);
      }
    }
  })();
});

// PSN sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/psn', checkAuth, async (req, res) => {
  const { userId, accountId, accessToken, refreshToken, syncLogId, batchSize, maxConcurrent } = req.body;

  // Validate required fields
  const missing = validateRequired(['userId', 'accountId', 'accessToken', 'refreshToken', 'syncLogId'], req.body);
  if (missing.length > 0) {
    console.error('❌ PSN sync validation failed - missing fields:', missing);
    return res.status(400).json({ error: `Missing required fields: ${missing.join(', ')}` });
  }

  // Respond immediately
  res.json({ success: true, message: 'PSN sync started in background' });

  // Run sync in background - lazy import handler to avoid startup crashes
  (async () => {
    try {
      const mod = await import('./psn-sync.js');
      const { syncPSNAchievements } = mod;
      await syncPSNAchievements(userId, accountId, accessToken, refreshToken, syncLogId, { batchSize, maxConcurrent });
      console.log('PSN sync completed - forcing GC');
      if (global.gc) global.gc();
    } catch (err) {
      console.error('PSN sync error (lazy import):', err);
      // Report error to sync log
      try {
        const { createClient } = await import('@supabase/supabase-js');
        const supabase = createClient(
          process.env.SUPABASE_URL,
          process.env.SUPABASE_SERVICE_ROLE_KEY
        );
        await supabase
          .from('psn_sync_logs')
          .update({
            status: 'failed',
            error_message: err.message || String(err),
            completed_at: new Date().toISOString(),
          })
          .eq('id', syncLogId);
        await supabase
          .from('profiles')
          .update({ psn_sync_status: 'error', psn_sync_error: err.message || String(err) })
          .eq('id', userId);
      } catch (reportErr) {
        console.error('Failed to report PSN sync error to DB:', reportErr);
      }
    }
  })();
});

// Steam sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/steam', checkAuth, async (req, res) => {
  const { userId, steamId, apiKey, syncLogId, batchSize, maxConcurrent } = req.body;

  // Validate required fields
  const missing = validateRequired(['userId', 'steamId', 'apiKey', 'syncLogId'], req.body);
  if (missing.length > 0) {
    console.error('❌ Steam sync validation failed - missing fields:', missing);
    return res.status(400).json({ error: `Missing required fields: ${missing.join(', ')}` });
  }

  // Respond immediately
  res.json({ success: true, message: 'Steam sync started in background' });

  // Run sync in background - lazy import handler to avoid startup crashes
  (async () => {
    try {
      const mod = await import('./steam-sync.js');
      const { syncSteamAchievements } = mod;
      await syncSteamAchievements(userId, steamId, apiKey, syncLogId, { batchSize, maxConcurrent });
      console.log('Steam sync completed - forcing GC');
      if (global.gc) global.gc();
    } catch (err) {
      console.error('Steam sync error (lazy import):', err);
      // Report error to sync log
      try {
        const { createClient } = await import('@supabase/supabase-js');
        const supabase = createClient(
          process.env.SUPABASE_URL,
          process.env.SUPABASE_SERVICE_ROLE_KEY
        );
        await supabase
          .from('steam_sync_logs')
          .update({
            status: 'failed',
            error_message: err.message || String(err),
            completed_at: new Date().toISOString(),
          })
          .eq('id', syncLogId);
        await supabase
          .from('profiles')
          .update({ steam_sync_status: 'error', steam_sync_error: err.message || String(err) })
          .eq('id', userId);
      } catch (reportErr) {
        console.error('Failed to report Steam sync error to DB:', reportErr);
      }
    }
  })();
});

// Stop sync endpoints - set cancellation flag in database
app.post('/sync/xbox/stop', checkAuth, async (req, res) => {
  const { userId } = req.body;
  
  if (!userId) {
    return res.status(400).json({ error: 'userId required' });
  }

  try {
    const { createClient } = await import('@supabase/supabase-js');
    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    await supabase
      .from('profiles')
      .update({ xbox_sync_status: 'cancelling' })
      .eq('id', userId);

    res.json({ success: true, message: 'Xbox sync cancellation requested' });
  } catch (err) {
    console.error('Error stopping Xbox sync:', err);
    res.status(500).json({ error: 'Failed to stop sync' });
  }
});

app.post('/sync/psn/stop', checkAuth, async (req, res) => {
  const { userId } = req.body;
  
  if (!userId) {
    return res.status(400).json({ error: 'userId required' });
  }

  try {
    const { createClient } = await import('@supabase/supabase-js');
    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    await supabase
      .from('profiles')
      .update({ psn_sync_status: 'cancelling' })
      .eq('id', userId);

    res.json({ success: true, message: 'PSN sync cancellation requested' });
  } catch (err) {
    console.error('Error stopping PSN sync:', err);
    res.status(500).json({ error: 'Failed to stop sync' });
  }
});

app.post('/sync/steam/stop', checkAuth, async (req, res) => {
  const { userId } = req.body;
  
  if (!userId) {
    return res.status(400).json({ error: 'userId required' });
  }

  try {
    const { createClient } = await import('@supabase/supabase-js');
    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    await supabase
      .from('profiles')
      .update({ steam_sync_status: 'cancelling' })
      .eq('id', userId);

    res.json({ success: true, message: 'Steam sync cancellation requested' });
  } catch (err) {
    console.error('Error stopping Steam sync:', err);
    res.status(500).json({ error: 'Failed to stop sync' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Sync service running on port ${PORT}`);
});
