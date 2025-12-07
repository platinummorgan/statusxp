import express from 'express';
import cors from 'cors';
import { syncXboxAchievements } from './xbox-sync.js';
import { syncPSNAchievements } from './psn-sync.js';
import { syncSteamAchievements } from './steam-sync.js';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'StatusXP Sync Service' });
});

// Xbox sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/xbox', async (req, res) => {
  const { userId, xuid, userHash, accessToken, refreshToken, syncLogId } = req.body;

  // Respond immediately so the client doesn't wait
  res.json({ success: true, message: 'Xbox sync started in background' });

  // Run sync in background - will complete no matter how long it takes
  syncXboxAchievements(userId, xuid, userHash, accessToken, refreshToken, syncLogId).catch(err => {
    console.error('Xbox sync error:', err);
  });
});

// PSN sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/psn', async (req, res) => {
  const { userId, accountId, accessToken, refreshToken, syncLogId } = req.body;

  // Respond immediately
  res.json({ success: true, message: 'PSN sync started in background' });

  // Run sync in background
  syncPSNAchievements(userId, accountId, accessToken, refreshToken, syncLogId).catch(err => {
    console.error('PSN sync error:', err);
  });
});

// Steam sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/steam', async (req, res) => {
  const { userId, steamId, apiKey, syncLogId } = req.body;

  // Respond immediately
  res.json({ success: true, message: 'Steam sync started in background' });

  // Run sync in background
  syncSteamAchievements(userId, steamId, apiKey, syncLogId).catch(err => {
    console.error('Steam sync error:', err);
  });
});

app.listen(PORT, () => {
  console.log(`Sync service running on port ${PORT}`);
});
