import { createClient } from '@supabase/supabase-js';

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
    
    // Create a unique filename: platform/userId_timestamp.ext
    const timestamp = Date.now();
    const filename = `${platform}/${userId}_${timestamp}.${extension}`;
    
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

  const xblData = await xblResponse.json();
  console.log('XBL auth response (xblData) keys:', Object.keys(xblData));
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

  const xstsData = await xstsResponse.json();
  console.log('XSTS response status:', xstsResponse.status);
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
  const updateData = {
    xbox_access_token: xstsData.Token,
    xbox_refresh_token: tokenData.refresh_token,
    xbox_xuid: xuid,
    xbox_user_hash: userHash,
    xbox_gamertag: gamertag,
  };
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

    const gamesWithProgress = titleHistory.titles.filter(t => t.achievement?.currentGamerscore > 0);

    console.log(`Found ${gamesWithProgress.length} games with achievements`);
    logMemory('After filtering gamesWithProgress');

    // Load existing user_games to enable cheap diff
    const { data: existingUserGames } = await supabase
      .from('user_games')
      .select('game_title_id, platform_id, xbox_total_achievements, xbox_achievements_earned, last_rarity_sync, sync_failed')
      .eq('user_id', userId);
    
    const userGamesMap = new Map();
    for (const ug of existingUserGames || []) {
      userGamesMap.set(`${ug.game_title_id}_${ug.platform_id}`, ug);
    }
    console.log(`Loaded ${userGamesMap.size} existing user_games for diff check`);

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
        for (const title of batch) {
          try {
            console.log(`Processing game: ${title.name} (${title.titleId})`);
            
            // Get or create Xbox One platform
            const { data: platform, error: platformError } = await supabase
              .from('platforms')
              .select('id')
              .eq('code', 'XBOXONE')
              .single();
            
            if (platformError || !platform) {
              console.error(
                '❌ Platform query failed for XBOXONE:',
                platformError?.message || 'Platform not found'
              );
              console.error(`   Skipping game: ${title.name}`);
              continue;
            }

            console.log(`✅ Platform resolved: XBOXONE → ID ${platform.id}`);
            
            // Search for existing game_title by xbox_title_id using dedicated column
            let gameTitle = null;
            const trimmedName = title.name.trim();
            const { data: existingGame } = await supabase
              .from('game_titles')
              .select('id, name, cover_url, metadata')
              .eq('xbox_title_id', title.titleId)
              .maybeSingle();
            
            if (existingGame) {
              // Update cover if we don't have one
              if (!existingGame.cover_url && title.displayImage) {
                console.log('Attempting to update game_title:', { 
                  name: title.name, 
                  id: existingGame.id, 
                  titleId: title.titleId,
                  hasId: !!existingGame.id 
                });
                const { error: updateError } = await supabase
                  .from('game_titles')
                  .update({ cover_url: title.displayImage })
                  .eq('id', existingGame.id);
                
                if (updateError) {
                  console.error('❌ Failed to update game_title cover:', title.name, 'Error:', updateError);
                  console.error('  - Game ID was:', existingGame.id);
                }
              }
              gameTitle = existingGame;
            } else {
              // Create new game_title with xbox_title_id in dedicated column
              const { data: newGame, error: insertError } = await supabase
                .from('game_titles')
                .insert({
                  name: trimmedName,
                  cover_url: title.displayImage,
                  xbox_title_id: title.titleId,
                  metadata: {
                    xbox_title_id: title.titleId,
                  },
                })
                .select()
                .single();
              
              if (insertError) {
                console.error('❌ Failed to insert game_title:', title.name, 'Error:', insertError);
                continue;
              }
              gameTitle = newGame;
            }

            if (!gameTitle) { console.log('Upserted game_title - no result'); continue; }

            // Cheap diff: Check if game data changed
            const apiTotalAchievements = title.achievement.totalAchievements || 0;
            const apiEarnedAchievements = title.achievement.currentAchievements || 0;
            
            const existingUserGame = userGamesMap.get(`${gameTitle.id}_${platform.id}`);
            const isNewGame = !existingUserGame;
            const countsChanged = existingUserGame && 
              (existingUserGame.xbox_total_achievements !== apiTotalAchievements || 
               existingUserGame.xbox_achievements_earned !== apiEarnedAchievements);
            const syncFailed = existingUserGame && existingUserGame.sync_failed === true;
            
            // Check if rarity is stale (>30 days old)
            let needRarityRefresh = false;
            if (!isNewGame && !countsChanged && !syncFailed && existingUserGame) {
              const lastRaritySync = existingUserGame.last_rarity_sync ? new Date(existingUserGame.last_rarity_sync) : null;
              const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
              needRarityRefresh = !lastRaritySync || lastRaritySync < thirtyDaysAgo;
            }
            
            const needsProcessing = isNewGame || countsChanged || needRarityRefresh || syncFailed;
            
            if (!needsProcessing) {
              console.log(`⏭️  Skip ${title.name} - no changes`);
              processedGames++;
              const progressPercent = Math.floor((processedGames / gamesWithProgress.length) * 100);
              await supabase.from('profiles').update({ xbox_sync_progress: progressPercent }).eq('id', userId);
              continue;
            }
            
            if (needRarityRefresh) {
              console.log(`🔄 RARITY REFRESH: ${title.name} (>30 days since last rarity sync)`);
            }
            
            if (syncFailed) {
              console.log(`🔄 RETRY FAILED SYNC: ${title.name} (previous sync failed)`);
            }

            // Log the achievement data from Xbox API
            console.log(`[XBOX ACHIEVEMENTS] ${title.name}: currentAchievements=${title.achievement.currentAchievements}, totalAchievements=${title.achievement.totalAchievements}, currentGamerscore=${title.achievement.currentGamerscore}, totalGamerscore=${title.achievement.totalGamerscore}`);

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

            const totalAchievementsFromAPI = achievementsForTitle.length;
            console.log(`[XBOX ACHIEVEMENTS] ${title.name}: Fetched total of ${totalAchievementsFromAPI} achievements across ${pageCount} pages`);

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
                  const rarityResponse = await fetch(
                    `https://xbl.io/api/v2/achievements/player/${xuid}/${title.titleId}`,
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
                    console.log(`[OPENXBL] Fetched rarity for ${openXBLRarityMap.size} achievements`);
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
            // Use totalAchievementsFromAPI (the count we actually fetched) since we now paginate and get all achievements
            // title.achievement.totalAchievements from Xbox API can sometimes be 0 or incorrect
            const userGameData = {
              user_id: userId,
              game_title_id: gameTitle.id,
              platform_id: platform.id,
              total_trophies: totalAchievementsFromAPI,
              earned_trophies: title.achievement.currentAchievements,
              completion_percent: title.achievement.progressPercentage,
              xbox_current_gamerscore: title.achievement.currentGamerscore,
              xbox_max_gamerscore: title.achievement.totalGamerscore,
              xbox_achievements_earned: title.achievement.currentAchievements,
              xbox_total_achievements: totalAchievementsFromAPI,
              xbox_last_updated_at: new Date().toISOString(),
              sync_failed: false,
              sync_error: null,
              last_sync_attempt: new Date().toISOString(),
            };
            
            // Preserve last_trophy_earned_at if it exists (will be updated later after processing achievements)
            if (existingUserGame && existingUserGame.last_trophy_earned_at) {
              userGameData.last_trophy_earned_at = existingUserGame.last_trophy_earned_at;
            }
            
            await supabase
              .from('user_games')
              .upsert(userGameData, {
                onConflict: 'user_id,game_title_id,platform_id',
              });

            // Process achievements for this title
            let mostRecentAchievementDate = null;
            
            for (const achievement of achievementsForTitle) {
              // Track the most recent achievement earned date
              if (achievement.progressState === 'Achieved' && achievement.progression?.timeUnlocked) {
                const earnedDate = new Date(achievement.progression.timeUnlocked);
                if (!mostRecentAchievementDate || earnedDate > mostRecentAchievementDate) {
                  mostRecentAchievementDate = earnedDate;
                }
              }
              
              // Xbox DLC detection: check if achievement has a category or parent title indicating DLC
              // For now, we'll default to false as Xbox API doesn't clearly separate DLC
              const isDLC = false; // TODO: Xbox API doesn't provide clear DLC indicators
              
              // Get rarity from OpenXBL (falls back to null if not available)
              const rarityPercent = openXBLRarityMap.get(achievement.id) || null;
              
              // Build upsert object
              const achievementUpsert = {
                game_title_id: gameTitle.id,
                platform: 'xbox',
                platform_version: 'XBOXONE',
                platform_achievement_id: achievement.id,
                name: achievement.name,
                description: achievement.description,
                icon_url: achievement.mediaAssets?.[0]?.url,
                xbox_gamerscore: achievement.rewards?.[0]?.value || 0,
                xbox_is_secret: achievement.isSecret || false,
                is_platinum: false, // Xbox doesn't have platinums
                is_dlc: isDLC,
                dlc_name: null,
              };

              // Only update rarity if we fetched new data
              if (needsRarityUpdate && rarityPercent !== null) {
                achievementUpsert.rarity_global = rarityPercent;
                achievementUpsert.rarity_last_updated_at = new Date().toISOString();
              }
              
              // Check if achievement exists
              const { data: existing } = await supabase
                .from('achievements')
                .select('id')
                .eq('game_title_id', title.gameTitleId)
                .eq('platform', 'xbox')
                .eq('platform_achievement_id', achievement.id)
                .maybeSingle();

              let achievementRecord;
              if (existing) {
                // Update existing
                const { data } = await supabase
                  .from('achievements')
                  .update(achievementUpsert)
                  .eq('id', existing.id)
                  .select()
                  .single();
                achievementRecord = data;
              } else {
                // Insert new
                const { data } = await supabase
                  .from('achievements')
                  .insert(achievementUpsert)
                  .select()
                  .single();
                achievementRecord = data;
              }

              if (!achievementRecord) continue;

              // Upsert user_achievement if unlocked
              if (achievement.progressState === 'Achieved') {
                // SAFETY: Xbox should never have platinums
                if (achievementRecord.is_platinum) {
                  console.log(`⚠️ [VALIDATION BLOCKED] Xbox achievement marked as platinum: ${achievement.name}`);
                  continue;
                }

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

            // Update user_games with the most recent achievement earned date
            if (mostRecentAchievementDate) {
              await supabase
                .from('user_games')
                .update({
                  last_trophy_earned_at: mostRecentAchievementDate.toISOString(),
                })
                .eq('user_id', userId)
                .eq('game_title_id', gameTitle.id)
                .eq('platform_id', platform.id);
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
            console.error(`Error processing title ${title.name}:`, error);
            
            // Mark sync as failed for this game
            try {
              await supabase
                .from('user_games')
                .update({
                  sync_failed: true,
                  sync_error: (error.message || String(error)).substring(0, 255),
                  last_sync_attempt: new Date().toISOString(),
                })
                .eq('user_id', userId)
                .eq('game_title_id', gameTitle?.id)
                .eq('platform_id', platform?.id);
            } catch (updateErr) {
              console.error('Failed to mark sync_failed:', updateErr);
            }
            
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

                const { data: achievementRecord } = await supabase
                  .from('achievements')
                  .upsert({
                    game_id: game.id,
                    xbox_achievement_id: achievement.id,
                    name: achievement.name,
                    description: achievement.description,
                    gamerscore: achievement.rewards?.[0]?.value || 0,
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

    // Calculate StatusXP for all achievements and games
    console.log('Calculating StatusXP values...');
    try {
      await supabase.rpc('calculate_user_achievement_statusxp');
      await supabase.rpc('calculate_user_game_statusxp');
      console.log('✅ StatusXP calculation complete');
    } catch (calcError) {
      console.error('⚠️ StatusXP calculation failed:', calcError);
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
