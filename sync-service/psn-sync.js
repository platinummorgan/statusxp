// Force redeploy after optimization fix - Dec 7, 2025
import { createClient } from '@supabase/supabase-js';
import { uploadExternalIcon } from './icon-proxy-utils.js';
import { initIGDBValidator, getIGDBValidator } from './igdb-validator.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const ENV_BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '20', 10);
const ENV_MAX_CONCURRENT = parseInt(process.env.MAX_CONCURRENT || '3', 10);

function logMemory(label) {
  try {
    const m = process.memoryUsage();
    console.log(
      label,
      `rss=${Math.round(m.rss / 1024 / 1024)}MB`,
      `heapUsed=${Math.round(m.heapUsed / 1024 / 1024)}MB`,
      `heapTotal=${Math.round(m.heapTotal / 1024 / 1024)}MB`,
      `external=${Math.round(m.external / 1024 / 1024)}MB`
    );
  } catch (e) {
    console.log('logMemory error', e.message);
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
        await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
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

// Cheap diff check: DB snapshot vs API snapshot
export async function syncPSNAchievements(
  userId,
  accountId,
  accessToken,
  refreshToken,
  syncLogId,
  options = {}
) {
  console.log(`Starting PSN sync for user ${userId}`);

  // Initialize IGDB validator for platform validation
  try {
    await initIGDBValidator();
    console.log('✅ IGDB validator initialized');
  } catch (igdbError) {
    console.warn('⚠️  IGDB validator initialization failed, will use API-only detection:', igdbError.message);
  }

  // CRITICAL: Validate profile exists before starting sync
  const { data: profileValidation, error: profileError } = await supabase
    .from('profiles')
    .select('id, psn_account_id')
    .eq('id', userId)
    .maybeSingle();
  
  if (profileError) {
    const errorMsg = `Profile lookup failed: ${profileError.message}`;
    console.error('🚨 FATAL:', errorMsg);
    await supabase
      .from('psn_sync_logs')
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
      .from('psn_sync_logs')
      .update({ 
        status: 'failed', 
        error_message: errorMsg,
        completed_at: new Date().toISOString()
      })
      .eq('id', syncLogId);
    throw new Error(errorMsg);
  }

  console.log(`✅ Profile validated for user ${userId}`);

  const psnModule = await import('psn-api');
  const psnApi = psnModule.default ?? psnModule;
  const { getUserTitles, getTitleTrophies, getUserTrophiesEarnedForTitle, exchangeRefreshTokenForAuthTokens, getProfileFromAccountId } =
    psnApi;

  try {
    console.log('Refreshing PSN access token...');
    const authTokens = await exchangeRefreshTokenForAuthTokens(refreshToken);
    let currentAccessToken = authTokens.accessToken;
    let currentRefreshToken = authTokens.refreshToken;
    console.log('PSN access token refreshed successfully');

    // Fetch user profile to ensure psn_online_id is set
    console.log('Fetching PSN user profile...');
    try {
      const userProfile = await getProfileFromAccountId({ accessToken: currentAccessToken }, accountId);
      console.log(`PSN profile fetched: ${userProfile.onlineId}`);
      
      // Get current profile to check display_name and preferred_display_platform
      const { data: currentProfile } = await supabase
        .from('profiles')
        .select('display_name, preferred_display_platform')
        .eq('id', userId)
        .single();
      
      const updates = {
        psn_online_id: userProfile.onlineId,
        psn_account_id: accountId,
      };
      
      // If display_name is missing or should use PSN name, update it
      if (!currentProfile?.display_name || currentProfile.preferred_display_platform === 'psn') {
        updates.display_name = userProfile.onlineId;
      }
      
      await supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId);
      console.log('✅ PSN profile info updated');
    } catch (profileError) {
      console.error('⚠️ Failed to fetch PSN profile, continuing with sync:', profileError.message);
    }

    await updateSyncStatus(userId, {
      psn_access_token: authTokens.accessToken,
      psn_refresh_token: authTokens.refreshToken,
      psn_sync_status: 'syncing',
      psn_sync_progress: 0,
    });

    await supabase
      .from('psn_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    console.log('Fetching PSN titles for accountId:', accountId);
    // Paginate through ALL titles (max 800 per request)
    let allTitles = [];
    let offset = 0;
    const limit = 800;
    let hasMore = true;

    console.log('Starting to fetch ALL PSN titles with pagination...');
    
    while (hasMore) {
      console.log(`Fetching titles with offset ${offset}, limit ${limit}`);
      
      try {
        const titles = await getUserTitles(
          { accessToken: currentAccessToken },
          accountId,
          { limit, offset }
        );
        
        // Log the raw API response for debugging
        console.log('PSN API Response:', JSON.stringify(titles).substring(0, 500));
        
        const fetchedCount = titles?.trophyTitles?.length ?? 0;
        console.log(`Fetched ${fetchedCount} titles in this batch`);
        
        if (fetchedCount > 0) {
          allTitles = allTitles.concat(titles.trophyTitles);
          offset += fetchedCount;
          
          // If we got fewer titles than the limit, we've reached the end
          hasMore = fetchedCount === limit;
        } else {
          // Check if this is an error condition vs actually no games
          if (offset === 0 && titles && Object.keys(titles).length > 0) {
            console.error('🚨 PSN API returned response but no trophyTitles array!');
            console.error('Response keys:', Object.keys(titles));
          }
          hasMore = false;
        }
      } catch (apiError) {
        console.error('❌ PSN API call failed:', apiError);
        throw new Error(`Failed to fetch PSN titles: ${apiError.message}`);
      }
    }

    console.log(`Total PSN titles fetched: ${allTitles.length}`);

    if (!allTitles || allTitles.length === 0) {
      console.log('No PSN titles found - checking if this is expected...');
      
      // Check if user previously had games - if so, 0 titles is an error
      const { count: existingGamesCount, error: countError } = await supabase
        .from('user_progress')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('platform_id', 1); // PSN platform_id
      
      if ((existingGamesCount || 0) > 0) {
        throw new Error(`PSN API returned 0 titles but user has ${existingGamesCount} existing games. This is likely an API error.`);
      }
      
      console.log('User has no existing games - marking sync as success with 0 games');
      await updateSyncStatus(userId, {
        psn_sync_status: 'success',
        psn_sync_progress: 100,
        last_psn_sync_at: new Date().toISOString(),
      });

      await supabase
        .from('psn_sync_logs')
        .update({
          status: 'completed',
          completed_at: new Date().toISOString(),
          games_processed: 0,
          trophies_synced: 0,
        })
        .eq('id', syncLogId);
      return;
    }

    // Sync ALL games with any trophy progress (including platinum-only games)
    const gamesWithTrophies = allTitles.filter(
      (title) => title.progress > 0
    );

    console.log(`Found ${gamesWithTrophies.length} games with progress`);
    logMemory('After filtering gamesWithTrophies');

    // V2 Schema: Each PlayStation version has its own platform_id
    // PS5=1, PS4=2, PS3=5, PSVITA=9
    console.log('PSN sync: PS5=1, PS4=2, PS3=5, PSVITA=9');

    // Load ALL user_progress ONCE for fast lookup (across all PSN platforms)
    console.log('Loading all user_progress for comparison...');
    const { data: allUserGames } = await supabase
      .from('user_progress')
      .select('platform_game_id, platform_id, achievements_earned, total_achievements, completion_percent, last_rarity_sync, sync_failed')
      .eq('user_id', userId)
      .in('platform_id', [1, 2, 5, 9]); // All PSN platforms
    
    const userGamesMap = new Map();
    (allUserGames || []).forEach(ug => {
      userGamesMap.set(`${ug.platform_game_id}_${ug.platform_id}`, ug);
    });
    console.log(`Loaded ${userGamesMap.size} existing user_progress records into memory`);

    let processedGames = 0;
    let totalTrophies = 0;

    const BATCH_SIZE = parseInt(options.batchSize, 10) || ENV_BATCH_SIZE;
    const MAX_CONCURRENT =
      parseInt(options.maxConcurrent, 10) || ENV_MAX_CONCURRENT;
    console.log(`Using BATCH_SIZE=${BATCH_SIZE}, MAX_CONCURRENT=${MAX_CONCURRENT}`);

    for (let i = 0; i < gamesWithTrophies.length; i += BATCH_SIZE) {
      // Refresh token every 100 games to prevent expiration on large libraries
      if (i > 0 && i % 100 === 0) {
        console.log('🔄 Refreshing PSN access token after 100 games...');
        try {
          const authTokens = await exchangeRefreshTokenForAuthTokens(currentRefreshToken);
          currentAccessToken = authTokens.accessToken;
          currentRefreshToken = authTokens.refreshToken;
          console.log('✅ PSN access token refreshed successfully');
          
          await supabase
            .from('profiles')
            .update({
              psn_access_token: authTokens.accessToken,
              psn_refresh_token: authTokens.refreshToken,
            })
            .eq('id', userId);
        } catch (refreshError) {
          console.error('❌ Failed to refresh token:', refreshError);
          throw new Error('Token refresh failed during sync');
        }
      }
      
      // Check if sync was cancelled
      const { data: profileCheck, error: profileCheckError } = await supabase
        .from('profiles')
        .select('psn_sync_status')
        .eq('id', userId)
        .maybeSingle();
      
      if (profileCheckError) {
        console.error('❌ Profile check failed:', profileCheckError);
        throw new Error(`Profile lookup failed: ${profileCheckError.message}`);
      }
      
      if (profileCheck?.psn_sync_status === 'cancelling') {
        console.log('PSN sync cancelled by user');
        await updateSyncStatus(userId, { 
          psn_sync_status: 'stopped',
          psn_sync_progress: 0 
        });
        
        await supabase
          .from('psn_sync_logs')
          .update({ status: 'cancelled', error: 'Cancelled by user' })
          .eq('id', syncLogId);
        
        return;
      }
      
      const batch = gamesWithTrophies.slice(i, i + BATCH_SIZE);
      logMemory(`Before processing PSN batch ${i / BATCH_SIZE + 1}`);

      const processTitle = async (title) => {
        let gameTitle;
        
        try {
          // Detect platform version and map to platform_id
          // PS5=1, PS4=2, PS3=5, PSVITA=9
          let platformVersion = 'PS5';
          let platformId = 1; // Default PS5
          
          if (title.trophyTitlePlatform) {
            const psnPlatform = title.trophyTitlePlatform.toUpperCase();
            if (psnPlatform.includes('PS5')) {
              platformVersion = 'PS5';
              platformId = 1;
            } else if (psnPlatform.includes('PS4')) {
              platformVersion = 'PS4';
              platformId = 2;
            } else if (psnPlatform.includes('PS3')) {
              platformVersion = 'PS3';
              platformId = 5;
            } else if (psnPlatform.includes('VITA')) {
              platformVersion = 'PSVITA';
              platformId = 9;
            }
          }

          console.log(`📱 Platform detected: ${title.trophyTitlePlatform} → ${platformVersion} (ID ${platformId})`);

          // Find or create game using unique PSN npCommunicationId
          const trimmedTitle = title.trophyTitleName.trim();
          
          // 🎮 IGDB VALIDATION: Check authoritative platform data before proceeding
          try {
            const validator = getIGDBValidator();
            if (validator) {
              const validatedPlatformId = await validator.validatePlatform(trimmedTitle, platformId);
              if (validatedPlatformId && validatedPlatformId !== platformId) {
                const platformNames = { 1: 'PS5', 2: 'PS4', 5: 'PS3', 9: 'PSVITA' };
                console.log(`🔧 IGDB Override: ${trimmedTitle} detected as ${platformNames[platformId]} but IGDB says ${platformNames[validatedPlatformId]} - using IGDB data`);
                platformId = validatedPlatformId;
                platformVersion = platformNames[validatedPlatformId];
              } else if (validatedPlatformId) {
                console.log(`✅ IGDB Confirmed: ${trimmedTitle} is correctly ${platformVersion}`);
              }
            }
          } catch (igdbError) {
            console.warn(`⚠️  IGDB validation failed for ${trimmedTitle}, falling back to API detection:`, igdbError.message);
          }
          
          // 🔍 BACKWARDS COMPATIBILITY CHECK: See if this game_id exists on older platform
          // PS4 games played on PS5 should stay as PS4 games
          if (platformId === 1) { // If detected as PS5
            const { data: ps4Version } = await supabase
              .from('games')
              .select('platform_id, platform_game_id')
              .eq('platform_id', 2) // Check PS4
              .eq('platform_game_id', title.npCommunicationId)
              .maybeSingle();
            
            if (ps4Version) {
              console.log(`⚠️  Backwards compat detected: ${trimmedTitle} exists on PS4, using PS4 platform instead of PS5`);
              platformId = 2; // Override to PS4
              platformVersion = 'PS4';
            }
          }
          
          // First try to find by PSN npCommunicationId (platform_game_id)
          const { data: existingGameById } = await supabase
            .from('games')
            .select('platform_game_id, cover_url, metadata')
            .eq('platform_id', platformId)
            .eq('platform_game_id', title.npCommunicationId)
            .maybeSingle();
          
          if (existingGameById) {
            // Found by composite key - this is the exact game
            if (!existingGameById.cover_url && title.trophyTitleIconUrl) {
              console.log('Attempting to update PSN game:', { 
                name: title.trophyTitleName, 
                platform_game_id: existingGameById.platform_game_id, 
                npwr: title.npCommunicationId
              });
              const { error: updateError } = await supabase
                .from('games')
                .update({ cover_url: title.trophyTitleIconUrl })
                .eq('platform_id', platformId)
                .eq('platform_game_id', existingGameById.platform_game_id);
              
              if (updateError) {
                console.error('❌ Failed to update game cover:', title.trophyTitleName, 'Error:', updateError);
                console.error('  - Platform Game ID was:', existingGameById.platform_game_id);
              }
            }
            gameTitle = existingGameById;
          } else {
            // Not found - create new game with V2 composite key
            const { data: newGame, error: insertError } = await supabase
              .from('games')
              .insert({
                platform_id: platformId,
                platform_game_id: title.npCommunicationId,
                name: trimmedTitle,
                cover_url: title.trophyTitleIconUrl,
                metadata: { 
                  psn_np_communication_id: title.npCommunicationId,
                  platform_version: platformVersion
                },
              })
              .select()
              .single();

            if (insertError) {
              console.error(
                '❌ Failed to insert game_title:',
                title.trophyTitleName,
                'Error:',
                insertError
              );
              return;
            }
            gameTitle = newGame;
          }

          if (!gameTitle) return;

          // API snapshot
          const defined = title.definedTrophies || {};
          const earned = title.earnedTrophies || {};
          const apiTotalTrophies =
            (defined.bronze || 0) +
            (defined.silver || 0) +
            (defined.gold || 0) +
            (defined.platinum || 0);
          const apiEarnedTrophies =
            (earned.bronze || 0) +
            (earned.silver || 0) +
            (earned.gold || 0) +
            (earned.platinum || 0);
          const apiProgress = Number(title.progress || 0);

          // Simple lookup - is this game new or changed?
          const existingUserGame = userGamesMap.get(`${gameTitle.platform_game_id}_${platformId}`);
          const isNewGame = !existingUserGame;
          const earnedChanged = existingUserGame && existingUserGame.achievements_earned !== apiEarnedTrophies;
          const syncFailed = existingUserGame && existingUserGame.sync_failed === true;
          
          // Check if rarity is stale (>30 days old)
          let needRarityRefresh = false;
          if (!isNewGame && !earnedChanged && !syncFailed && existingUserGame) {
            const lastRaritySync = existingUserGame.last_rarity_sync ? new Date(existingUserGame.last_rarity_sync) : null;
            const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
            needRarityRefresh = !lastRaritySync || lastRaritySync < thirtyDaysAgo;
          }
          
          // CRITICAL: Check if achievements are missing from user_achievements table
          let missingAchievements = false;
          if (!isNewGame && !earnedChanged && !syncFailed && apiEarnedTrophies > 0) {
            try {
              const { count: gameAchievementsCount } = await supabase
                .from('achievements')
                .select('*', { count: 'exact', head: true })
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle.platform_game_id);
              
              if (gameAchievementsCount && gameAchievementsCount > 0) {
                const { count: existingAchievementsCount } = await supabase
                  .from('user_achievements')
                  .select('*', { count: 'exact', head: true })
                  .eq('user_id', userId)
                  .eq('platform_id', platformId)
                  .eq('platform_game_id', gameTitle.platform_game_id);

                if (existingAchievementsCount === 0 || existingAchievementsCount < apiEarnedTrophies) {
                  missingAchievements = true;
                  console.log(`🔍 MISSING ACHIEVEMENTS: ${title.trophyTitleName} (DB: ${existingAchievementsCount}, API: ${apiEarnedTrophies})`);
                }
              }
            } catch (checkError) {
              console.error(`⚠️ Error checking missing achievements for ${title.trophyTitleName}:`, checkError);
              // Continue without the check - don't break the sync
            }
          }
          
          const needTrophies = isNewGame || earnedChanged || needRarityRefresh || syncFailed || missingAchievements;

          if (!needTrophies) {
            console.log(`⏭️  Skip ${title.trophyTitleName} - no changes`);
            processedGames++;
            const progress = Math.floor((processedGames / gamesWithTrophies.length) * 100);
            await supabase.from('profiles').update({ psn_sync_progress: progress }).eq('id', userId);
            return;
          }
          
          if (needRarityRefresh) {
            console.log(`🔄 RARITY REFRESH: ${title.trophyTitleName} (>30 days since last rarity sync)`);
          }
          
          if (syncFailed) {
            console.log(`🔄 RETRY FAILED SYNC: ${title.trophyTitleName} (previous sync failed)`);
          }

          console.log(`🔄 ${isNewGame ? 'NEW' : 'UPDATED'}: ${title.trophyTitleName} (earned: ${apiEarnedTrophies})`);

          console.log(`🔄 Fetching trophy details (with rarity) for ${title.trophyTitleName}`);
          
          // Fetch trophy metadata (names, descriptions, icons)
          const trophyMetadata = await getTitleTrophies(
            { accessToken: currentAccessToken },
            title.npCommunicationId,
            'all',
            { npServiceName: title.npServiceName }
          );
          
          // Fetch user trophy data (earned status + RARITY)
          const userTrophyData = await getUserTrophiesEarnedForTitle(
            { accessToken: currentAccessToken },
            accountId,
            title.npCommunicationId,
            'all',
            { npServiceName: title.npServiceName }
          );
          
          console.log(
            'Fetched trophies count:',
            trophyMetadata?.trophies?.length ?? 0,
            'with rarity data:',
            userTrophyData?.trophies?.length ?? 0
          );

          if (!trophyMetadata?.trophies || trophyMetadata.trophies.length === 0) {
            console.error(`❌ Failed to fetch trophies for ${title.trophyTitleName} - skipping user_progress update to prevent data inconsistency`);
            processedGames++;
            const progress = Math.floor(
              (processedGames / gamesWithTrophies.length) * 100
            );
            await supabase
              .from('profiles')
              .update({ psn_sync_progress: progress })
              .eq('id', userId);
            return;
          }

          // Now that we successfully fetched trophy data, update user_progress
          const userGameData = {
            user_id: userId,
            platform_id: platformId,
            platform_game_id: gameTitle.platform_game_id,
            completion_percent: apiProgress,
            total_achievements: apiTotalTrophies,
            achievements_earned: apiEarnedTrophies,
            last_rarity_sync: new Date().toISOString(),
            metadata: {
              bronze_trophies: earned.bronze || 0,
              silver_trophies: earned.silver || 0,
              gold_trophies: earned.gold || 0,
              platinum_trophies: earned.platinum || 0,
              has_platinum: (earned.platinum || 0) > 0,
            },
            last_played_at: title.lastUpdatedDateTime,
            sync_failed: false,
            sync_error: null,
            last_sync_attempt: new Date().toISOString(),
          };
          
          // Preserve last_achievement_earned_at if it exists (will be updated later after processing trophies)
          if (existingUserGame && existingUserGame.last_achievement_earned_at) {
            userGameData.last_achievement_earned_at = existingUserGame.last_achievement_earned_at;
          }
          
          await supabase
            .from('user_progress')
            .upsert(userGameData, { onConflict: 'user_id,platform_id,platform_game_id' });

          // Create a map of user trophy data by trophyId for easy lookup
          const userTrophyMap = new Map();
          let mostRecentTrophyDate = null;
          
          for (const userTrophy of (userTrophyData?.trophies || [])) {
            userTrophyMap.set(userTrophy.trophyId, userTrophy);
            
            // Track the most recent trophy earned date
            if (userTrophy?.earned && userTrophy?.earnedDateTime) {
              const earnedDate = new Date(userTrophy.earnedDateTime);
              if (!mostRecentTrophyDate || earnedDate > mostRecentTrophyDate) {
                mostRecentTrophyDate = earnedDate;
              }
            }
          }

          // TODO OPTIMIZATION: This trophy processing loop is N+1 (2-3 DB calls per trophy)
          // Should batch upsert achievements with unique constraint on (platform_id, platform_game_id, platform_achievement_id)
          // Then batch upsert user_achievements. This is the #1 performance bottleneck.
          // Current approach: 200 trophies = 400-600 DB calls. Batch approach: 200 trophies = 2 DB calls.
          for (const trophyMeta of trophyMetadata.trophies) {
            const userTrophy = userTrophyMap.get(trophyMeta.trophyId);
            
            // Debug: Log full trophy object structure for first game
            if (processedGames === 0 && trophyMetadata.trophies.indexOf(trophyMeta) === 0) {
              console.log(`[DEBUG] Trophy metadata:`, JSON.stringify(trophyMeta, null, 2));
              console.log(`[DEBUG] User trophy data:`, JSON.stringify(userTrophy, null, 2));
            }

            const isDLC =
              trophyMeta.trophyGroupId && trophyMeta.trophyGroupId !== 'default';
            const dlcName = isDLC ? `DLC Group ${trophyMeta.trophyGroupId}` : null;
            const rarityPercent = userTrophy?.trophyEarnedRate
              ? parseFloat(userTrophy.trophyEarnedRate)
              : null;

            if (rarityPercent !== null && rarityPercent > 0) {
              console.log(
                `[PSN RARITY] ${trophyMeta.trophyName}: ${rarityPercent}%`
              );
            } else {
              // Only log debug for first few trophies to avoid spam
              if (processedGames < 2 && trophyMetadata.trophies.indexOf(trophyMeta) < 5) {
                console.log(
                  `[PSN RARITY DEBUG] ${trophyMeta.trophyName}: trophyEarnedRate=${userTrophy?.trophyEarnedRate}, parsed=${rarityPercent}`
                );
              }
            }

            // Proxy the icon URL through Supabase Storage
            const proxiedIconUrl = await uploadExternalIcon(
              trophyMeta.trophyIconUrl,
              trophyMeta.trophyId.toString(),
              'psn',
              supabase
            );

            // Calculate base_status_xp and rarity_multiplier from rarity_global
            const isPlatinum = trophyMeta.trophyType === 'platinum';
            const includeInScore = !isPlatinum;
            
            let baseStatusXP = 0.5; // Default for common (>25%)
            let rarityMultiplier = 1.00;
            
            if (!includeInScore) {
              baseStatusXP = 0; // Platinum trophies don't count
            } else if (rarityPercent !== null) {
              if (rarityPercent > 25) {
                baseStatusXP = 0.5;  // Common: 0.5 × 1.00 = 0.50
                rarityMultiplier = 1.00;
              } else if (rarityPercent > 10) {
                baseStatusXP = 0.7;  // Uncommon: 0.7 × 1.25 = 0.875
                rarityMultiplier = 1.25;
              } else if (rarityPercent > 5) {
                baseStatusXP = 0.9;  // Rare: 0.9 × 1.75 = 1.575
                rarityMultiplier = 1.75;
              } else if (rarityPercent > 1) {
                baseStatusXP = 1.2;  // Very Rare: 1.2 × 2.25 = 2.70
                rarityMultiplier = 2.25;
              } else {
                baseStatusXP = 1.5;  // Ultra Rare: 1.5 × 3.00 = 4.50
                rarityMultiplier = 3.00;
              }
            }

            const achievementData = {
              platform_id: platformId,
              platform_game_id: gameTitle.platform_game_id,
              platform_achievement_id: trophyMeta.trophyId.toString(),
              name: trophyMeta.trophyName,
              description: trophyMeta.trophyDetail,
              icon_url: trophyMeta.trophyIconUrl,
              rarity_global: rarityPercent,
              base_status_xp: baseStatusXP,
              rarity_multiplier: rarityMultiplier,
              is_platinum: isPlatinum,
              include_in_score: includeInScore,
              metadata: {
                psn_trophy_type: trophyMeta.trophyType, // FIXED: was trophy_type, must be psn_trophy_type
                platform_version: platformVersion, // PS3, PS4, PS5, PSVITA
                is_dlc: isDLC,
                dlc_name: dlcName,
                is_platinum: isPlatinum, // Add is_platinum to metadata too
                steam_hidden: false, // PSN doesn't have hidden trophies
                xbox_is_secret: false, // PSN doesn't use Xbox secret flag
              },
            };

            // Only include proxied_icon_url if upload succeeded
            if (proxiedIconUrl) {
              achievementData.proxied_icon_url = proxiedIconUrl;
            }

            // Check if achievement exists
            const { data: existing } = await supabase
              .from('achievements')
              .select('platform_achievement_id, proxied_icon_url')
              .eq('platform_id', platformId)
              .eq('platform_game_id', gameTitle.platform_game_id)
              .eq('platform_achievement_id', trophyMeta.trophyId.toString())
              .maybeSingle();

            let achievementRecord;
            if (existing) {
              // Update existing
              const { data } = await supabase
                .from('achievements')
                .update(achievementData)
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle.platform_game_id)
                .eq('platform_achievement_id', trophyMeta.trophyId.toString())
                .select()
                .single();
              achievementRecord = data;
            } else {
              // Insert new
              const { data } = await supabase
                .from('achievements')
                .insert(achievementData)
                .select()
                .single();
              achievementRecord = data;
            }

            if (!achievementRecord) continue;

            if (userTrophy?.earned) {
              // Trust the individual trophy earned status from PSN API
              // The summary counts can be inaccurate, so we don't validate against them
              await supabase
                .from('user_achievements')
                .upsert(
                  {
                    user_id: userId,
                    platform_id: platformId,
                    platform_game_id: gameTitle.platform_game_id,
                    platform_achievement_id: achievementRecord.platform_achievement_id,
                    earned_at: userTrophy.earnedDateTime,
                  },
                  {
                    onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
                  }
                );

              totalTrophies++;
            }
          }

          // Update user_progress with the most recent trophy earned date
          if (mostRecentTrophyDate) {
            await supabase
              .from('user_progress')
              .update({
                last_achievement_earned_at: mostRecentTrophyDate.toISOString(),
              })
              .eq('user_id', userId)
              .eq('platform_id', platformId)
              .eq('platform_game_id', gameTitle.platform_game_id);
          }

          processedGames++;
          const progress = Math.floor(
            (processedGames / gamesWithTrophies.length) * 100
          );
          await supabase
            .from('profiles')
            .update({ psn_sync_progress: progress })
            .eq('id', userId);

          console.log(
            `Processed ${processedGames}/${gamesWithTrophies.length} games (${progress}%)`
          );
          await new Promise((r) => setTimeout(r, 10));
        } catch (error) {
          console.error(`❌ Error processing title ${title.trophyTitleName}:`, error);
          
          // If trophy fetch/processing failed, mark the game with sync_failed flag if we have gameTitle
          // This prevents data inconsistency where user_progress says has_platinum but no achievements exist
          if (gameTitle?.platform_game_id && platformId) {
            try {
              await supabase
                .from('user_progress')
                .update({
                  sync_failed: true,
                  sync_error: error.message?.substring(0, 255),
                  last_sync_attempt: new Date().toISOString(),
                })
                .eq('user_id', userId)
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle.platform_game_id);
            } catch (updateError) {
              console.error('Failed to mark game as sync_failed:', updateError);
            }
          } else {
            console.log(`⚠️ Skipping sync_failed update - game not yet in database (${title.trophyTitleName})`);
          }
        }
      };

      if (MAX_CONCURRENT <= 1) {
        // sequential
        for (let batchIndex = 0; batchIndex < batch.length; batchIndex++) {
          const title = batch[batchIndex];
          
          // Check for cancellation every 5 games within batch
          if (batchIndex > 0 && batchIndex % 5 === 0) {
            const { data: cancelCheck } = await supabase
              .from('profiles')
              .select('psn_sync_status')
              .eq('id', userId)
              .maybeSingle();
            
            if (cancelCheck?.psn_sync_status === 'cancelling') {
              console.log('PSN sync cancelled by user (mid-batch)');
              await supabase
                .from('profiles')
                .update({ 
                  psn_sync_status: 'stopped',
                  psn_sync_progress: 0 
                })
                .eq('id', userId);
              
              await supabase
                .from('psn_sync_logs')
                .update({ status: 'cancelled', error: 'Cancelled by user' })
                .eq('id', syncLogId);
              
              return;
            }
          }
          
          await processTitle(title);
        }
      } else {
        // chunked concurrency
        for (let k = 0; k < batch.length; k += MAX_CONCURRENT) {
          const chunk = batch.slice(k, k + MAX_CONCURRENT);
          await Promise.all(chunk.map((t) => processTitle(t)));
        }
      }

      logMemory(`After processing PSN batch ${i / BATCH_SIZE + 1}`);
    }

    // Calculate StatusXP for all achievements and games
    console.log('Calculating StatusXP values...');
    try {
      await supabase.rpc('refresh_statusxp_leaderboard');
      console.log('✅ StatusXP calculation complete');
    } catch (calcError) {
      console.error('⚠️ StatusXP calculation failed:', calcError);
    }

    const statusUpdated = await updateSyncStatus(userId, {
      psn_sync_status: 'success',
      psn_sync_progress: 100,
      last_psn_sync_at: new Date().toISOString(),
    });
    
    if (!statusUpdated) {
      console.error('🚨 WARNING: Sync completed but status update failed! User may see stuck sync.');
    }

    await supabase
      .from('psn_sync_logs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        games_processed: processedGames,
        trophies_synced: totalTrophies,
      })
      .eq('id', syncLogId);

    console.log(
      `PSN sync completed: ${processedGames} games, ${totalTrophies} trophies`
    );
  } catch (error) {
    console.error('PSN sync failed:', error);

    await updateSyncStatus(userId, {
      psn_sync_status: 'error',
      psn_sync_progress: 0,
      psn_sync_error: error.message?.substring(0, 500) || 'Unknown error',
    });

    await supabase
      .from('psn_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error.message,
      })
      .eq('id', syncLogId);
  }
}
