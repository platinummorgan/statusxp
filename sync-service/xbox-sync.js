import { createClient } from '@supabase/supabase-js';
import { uploadGameCover, uploadExternalIcon } from './icon-proxy-utils.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const ENV_BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '5', 10);
const ENV_MAX_CONCURRENT = parseInt(process.env.MAX_CONCURRENT || '1', 10);

// Helper to download external avatar and upload to Supabase Storage
async function uploadExternalAvatar(externalUrl, userId, platform) {
  try {
    console.log(`[AVATAR STORAGE] Downloading ${platform} avatar from:`, externalUrl);
    
    // Download the image from the external URL
    const response = await fetch(externalUrl);
    if (!response.ok) {
      console.error(`[AVATAR STORAGE] Failed to download avatar: ${response.status}`);
      return null;
    }

    // Get the image data as a buffer
    const arrayBuffer = await response.arrayBuffer();
    
    // Determine file extension from content type
    const contentType = response.headers.get('content-type') || 'image/jpeg';
    let extension = 'jpg';
    if (contentType.includes('png')) extension = 'png';
    else if (contentType.includes('gif')) extension = 'gif';
    else if (contentType.includes('webp')) extension = 'webp';
    
    // Create a unique filename: user-avatars/{platform}_{userId}_{timestamp}.ext
    const timestamp = Date.now();
    const filename = `user-avatars/${platform}_${userId}_${timestamp}.${extension}`;
    
    console.log(`[AVATAR STORAGE] Uploading to Supabase Storage: ${filename}`);
    
    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from('avatars')
      .upload(filename, arrayBuffer, {
        contentType,
        upsert: true,
      });

    if (error) {
      console.error('[AVATAR STORAGE] Upload error:', error);
      return null;
    }

    // Get the public URL
    const { data: { publicUrl } } = supabase.storage
      .from('avatars')
      .getPublicUrl(filename);

    console.log(`[AVATAR STORAGE] Successfully uploaded avatar:`, publicUrl);
    return publicUrl;
  } catch (error) {
    console.error('[AVATAR STORAGE] Exception:', error);
    return null;
  }
}

// Helper to safely update sync status with retries
async function updateSyncStatus(userId, updates, retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const { error } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId);
      
      if (!error) {
        console.log(`✅ Status updated successfully:`, updates);
        return true;
      }
      
      console.error(`❌ Attempt ${attempt}/${retries} failed:`, error);
      if (attempt < retries) {
        await new Promise(resolve => setTimeout(resolve, 1000 * attempt)); // Exponential backoff
      }
    } catch (err) {
      console.error(`❌ Attempt ${attempt}/${retries} threw error:`, err.message);
      if (attempt < retries) {
        await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
      }
    }
  }
  
  console.error('🚨 CRITICAL: Failed to update sync status after all retries');
  return false;
}

function logMemory(label) {
  try {
    const m = process.memoryUsage();
    console.log(label, `rss=${Math.round(m.rss/1024/1024)}MB`, `heapUsed=${Math.round(m.heapUsed/1024/1024)}MB`, `heapTotal=${Math.round(m.heapTotal/1024/1024)}MB`, `external=${Math.round(m.external/1024/1024)}MB`);
  } catch (e) {
    console.log('logMemory error', e.message);
  }
}

function mapXboxPlatformToPlatformId(devices) {
  if (!devices || !Array.isArray(devices) || devices.length === 0) {
    return { platformId: 11, platformVersion: 'XboxOne', isPCOnly: false }; // Default to Xbox One
  }
  
  const deviceTypes = devices.map(d => d.toLowerCase());
  
  // Check if PC-only (Xbox achievements earned on PC via Game Pass/Microsoft Store)
  const hasConsole = deviceTypes.some(d => 
    d.includes('xbox') && d !== 'pc'
  );
  const isPCOnly = !hasConsole && deviceTypes.includes('pc');
  
  // Check in order: newest to oldest (same as PSN)
  // Xbox API returns 'XboxSeries' for both Series S and X
  if (deviceTypes.includes('xboxseriess') || deviceTypes.includes('xboxseriesx') || deviceTypes.includes('xboxseries')) {
    return { platformId: 12, platformVersion: 'XboxSeriesX', isPCOnly };
  }
  if (deviceTypes.includes('xboxone')) {
    return { platformId: 11, platformVersion: 'XboxOne', isPCOnly };
  }
  if (deviceTypes.includes('xbox360')) {
    return { platformId: 10, platformVersion: 'Xbox360', isPCOnly };
  }
  
  // PC-only Xbox achievements default to Xbox One platform
  return { platformId: 11, platformVersion: 'XboxOne', isPCOnly };
}

function validateXboxPlatformMapping(devices, platformId, gameName, titleId, isPCOnly = false) {
  if (!devices || !Array.isArray(devices)) {
    // No device info available, skip validation
    return true;
  }
  
  // Skip validation for PC-only Xbox achievements
  if (isPCOnly) {
    return true;
  }
  
  const deviceTypes = devices.map(d => d.toLowerCase());
  
  // For cross-platform games, we pick the newest platform
  // So validation should check if assigned platform exists in the devices array, not exact match
  const platformMap = {
    10: 'xbox360',
    11: 'xboxone',
    12: ['xboxseriess', 'xboxseriesx', 'xboxseries'] // Xbox API returns 'XboxSeries' for both S and X
  };
  
  const assignedPlatformDevices = platformMap[platformId];
  if (!assignedPlatformDevices) {
    console.error(
      `🚨 INVALID PLATFORM ID: ${platformId} | ` +
      `game="${gameName}" | titleId=${titleId}`
    );
    return false;
  }
  
  // Check if assigned platform exists in devices array
  const platformDeviceArray = Array.isArray(assignedPlatformDevices) 
    ? assignedPlatformDevices 
    : [assignedPlatformDevices];
  
  const platformExists = platformDeviceArray.some(device => 
    deviceTypes.includes(device)
  );
  
  if (!platformExists) {
    console.error(
      `🚨 PLATFORM MISMATCH: Assigned ${platformMap[platformId]} (id=${platformId}) but not in Xbox devices [${devices.join(', ')}] | ` +
      `game="${gameName}" | titleId=${titleId}`
    );
    return false;
  }
  
  return true;
}

