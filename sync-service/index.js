import express from 'express';
import cors from 'cors';
// Lazy-load sync handlers on-demand to avoid boot-time module errors
// (psn-api & other ESM/CJS modules can crash startup when required at top-level)

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Startup diagnostics
console.log('Starting Sync Service');
console.log('Node version:', process.version);
console.log('SUPABASE_URL present:', !!process.env.SUPABASE_URL);
console.log('SUPABASE_SERVICE_ROLE_KEY present:', !!process.env.SUPABASE_SERVICE_ROLE_KEY);
console.log('XBOX_CLIENT_ID present:', !!process.env.XBOX_CLIENT_ID);

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

// Xbox sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/xbox', async (req, res) => {
  const { userId, xuid, userHash, accessToken, refreshToken, syncLogId, batchSize, maxConcurrent } = req.body;

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
    }
  })();
});

// PSN sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/psn', async (req, res) => {
  const { userId, accountId, accessToken, refreshToken, syncLogId, batchSize, maxConcurrent } = req.body;

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
    }
  })();
});

// Steam sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/steam', async (req, res) => {
  const { userId, steamId, apiKey, syncLogId, batchSize, maxConcurrent } = req.body;

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
    }
  })();
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Sync service running on port ${PORT}`);
});