async function refreshXboxToken(refreshToken, userId) {
  const tokenResponse = await fetch('https://login.live.com/oauth20_token.srf', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: process.env.XBOX_CLIENT_ID,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
      scope: 'Xboxlive.signin Xboxlive.offline_access',
    }),
  });

  if (!tokenResponse.ok) {
    const body = await tokenResponse.text();
    console.error('Failed to refresh Xbox token. Status:', tokenResponse.status, 'Body:', body);
    if (body.includes('invalid_client') || body.includes('does not exist or is not enabled for consumers')) {
      throw new Error('Xbox link expired. Please unlink and relink your Xbox account.');
    }
    throw new Error('Failed to refresh Xbox token');
  }

  const tokenData = await tokenResponse.json();

  // Exchange for Xbox Live token
  const xblResponse = await fetch('https://user.auth.xboxlive.com/user/authenticate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      RelyingParty: 'http://auth.xboxlive.com',
      TokenType: 'JWT',
      Properties: {
        AuthMethod: 'RPS',
        SiteName: 'user.auth.xboxlive.com',
        RpsTicket: `d=${tokenData.access_token}`,
      },
    }),
  });

  if (!xblResponse.ok) {
    const xblBody = await xblResponse.text();
    console.error('XBL auth failed. Status:', xblResponse.status, 'Body:', xblBody);
    throw new Error(`XBL authentication failed: ${xblResponse.status}`);
  }
  
  const xblData = await xblResponse.json();
  console.log('XBL auth response (xblData) keys:', Object.keys(xblData));
  
  if (!xblData.DisplayClaims || !xblData.DisplayClaims.xui || !xblData.DisplayClaims.xui[0]) {
    console.error('XBL response missing DisplayClaims:', JSON.stringify(xblData));
    throw new Error('XBL response missing DisplayClaims');
  }
  
  const userHash = xblData.DisplayClaims.xui[0].uhs;

  // Exchange for XSTS token
  const xstsResponse = await fetch('https://xsts.auth.xboxlive.com/xsts/authorize', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      RelyingParty: 'http://xboxlive.com',
      TokenType: 'JWT',
      Properties: {
        UserTokens: [xblData.Token],
        SandboxId: 'RETAIL',
      },
    }),
  });

  if (!xstsResponse.ok) {
    const xstsBody = await xstsResponse.text();
    console.error('XSTS auth failed. Status:', xstsResponse.status, 'Body:', xstsBody);
    throw new Error(`XSTS authentication failed: ${xstsResponse.status}`);
  }
  
  const xstsData = await xstsResponse.json();
  console.log('XSTS response status:', xstsResponse.status);
  
  if (!xstsData.DisplayClaims || !xstsData.DisplayClaims.xui || !xstsData.DisplayClaims.xui[0]) {
    console.error('XSTS response missing DisplayClaims:', JSON.stringify(xstsData));
    throw new Error('XSTS response missing DisplayClaims');
  }
  
  const xuid = xstsData.DisplayClaims.xui[0].xid;

  // Fetch gamertag and avatar from Xbox Live profile
  console.log('[GAMERTAG FETCH] Starting gamertag fetch for xuid:', xuid);
  let gamertag = 'Unknown';
  let avatarUrl = null;
  try {
    const profileUrl = `https://profile.xboxlive.com/users/xuid(${xuid})/profile/settings?settings=Gamertag,GameDisplayPicRaw`;
    console.log('[GAMERTAG FETCH] URL:', profileUrl);
    const profileResponse = await fetch(profileUrl, {
      headers: {
        'Authorization': `XBL3.0 x=${userHash};${xstsData.Token}`,
        'x-xbl-contract-version': '2',
      },
    });
    
    console.log('[GAMERTAG FETCH] Response status:', profileResponse.status);
    if (profileResponse.ok) {
      const profileData = await profileResponse.json();
      console.log('[GAMERTAG FETCH] Response data:', JSON.stringify(profileData));
      const settings = profileData.profileUsers?.[0]?.settings || [];
      const gamertagSetting = settings.find(s => s.id === 'Gamertag');
      const avatarSetting = settings.find(s => s.id === 'GameDisplayPicRaw');
      if (gamertagSetting) {
        gamertag = gamertagSetting.value;
        console.log('[GAMERTAG FETCH] ✅ SUCCESS - Fetched Xbox gamertag:', gamertag);
      } else {
        console.log('[GAMERTAG FETCH] ❌ FAILED - Gamertag not found in response');
      }
      if (avatarSetting) {
        avatarUrl = avatarSetting.value;
        console.log('[GAMERTAG FETCH] ✅ SUCCESS - Fetched Xbox avatar URL:', avatarUrl);
      }
    } else {
      console.log('[GAMERTAG FETCH] ❌ FAILED - Bad response status');
    }
  } catch (e) {
    console.error('[GAMERTAG FETCH] ❌ EXCEPTION:', e.message, e.stack);
  }

  // Save to database
  console.log('[GAMERTAG SAVE] Saving gamertag to database:', gamertag, 'for user:', userId);
  
  // Get current profile to check display_name and preferred_display_platform
  const { data: currentProfile } = await supabase
    .from('profiles')
    .select('display_name, preferred_display_platform')
    .eq('id', userId)
    .single();
  
  const updateData = {
    xbox_access_token: xstsData.Token,
    xbox_refresh_token: tokenData.refresh_token,
    xbox_xuid: xuid,
    xbox_user_hash: userHash,
    xbox_gamertag: gamertag,
  };
  
  // If display_name is missing or should use Xbox name, update it
  if (!currentProfile?.display_name || currentProfile.preferred_display_platform === 'xbox') {
    updateData.display_name = gamertag;
    console.log('[GAMERTAG SAVE] Updating display_name to:', gamertag);
  }
  
  if (avatarUrl) {
    console.log('[GAMERTAG SAVE] Proxying Xbox avatar through Supabase Storage...');
    const proxiedUrl = await uploadExternalAvatar(avatarUrl, userId, 'xbox');
    if (proxiedUrl) {
      updateData.xbox_avatar_url = proxiedUrl;
      console.log('[GAMERTAG SAVE] Successfully proxied Xbox avatar:', proxiedUrl);
    } else {
      console.warn('[GAMERTAG SAVE] Failed to proxy avatar, using external URL');
      updateData.xbox_avatar_url = avatarUrl;
    }
  }
  const updateProfile = await supabase
    .from('profiles')
    .update(updateData)
    .eq('id', userId);
  console.log('[GAMERTAG SAVE] Save result:', updateProfile.error || 'OK');

  return {
    accessToken: xstsData.Token,
    xuid,
    userHash,
  };
}

export async function syncXboxAchievements(userId, xuid, userHash, accessToken, refreshToken, syncLogId, options = {}) {
  console.log(`Starting Xbox sync for user ${userId}, syncLogId=${syncLogId}`);
  
  // CRITICAL: Validate profile exists before starting sync
  const { data: profileValidation, error: profileError } = await supabase
    .from('profiles')
    .select('id, xbox_xuid')
    .eq('id', userId)
    .maybeSingle();
  
  if (profileError) {
    const errorMsg = `Profile lookup failed: ${profileError.message}`;
    console.error('🚨 FATAL:', errorMsg);
    await supabase
      .from('xbox_sync_logs')
      .update({ 
        status: 'failed', 
        error_message: errorMsg,
        completed_at: new Date().toISOString()
      })
      .eq('id', syncLogId);
    throw new Error(errorMsg);
  }
  
  if (!profileValidation) {
    const errorMsg = `Profile not found for user ${userId}. User may have been deleted or has corrupted data.`;
    console.error('🚨 FATAL:', errorMsg);
    await supabase
      .from('xbox_sync_logs')
      .update({ 
        status: 'failed', 
        error_message: errorMsg,
        completed_at: new Date().toISOString()
      })
      .eq('id', syncLogId);
    throw new Error(errorMsg);
  }

  console.log(`✅ Profile validated for user ${userId}`);
  
  try {
    // Refresh token first
    const refreshed = await refreshXboxToken(refreshToken, userId);
    accessToken = refreshed.accessToken;
    xuid = refreshed.xuid;
    userHash = refreshed.userHash;

    // Set initial status
    const profileUpdateRes = await supabase
      .from('profiles')
      .update({ xbox_sync_status: 'syncing', xbox_sync_progress: 0 })
      .eq('id', userId);
    console.log('Set profile to syncing:', profileUpdateRes.error || 'OK');

    await supabase
      .from('xbox_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    // Calculate actual values from env and options
    const BATCH_SIZE = parseInt(options.batchSize, 10) || ENV_BATCH_SIZE;
    const MAX_CONCURRENT = parseInt(options.maxConcurrent, 10) || ENV_MAX_CONCURRENT;

    console.log(`Using BATCH_SIZE=${BATCH_SIZE}, MAX_CONCURRENT=${MAX_CONCURRENT}`);

    // Fetch all games
    const titleHistoryResponse = await fetch(
      `https://titlehub.xboxlive.com/users/xuid(${xuid})/titles/titlehistory/decoration/achievement`,
      {
        headers: {
          'x-xbl-contract-version': '2',
          'Accept-Language': 'en-US',
          Authorization: `XBL3.0 x=${userHash};${accessToken}`,
        },
      }
    );

    const titleHistory = await titleHistoryResponse.json();
    console.log('Fetched title history - titles length:', (titleHistory?.titles || []).length);
    
    if (!titleHistory?.titles || titleHistory.titles.length === 0) {
      console.log('No Xbox titles found - marking sync as success with 0 games');
      await supabase
        .from('profiles')
        .update({
          xbox_sync_status: 'success',
          xbox_sync_progress: 100,
          last_xbox_sync_at: new Date().toISOString(),
        })
        .eq('id', userId);

      await supabase
        .from('xbox_sync_logs')
        .update({
          status: 'completed',
          completed_at: new Date().toISOString(),
          games_processed: 0,
          achievements_synced: 0,
        })
        .eq('id', syncLogId);
      return;
    }

    const gamesWithProgress = titleHistory.titles.filter(t => {
      const currentGamerscore = t.achievement?.currentGamerscore || 0;
      const currentAchievements = t.achievement?.currentAchievements || 0;
      if (currentGamerscore > 0 || currentAchievements > 0) return true;

      const devices = (t.devices || []).map(d => d.toLowerCase());
      const isXbox360 = devices.includes('xbox360');
      const totalGamerscore = t.achievement?.totalGamerscore || 0;
      const totalAchievements = t.achievement?.totalAchievements || 0;

      // Xbox 360 titles can report 0 current progress; include if the title has achievements
      return isXbox360 && (totalGamerscore > 0 || totalAchievements > 0);
    });

    console.log(`Found ${gamesWithProgress.length} games with achievements`);
    logMemory('After filtering gamesWithProgress');

    // V2 Schema: Each Xbox version has its own platform_id
    // Xbox360=10, XboxOne=11, XboxSeriesX=12
    console.log('Xbox sync: Xbox360=10, XboxOne=11, XboxSeriesX=12');

    // Load ALL user_progress ONCE for fast lookup (across all Xbox platforms)
    console.log('Loading all user_progress for comparison...');
    const { data: existingUserGames } = await supabase
      .from('user_progress')
      .select('platform_game_id, platform_id, achievements_earned, total_achievements, completion_percentage, metadata, synced_at, current_score')
      .eq('user_id', userId)
      .in('platform_id', [10, 11, 12]); // All Xbox platforms
    
    const userGamesMap = new Map();
    for (const ug of existingUserGames || []) {
      userGamesMap.set(`${ug.platform_game_id}_${ug.platform_id}`, ug);
    }
    console.log(`Loaded ${userGamesMap.size} existing user_progress records into memory`);

    let processedGames = 0;
    let totalAchievements = 0;
    
    // Process in batches to avoid OOM and reduce memory footprint
    // NOTE: BATCH_SIZE configurable via env var
    for (let i = 0; i < gamesWithProgress.length; i += BATCH_SIZE) {
      // Check if sync was cancelled
      const { data: profileCheck, error: profileCheckError } = await supabase
        .from('profiles')
        .select('xbox_sync_status')
        .eq('id', userId)
        .maybeSingle();
      
      if (profileCheckError) {
        console.error('❌ Profile check failed:', profileCheckError);
        throw new Error(`Profile lookup failed: ${profileCheckError.message}`);
      }
      
      if (profileCheck?.xbox_sync_status === 'cancelling') {
        console.log('Xbox sync cancelled by user');
        await supabase
          .from('profiles')
          .update({ 
            xbox_sync_status: 'stopped',
            xbox_sync_progress: 0 
          })
          .eq('id', userId);
        
        await supabase
          .from('xbox_sync_logs')
          .update({ status: 'cancelled', error: 'Cancelled by user' })
          .eq('id', syncLogId);
        
        return;
      }
      
      const batch = gamesWithProgress.slice(i, i + BATCH_SIZE);
      logMemory(`Before processing batch ${i / BATCH_SIZE + 1}`);
      // Process the batch with limited concurrency to reduce memory spikes
      // If MAX_CONCURRENT === 1 we'll process sequentially.
      if (MAX_CONCURRENT <= 1) {
        for (let batchIndex = 0; batchIndex < batch.length; batchIndex++) {
          const title = batch[batchIndex];
          
          // Check for cancellation every 5 games within batch
          if (batchIndex > 0 && batchIndex % 5 === 0) {
            const { data: cancelCheck } = await supabase
              .from('profiles')
              .select('xbox_sync_status')
              .eq('id', userId)
              .maybeSingle();
            
            if (cancelCheck?.xbox_sync_status === 'cancelling') {
              console.log('Xbox sync cancelled by user (mid-batch)');
              await supabase
                .from('profiles')
                .update({ 
                  xbox_sync_status: 'stopped',
                  xbox_sync_progress: 0 
                })
                .eq('id', userId);
              
              await supabase
                .from('xbox_sync_logs')
                .update({ status: 'cancelled', error: 'Cancelled by user' })
                .eq('id', syncLogId);
              
              return;
            }
          }
          
          try {
            console.log(`Processing game: ${title.name} (${title.titleId})`);
            
            // Detect platform version and map to platform_id
            // Xbox360=10, XboxOne=11, XboxSeriesX=12
            const platformMapping = mapXboxPlatformToPlatformId(title.devices);
            let platformId = platformMapping.platformId;
            let platformVersion = platformMapping.platformVersion;
            let isPCOnly = platformMapping.isPCOnly;
            
            if (isPCOnly) {
              console.log(`💻 PC-only game: ${title.devices?.join(', ')} → ${platformVersion} (ID ${platformId})`);
            } else {
              console.log(`📱 Platform detected: ${title.devices?.join(', ')} → ${platformVersion} (ID ${platformId})`);
            }
            
            // Validate platform mapping
            if (!validateXboxPlatformMapping(title.devices, platformId, title.name, title.titleId, isPCOnly)) {
              console.error(`⚠️  Skipping game due to platform mismatch: ${title.name}`);
              continue;
            }
            
            // Find or create game using unique Xbox titleId
            const trimmedName = title.name.trim();
            
            // Check if game already exists on ANY platform to prevent duplicates
            const { data: existingOnAnyPlatform } = await supabase
              .from('games')
              .select('platform_id, platform_game_id, name')
              .eq('platform_game_id', title.titleId)
              .maybeSingle();
            
            if (existingOnAnyPlatform) {
              const platformNames = { 10: 'Xbox 360', 11: 'Xbox One', 12: 'Xbox Series X|S' };
              console.log(`⚠️  Game already exists: ${trimmedName} (${title.titleId})`);
              console.log(`   Found on ${platformNames[existingOnAnyPlatform.platform_id]}, Xbox API detected ${platformNames[platformId]}`);
              console.log(`   Using existing ${platformNames[existingOnAnyPlatform.platform_id]} entry to prevent duplicate`);
              platformId = existingOnAnyPlatform.platform_id;
              platformVersion = platformNames[existingOnAnyPlatform.platform_id];
            }
            
            // First try to find by Xbox titleId (platform_game_id) with composite key
            const { data: existingGameById } = await supabase
              .from('games')
              .select('platform_game_id, cover_url, metadata')
              .eq('platform_id', platformId)
              .eq('platform_game_id', title.titleId)
              .maybeSingle();
            
            let gameTitle;
            if (existingGameById) {
              // Found by composite key - this is the exact game
              if (!existingGameById.cover_url && title.displayImage) {
                console.log('Attempting to update Xbox game:', { 
                  name: title.name, 
                  platform_game_id: existingGameById.platform_game_id, 
                  titleId: title.titleId
                });
                
                const proxiedCoverUrl = await uploadGameCover(title.displayImage, platformId, title.titleId, supabase);
                
                const { error: updateError } = await supabase
                  .from('games')
                  .update({ cover_url: proxiedCoverUrl || title.displayImage })
                  .eq('platform_id', platformId)
                  .eq('platform_game_id', existingGameById.platform_game_id);
                
                if (updateError) {
                  console.error('❌ Failed to update game cover:', title.name, 'Error:', updateError);
                  console.error('  - Platform Game ID was:', existingGameById.platform_game_id);
                }
              }
              gameTitle = existingGameById;
            } else {
              // Not found - upsert game with V2 composite key (race-condition safe)
              const proxiedCoverUrl = title.displayImage 
                ? await uploadGameCover(title.displayImage, platformId, title.titleId, supabase)
                : null;
              
              const gamePayload = {
                platform_id: platformId,
                platform_game_id: title.titleId,
                name: trimmedName,
                metadata: { 
                  xbox_title_id: title.titleId,
                  platform_version: platformVersion
                },
              };
              
              // Only set cover_url if we have a new value
              const newCoverUrl = proxiedCoverUrl || title.displayImage;
              if (newCoverUrl) {
                gamePayload.cover_url = newCoverUrl;
              }
              
              const { data: newGame, error: insertError } = await supabase
                .from('games')
                .upsert(gamePayload, {
                  onConflict: 'platform_id,platform_game_id'
                })
                .select()
                .single();
              
              if (insertError) {
                console.error('❌ Failed to upsert game:', title.name, 'Error:', insertError);
                continue;
              }
              gameTitle = newGame;
            }

            if (!gameTitle) continue;

            // Log the achievement data from Xbox API
            console.log(`[XBOX ACHIEVEMENTS] ${title.name}: currentAchievements=${title.achievement.currentAchievements}, totalAchievements=${title.achievement.totalAchievements}, currentGamerscore=${title.achievement.currentGamerscore}, totalGamerscore=${title.achievement.totalGamerscore}`);

            const existingUserGame = userGamesMap.get(`${gameTitle.platform_game_id}_${platformId}`);
            const isNewGame = !existingUserGame;
            const syncFailed = existingUserGame && existingUserGame.metadata?.sync_failed === true;
            
            // For diff check: use current gamerscore/achievements
            const apiEarnedAchievements = title.achievement.currentAchievements || 0;
            const apiGamerscore = title.achievement.currentGamerscore || 0;
            
            const countsChanged = existingUserGame && 
              (existingUserGame.achievements_earned !== apiEarnedAchievements ||
               existingUserGame.current_score !== apiGamerscore);
            
            // Check if rarity is stale (>30 days old)
            let needRarityRefresh = false;
            if (!isNewGame && !countsChanged && !syncFailed && existingUserGame) {
              const lastRaritySync = existingUserGame.metadata?.last_rarity_sync ? new Date(existingUserGame.metadata.last_rarity_sync) : null;
              const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
              needRarityRefresh = !lastRaritySync || lastRaritySync < thirtyDaysAgo;
            }
            
            // CRITICAL: Check if achievements are missing from user_achievements table
            let missingAchievements = false;
            let hasAchievementDefs = true;
            let suspiciousZeroAchievements = false;
            if (!isNewGame && !countsChanged && !syncFailed) {
              try {
                // If API reports gamerscore but 0 achievements, force a reprocess (likely Xbox 360 issue)
                if (apiGamerscore > 0 && apiEarnedAchievements === 0 && existingUserGame?.achievements_earned === 0) {
                  suspiciousZeroAchievements = true;
                  console.log(`🔍 ZERO ACHIEVEMENTS WITH SCORE: ${title.name} (API score: ${apiGamerscore})`);
                }

                const { count: gameAchievementsCount } = await supabase
                  .from('achievements')
                  .select('*', { count: 'exact', head: true })
                  .eq('platform_id', platformId)
                  .eq('platform_game_id', gameTitle.platform_game_id);

                hasAchievementDefs = (gameAchievementsCount || 0) > 0;
                if (hasAchievementDefs && apiEarnedAchievements > 0) {
                  const { count: existingAchievementsCount } = await supabase
                    .from('user_achievements')
                    .select('*', { count: 'exact', head: true })
                    .eq('user_id', userId)
                    .eq('platform_id', platformId)
                    .eq('platform_game_id', gameTitle.platform_game_id);

                  if (existingAchievementsCount === 0 || existingAchievementsCount < apiEarnedAchievements) {
                    missingAchievements = true;
                    console.log(`🔍 MISSING ACHIEVEMENTS: ${title.name} (DB: ${existingAchievementsCount}, API: ${apiEarnedAchievements})`);
                  }
                }
              } catch (checkError) {
                console.error(`⚠️ Error checking missing achievements for ${title.name}:`, checkError);
                // Continue without the check - don't break the sync
              }
            }
            
            const forceFullSync = process.env.FORCE_FULL_SYNC === 'true';
            const needsProcessing = forceFullSync || isNewGame || countsChanged || needRarityRefresh || syncFailed || missingAchievements || !hasAchievementDefs || suspiciousZeroAchievements;
            
            if (!needsProcessing) {
              console.log(`⏭️  Skip ${title.name} - no changes`);
              processedGames++;
              const progressPercent = Math.floor((processedGames / gamesWithProgress.length) * 100);
              await supabase.from('profiles').update({ xbox_sync_progress: progressPercent }).eq('id', userId);
              continue;
            }
            if (forceFullSync) {
              console.log(`🔄 FULL SYNC MODE: ${title.name} - reprocessing to fix data`);
            }
            
            if (needRarityRefresh) {
              console.log(`🔄 RARITY REFRESH: ${title.name} (>30 days since last rarity sync)`);
            }
            
            if (syncFailed) {
              console.log(`🔄 RETRY FAILED SYNC: ${title.name} (previous sync failed)`);
            }

            // Fetch ALL achievements for this title (handle pagination)
            const achievementsForTitle = [];
            let continuationToken = null;
            let pageCount = 0;
            
            do {
              const url = continuationToken
                ? `https://achievements.xboxlive.com/users/xuid(${xuid})/achievements?titleId=${title.titleId}&continuationToken=${continuationToken}`
                : `https://achievements.xboxlive.com/users/xuid(${xuid})/achievements?titleId=${title.titleId}`;
              
              const achievementsResponse = await fetch(url, {
                headers: {
                  'x-xbl-contract-version': '2',
                  Authorization: `XBL3.0 x=${userHash};${accessToken}`,
                },
              });

              if (!achievementsResponse.ok) {
                console.error(`[XBOX ACHIEVEMENTS] Failed to fetch achievements page ${pageCount + 1} for ${title.name}: ${achievementsResponse.status}`);
                break;
              }

              const achievementsData = await achievementsResponse.json();
              const pageAchievements = achievementsData?.achievements || [];
              
              // LOG FIRST ACHIEVEMENT TO SEE FULL STRUCTURE
              if (pageCount === 0 && pageAchievements.length > 0) {
                console.log(`[XBOX API DEBUG] First achievement structure for ${title.name}:`, JSON.stringify(pageAchievements[0], null, 2));
              }
              
              achievementsForTitle.push(...pageAchievements);
              
              continuationToken = achievementsData?.pagingInfo?.continuationToken || null;
              pageCount++;
              
              console.log(`[XBOX ACHIEVEMENTS] ${title.name}: Fetched page ${pageCount} with ${pageAchievements.length} achievements (total so far: ${achievementsForTitle.length})`);
              
              // Safety: prevent infinite loops
              if (pageCount > 20) {
                console.warn(`[XBOX ACHIEVEMENTS] ${title.name}: Stopped after 20 pages to prevent infinite loop`);
                break;
              }
            } while (continuationToken);

            let totalAchievementsFromAPI = achievementsForTitle.length;
            console.log(`[XBOX ACHIEVEMENTS] ${title.name}: Fetched total of ${totalAchievementsFromAPI} achievements across ${pageCount} pages`);

            // Fallback: Xbox 360 titles sometimes return 0 achievements from Xbox API
            let usedOpenXblPlayerFallback = false;
            if (totalAchievementsFromAPI === 0) {
              const openXBLKey = process.env.OPENXBL_API_KEY;
              if (openXBLKey) {
                try {
                  const openXblResponse = await fetch(
                    `https://xbl.io/api/v2/achievements/player/${xuid}/${title.titleId}`,
                    { headers: { 'x-authorization': openXBLKey } }
                  );

                  if (openXblResponse.ok) {
                    const openXblData = await openXblResponse.json();
                    const openXblAchievements = openXblData?.achievements || [];
                    if (openXblAchievements.length > 0) {
                      achievementsForTitle.push(...openXblAchievements);
                      totalAchievementsFromAPI = achievementsForTitle.length;
                      usedOpenXblPlayerFallback = true;
                      console.log(`[OPENXBL] Using player achievements fallback for ${title.name} (${totalAchievementsFromAPI} achievements)`);
                    }
                  } else {
                    console.log(`[OPENXBL] Player endpoint failed (${openXblResponse.status}) for ${title.name}`);
                  }
                } catch (openXblError) {
                  console.error(`[OPENXBL] Player endpoint error for ${title.name}:`, openXblError);
                }
              } else {
                console.warn('[OPENXBL] OPENXBL_API_KEY not set; cannot use player achievements fallback.');
              }
            }

            // Check if this game needs rarity refresh (30+ days since last update)
            const { data: rarityCheckGame } = await supabase
              .from('achievements')
              .select('rarity_last_updated_at')
              .eq('game_title_id', gameTitle.id)
              .eq('platform', 'xbox')
              .order('rarity_last_updated_at', { ascending: false })
              .limit(1)
              .single();

            const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
            const needsRarityUpdate = !rarityCheckGame?.rarity_last_updated_at || 
                                      new Date(rarityCheckGame.rarity_last_updated_at) < thirtyDaysAgo;

            // Check if any achievements for this game have NULL rarity
            let hasNullRarity = false;
            if (!needsRarityUpdate) {
              const { data: nullCheck } = await supabase
                .from('achievements')
                .select('id')
                .eq('game_title_id', gameTitle.id)
                .eq('platform', 'xbox')
                .is('rarity_global', null)
                .limit(1)
                .maybeSingle();
              hasNullRarity = !!nullCheck;
            }

            // Fetch rarity data from OpenXBL (only if needed to save API calls)
            let openXBLRarityMap = new Map();
            if (needsRarityUpdate || hasNullRarity) {
              if (hasNullRarity && !needsRarityUpdate) {
                console.log(`[OPENXBL] Forcing rarity fetch - has NULL rarity despite recent sync`);
              }
              try {
                const openXBLKey = process.env.OPENXBL_API_KEY;
                if (openXBLKey) {
                  // Use title endpoint (requires paid tier) for complete rarity data
                  const rarityResponse = await fetch(
                    `https://xbl.io/api/v2/achievements/title/${title.titleId}`,
                    {
                      headers: {
                        'x-authorization': openXBLKey,
                      },
                    }
                  );
                  
                  if (rarityResponse.ok) {
                    const rarityData = await rarityResponse.json();
                    const achievementsWithRarity = rarityData?.achievements || [];
                    for (const ach of achievementsWithRarity) {
                      if (ach.rarity?.currentPercentage !== undefined) {
                        openXBLRarityMap.set(ach.id, ach.rarity.currentPercentage);
                      }
                    }
                    console.log(`[OPENXBL] Fetched rarity for ${openXBLRarityMap.size} achievements (title endpoint)`);
                  } else {
                    console.log(`[OPENXBL] Title endpoint failed (${rarityResponse.status}), trying player endpoint fallback`);
                    // Fallback to player endpoint if title endpoint fails
                    const playerRarityResponse = await fetch(
                      `https://xbl.io/api/v2/achievements/player/${xuid}/${title.titleId}`,
                      {
                        headers: {
                          'x-authorization': openXBLKey,
                        },
                      }
                    );
                    
                    if (playerRarityResponse.ok) {
                      const playerRarityData = await playerRarityResponse.json();
                      const playerAchievements = playerRarityData?.achievements || [];
                      for (const ach of playerAchievements) {
                        if (ach.rarity?.currentPercentage !== undefined) {
                          openXBLRarityMap.set(ach.id, ach.rarity.currentPercentage);
                        }
                      }
                      console.log(`[OPENXBL] Fetched rarity for ${openXBLRarityMap.size} achievements (player endpoint fallback)`);
                    }
                  }
                }
              } catch (error) {
                console.error(`[OPENXBL] Failed to fetch rarity data:`, error);
                // Continue without rarity data
              }
            } else {
              console.log(`[OPENXBL] Skipping rarity fetch - last updated within 30 days`);
            }

            // Upsert user_games
            // Update user_progress with game progress
            // Use totalAchievementsFromAPI (the count we actually fetched) since we now paginate and get all achievements
            // title.achievement.totalAchievements from Xbox API can sometimes be 0 or incorrect
            const userGameData = {
              user_id: userId,
              platform_id: platformId,
              platform_game_id: gameTitle.platform_game_id,
              completion_percentage: title.achievement.progressPercentage,
              total_achievements: totalAchievementsFromAPI,
              achievements_earned: title.achievement.currentAchievements,
              current_score: title.achievement.currentGamerscore,
              metadata: {
                current_gamerscore: title.achievement.currentGamerscore, // Store actual Gamerscore for display
                max_gamerscore: title.achievement.totalGamerscore,
                platform_version: platformVersion,
                last_rarity_sync: new Date().toISOString(),
                sync_failed: false,
                sync_error: null,
                last_sync_attempt: new Date().toISOString(),
              },
            };
            
            // Preserve last_achievement_earned_at if it exists (will be updated later after processing achievements)
            if (existingUserGame && existingUserGame.last_achievement_earned_at) {
              userGameData.last_achievement_earned_at = existingUserGame.last_achievement_earned_at;
            }
            
            await supabase
              .from('user_progress')
              .upsert(userGameData, {
                onConflict: 'user_id,platform_id,platform_game_id',
              });

            // Fetch existing achievements to check for valid proxied URLs
            const achievementIds = achievementsForTitle.map(a => a.id);
            const { data: existingAchievements } = await supabase
              .from('achievements')
              .select('platform_achievement_id, proxied_icon_url')
              .eq('platform_id', platformId)
              .eq('platform_game_id', gameTitle.platform_game_id)
              .in('platform_achievement_id', achievementIds);

            const existingProxiedMap = new Map();
            if (existingAchievements) {
              for (const ach of existingAchievements) {
                existingProxiedMap.set(ach.platform_achievement_id, ach.proxied_icon_url);
              }
            }

            // Helper to check if proxied URL is valid (not NULL, not numbered folder, not timestamped, matches achievement ID)
            const isValidProxiedUrl = (url, achievementId) => {
              if (!url) return false;
              if (!url.includes('/avatars/achievement-icons/xbox/')) return false;
              if (/\/avatars\/achievement-icons\/\d+\//.test(url)) return false;
              if (/_\d{13}\.(png|jpg|jpeg|gif|webp)$/i.test(url)) return false;
              // Filename must match achievement ID: ends with /{achievementId}.ext
              const filePattern = new RegExp(`/${achievementId}\\.(png|jpg|jpeg|gif|webp)$`, 'i');
              if (!filePattern.test(url)) return false;
              return true;
            };

            // Process achievements for this title
            let mostRecentAchievementDate = null;
            
            for (const achievement of achievementsForTitle) {
              // Track the most recent achievement earned date
              const earnedAt = achievement.progression?.timeUnlocked || achievement.timeUnlocked || achievement.unlockTime || null;
              if (achievement.progressState === 'Achieved' && earnedAt) {
                const earnedDate = new Date(earnedAt);
                if (!mostRecentAchievementDate || earnedDate > mostRecentAchievementDate) {
                  mostRecentAchievementDate = earnedDate;
                }
              }
              
              // Xbox DLC detection: check if achievement has a category or parent title indicating DLC
              // For now, we'll default to false as Xbox API doesn't clearly separate DLC
              const isDLC = false; // TODO: Xbox API doesn't provide clear DLC indicators
              
              // Get rarity from OpenXBL (falls back to null if not available)
              const rarityPercent = openXBLRarityMap.get(achievement.id) || null;
              
              // Proxy the icon URL through Supabase Storage (check existing first)
              const iconUrl = achievement.mediaAssets?.[0]?.url || achievement.mediaAsset?.url || achievement.mediaAsset || null;
              const existingProxied = existingProxiedMap.get(achievement.id);
              let proxiedIconUrl = null;
              
              if (isValidProxiedUrl(existingProxied, achievement.id)) {
                proxiedIconUrl = existingProxied;
                console.log(`[XBOX SYNC] ✓ Reusing valid proxied URL for ${achievement.id}`);
              } else if (iconUrl) {
                proxiedIconUrl = await uploadExternalIcon(iconUrl, achievement.id, 'xbox', supabase);
              }
              
              // Calculate base_status_xp using EXPONENTIAL CURVE (floor=0.5, cap=12, p=3)
              const includeInScore = true; // All Xbox achievements count
              const rawGamerscore = Number(achievement.rewards?.[0]?.value ?? 0);
              let sanitizedGamerscore = Number.isFinite(rawGamerscore) ? rawGamerscore : 0;
              if (sanitizedGamerscore < 0 || sanitizedGamerscore > 200) {
                sanitizedGamerscore = 0;
              }
              
              let baseStatusXP = 0.5; // Default for NULL rarity (treat as common)
              
              if (rarityPercent !== null && !Number.isNaN(Number(rarityPercent))) {
                const r = Number(rarityPercent);
                const floor = 0.5;
                const cap = 12;
                const p = 3;
                
                // Exponential curve: base = floor + (cap - floor) * (1 - r/100)^p
                const inv = Math.max(0, Math.min(1, 1 - (r / 100)));
                baseStatusXP = floor + (cap - floor) * Math.pow(inv, p);
                
                // Clamp to range
                baseStatusXP = Math.max(floor, Math.min(cap, baseStatusXP));
              }
              
              // Build achievement data object
              const achievementData = {
                platform_id: platformId,
                platform_game_id: gameTitle.platform_game_id,
                platform_achievement_id: achievement.id,
                name: achievement.name,
                description: achievement.description,
                icon_url: iconUrl,
                rarity_global: rarityPercent,
                score_value: sanitizedGamerscore,
                base_status_xp: baseStatusXP,
                is_platinum: false, // Xbox doesn't have platinums
                include_in_score: includeInScore,
                metadata: {
                  gamerscore: sanitizedGamerscore,
                  is_secret: achievement.isSecret || false,
                  platform_version: platformVersion,
                  is_dlc: isDLC,
                  dlc_name: null,
                },
              };

              // Only include proxied_icon_url if upload succeeded
              if (proxiedIconUrl) {
                achievementData.proxied_icon_url = proxiedIconUrl;
              }
              
              // Upsert achievement (race-condition safe)
              const { data: achievementRecord, error: achError } = await supabase
                .from('achievements')
                .upsert(achievementData, {
                  onConflict: 'platform_id,platform_game_id,platform_achievement_id'
                })
                .select()
                .single();

              if (achError || !achievementRecord) {
                console.error(`❌ Failed to upsert achievement ${achievement.name}:`, achError?.message);
                continue;
              }

              // Upsert user_achievement if unlocked
              if (achievement.progressState === 'Achieved') {
                await supabase
                  .from('user_achievements')
                  .upsert({
                    user_id: userId,
                    platform_id: platformId,
                    platform_game_id: gameTitle.platform_game_id,
                    platform_achievement_id: achievementRecord.platform_achievement_id,
                    earned_at: earnedAt,
                  }, {
                    onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
                  });
                
                totalAchievements++;
              }
            }

            // Update user_progress with the most recent achievement earned date
            if (mostRecentAchievementDate) {
              await supabase
                .from('user_progress')
                .update({
                  last_achievement_earned_at: mostRecentAchievementDate.toISOString(),
                })
                .eq('user_id', userId)
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle.platform_game_id);
            }

            processedGames++;
            const progress = Math.floor((processedGames / gamesWithProgress.length) * 100);
            
            // Update progress
            await supabase
              .from('profiles')
              .update({ xbox_sync_progress: progress })
              .eq('id', userId);

            console.log(`Processed ${processedGames}/${gamesWithProgress.length} games (${progress}%)`);
            // Briefly yield to the event loop to reduce temporary memory spikes
            await new Promise((r) => setTimeout(r, 25));
          } catch (error) {
            console.error(`❌ Error processing title ${title.name}:`, error);
            
            // If achievement fetch/processing failed, mark the game with sync_failed flag if we have gameTitle
            // This prevents data inconsistency where user_progress says has achievements but no achievements exist
            if (gameTitle?.platform_game_id && platformId) {
              try {
                const { data: existingGame } = await supabase
                  .from('user_progress')
                  .select('metadata')
                  .eq('user_id', userId)
                  .eq('platform_id', platformId)
                  .eq('platform_game_id', gameTitle.platform_game_id)
                  .single();
                
                await supabase
                  .from('user_progress')
                  .update({
                    metadata: {
                      ...(existingGame?.metadata || {}),
                      sync_failed: true,
                      sync_error: error.message?.substring(0, 255),
                      last_sync_attempt: new Date().toISOString(),
                    }
                  })
                  .eq('user_id', userId)
                  .eq('platform_id', platformId)
                  .eq('platform_game_id', gameTitle.platform_game_id);
              } catch (updateError) {
                console.error('Failed to mark game as sync_failed:', updateError);
              }
            } else {
              console.log(`⚠️ Skipping sync_failed update - game not yet in database (${title.name})`);
            }
            processedGames++;
            const progress = Math.floor((processedGames / gamesWithProgress.length) * 100);
            await supabase
              .from('profiles')
              .update({ xbox_sync_progress: progress })
              .eq('id', userId);
            
            // Continue with next game
          }
        }
      } else {
        // Run with concurrency in parallel chunks
        const worker = async (titlesChunk) => {
          await Promise.all(titlesChunk.map(async (title) => {
            try {
              console.log(`Processing game: ${title.name} (${title.titleId})`);
              // Upsert game + user_games and achievements (same as above)
              const { data: game } = await supabase
                .from('games')
                .upsert({
                  xbox_title_id: title.titleId,
                  title: title.name,
                  platform: 'xbox',
                  image_url: title.displayImage,
                }, {
                  onConflict: 'xbox_title_id',
                })
                .select()
                .single();

              if (!game) { console.log('Upserted game - no result'); return; }

              // Upsert user_games
              await supabase
                .from('user_games')
                .upsert({
                  user_id: userId,
                  game_id: game.id,
                  platform: 'xbox',
                  gamerscore: title.achievement.currentGamerscore,
                  total_gamerscore: title.achievement.totalGamerscore,
                  achievements_unlocked: title.achievement.currentAchievements,
                  total_achievements: title.achievement.totalAchievements,
                  progress: title.achievement.progressPercentage,
                }, {
                  onConflict: 'user_id,game_id',
                });

              // Fetch achievements
              const achievementsResponse = await fetch(
                `https://achievements.xboxlive.com/users/xuid(${xuid})/achievements?titleId=${title.titleId}`,
                {
                  headers: {
                    'x-xbl-contract-version': '2',
                    Authorization: `XBL3.0 x=${userHash};${accessToken}`,
                  },
                }
              );

              const achievementsData = await achievementsResponse.json();

              for (const achievement of achievementsData.achievements) {
                // TODO: Xbox API doesn't clearly separate DLC achievements from base game
                // For now, marking all as base game (is_dlc = false)
                const isDLC = false;
                const dlcName = null;
                const rawGamerscore = Number(achievement.rewards?.[0]?.value ?? 0);
                let sanitizedGamerscore = Number.isFinite(rawGamerscore) ? rawGamerscore : 0;
                if (sanitizedGamerscore < 0 || sanitizedGamerscore > 200) {
                  sanitizedGamerscore = 0;
                }

                const { data: achievementRecord } = await supabase
                  .from('achievements')
                  .upsert({
                    game_id: game.id,
                    xbox_achievement_id: achievement.id,
                    name: achievement.name,
                    description: achievement.description,
                    gamerscore: sanitizedGamerscore,
                    icon_locked_url: achievement.mediaAssets?.[0]?.url,
                    icon_unlocked_url: achievement.mediaAssets?.[0]?.url,
                    is_dlc: isDLC,
                    dlc_name: dlcName,
                  }, {
                    onConflict: 'game_id,xbox_achievement_id',
                  })
                  .select()
                  .single();

                if (!achievementRecord) continue;

                if (achievement.progressState === 'Achieved') {
                  await supabase
                    .from('user_achievements')
                    .upsert({
                      user_id: userId,
                      achievement_id: achievementRecord.id,
                      earned_at: achievement.progression?.timeUnlocked,
                    }, {
                      onConflict: 'user_id,achievement_id',
                    });
                  totalAchievements++;
                }
              }

              processedGames++;
              const progress = Math.floor((processedGames / gamesWithProgress.length) * 100);
              await supabase
                .from('profiles')
                .update({ xbox_sync_progress: progress })
                .eq('id', userId);
            } catch (error) {
              console.error(`Error processing title ${title.name}:`, error);
            }
          }));
        };

        for (let k = 0; k < batch.length; k += MAX_CONCURRENT) {
          const titlesChunk = batch.slice(k, k + MAX_CONCURRENT);
          await worker(titlesChunk);
        }
      // end inner try-catch for title
      }
      // free batch memory
      // eslint-disable-next-line no-unused-vars
      // Note: local 'batch' will be GC'd when out of scope; explicit null helps
      // eslint-disable-next-line no-param-reassign
      // not reassigning but just log
      logMemory(`After processing batch ${i / BATCH_SIZE + 1}`);
    }

    // Refresh StatusXP leaderboard cache (source of truth is user_achievements)
    try {
      await supabase.rpc('refresh_statusxp_leaderboard_for_user', { p_user_id: userId });
      console.log('✅ StatusXP leaderboard refresh complete');
    } catch (refreshError) {
      console.error('⚠️ StatusXP leaderboard refresh failed:', refreshError);
    }

    // Mark as completed with retry logic
    const statusUpdated = await updateSyncStatus(userId, {
      xbox_sync_status: 'success',
      xbox_sync_progress: 100,
      last_xbox_sync_at: new Date().toISOString(),
    });
    
    if (!statusUpdated) {
      console.error('🚨 WARNING: Sync completed but status update failed! User may see stuck sync.');
    }

    await supabase
      .from('xbox_sync_logs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        games_processed: processedGames,
        achievements_synced: totalAchievements,
      })
      .eq('id', syncLogId);

    console.log(`Xbox sync completed: ${processedGames} games, ${totalAchievements} achievements`);

  } catch (error) {
    console.error('Xbox sync failed:', error);
    
    await updateSyncStatus(userId, {
      xbox_sync_status: 'error',
      xbox_sync_progress: 0,
      xbox_sync_error: error.message?.substring(0, 500) || 'Unknown error',
    });

    await supabase
      .from('xbox_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error.message,
      })
      .eq('id', syncLogId);
  }
}
