// Force redeploy after optimization fix - Dec 7, 2025
import { createClient } from '@supabase/supabase-js';
import { uploadExternalIcon } from './icon-proxy-utils.js';

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
  const { getUserTitles, getTitleTrophies, getUserTrophiesEarnedForTitle, exchangeRefreshTokenForAuthTokens } =
    psnApi;
  const getUserProfile = psnApi.getUserProfile; // Optional - may not exist in all versions

  try {
    console.log('Refreshing PSN access token...');
    const authTokens = await exchangeRefreshTokenForAuthTokens(refreshToken);
    let currentAccessToken = authTokens.accessToken;
    let currentRefreshToken = authTokens.refreshToken;
    console.log('PSN access token refreshed successfully');

    // Fetch user profile to ensure psn_online_id is set (if available)
    console.log('Fetching PSN user profile...');
    try {
      if (getUserProfile) {
        const userProfile = await getUserProfile({ accessToken: currentAccessToken }, accountId);
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
      } else {
        console.log('⚠️ getUserProfile not available in psn-api version, skipping profile fetch');
      }
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
      const { data: existingGames } = await supabase
        .from('user_games')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('platform_id', 1); // PSN platform_id
      
      if (existingGames && existingGames.length > 0) {
        throw new Error(`PSN API returned 0 titles but user has ${existingGames.length} existing games. This is likely an API error.`);
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

    // Load ALL user_games ONCE for fast lookup
    console.log('Loading all user_games for comparison...');
    const { data: allUserGames } = await supabase
      .from('user_games')
      .select('game_title_id, platform_id, earned_trophies, total_trophies, completion_percent, last_rarity_sync, sync_failed')
      .eq('user_id', userId);
    
    const userGamesMap = new Map();
    (allUserGames || []).forEach(ug => {
      userGamesMap.set(`${ug.game_title_id}_${ug.platform_id}`, ug);
    });
    console.log(`Loaded ${userGamesMap.size} existing user_games into memory`);

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
        let platform;
        
        try {
          // Map PSN platform codes to our platform codes
          let platformCode = 'PS5';
          if (title.trophyTitlePlatform) {
            const psnPlatform = title.trophyTitlePlatform.toUpperCase();
            if (psnPlatform.includes('PS5')) platformCode = 'PS5';
            else if (psnPlatform.includes('PS4')) platformCode = 'PS4';
            else if (psnPlatform.includes('PS3')) platformCode = 'PS3';
            else if (psnPlatform.includes('VITA')) platformCode = 'PSVITA';
          }

          console.log(`📱 Platform detected: ${title.trophyTitlePlatform} → ${platformCode}`);

          const { data: platformData, error: platformError } = await supabase
            .from('platforms')
            .select('id')
            .eq('code', platformCode)
            .single();
          
          platform = platformData;

          if (platformError || !platformData) {
            console.error(
              `❌ Platform query failed for code ${platformCode} (PSN: ${title.trophyTitlePlatform}):`,
              platformError?.message || 'Platform not found'
            );
            console.error(`   Skipping game: ${title.trophyTitleName}`);
            return;
          }

          console.log(`✅ Platform resolved: ${platformCode} → ID ${platformData.id}`);

          // Find or create game_title using unique PSN npCommunicationId
          const trimmedTitle = title.trophyTitleName.trim();
          
          // First try to find by PSN npCommunicationId using dedicated column
          const { data: existingGameById } = await supabase
            .from('game_titles')
            .select('id, cover_url, metadata')
            .eq('psn_npwr_id', title.npCommunicationId)
            .maybeSingle();
          
          if (existingGameById) {
            // Found by npCommunicationId - this is the exact game
            if (!existingGameById.cover_url && title.trophyTitleIconUrl) {
              console.log('Attempting to update PSN game_title:', { 
                name: title.trophyTitleName, 
                id: existingGameById.id, 
                npwr: title.npCommunicationId,
                hasId: !!existingGameById.id 
              });
              const { error: updateError } = await supabase
                .from('game_titles')
                .update({ cover_url: title.trophyTitleIconUrl })
                .eq('id', existingGameById.id);
              
              if (updateError) {
                console.error('❌ Failed to update game_title cover:', title.trophyTitleName, 'Error:', updateError);
                console.error('  - Game ID was:', existingGameById.id);
              }
            }
            gameTitle = existingGameById;
          } else {
            // Not found by ID - create new game with npCommunicationId in dedicated column
            const { data: newGame, error: insertError } = await supabase
              .from('game_titles')
              .insert({
                name: trimmedTitle,
                cover_url: title.trophyTitleIconUrl,
                psn_npwr_id: title.npCommunicationId,
                metadata: { psn_np_communication_id: title.npCommunicationId },
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
          const existingUserGame = userGamesMap.get(`${gameTitle.id}_${platform.id}`);
          const isNewGame = !existingUserGame;
          const earnedChanged = existingUserGame && existingUserGame.earned_trophies !== apiEarnedTrophies;
          const syncFailed = existingUserGame && existingUserGame.sync_failed === true;
          
          // Check if rarity is stale (>30 days old)
          let needRarityRefresh = false;
          if (!isNewGame && !earnedChanged && !syncFailed && existingUserGame) {
            const lastRaritySync = existingUserGame.last_rarity_sync ? new Date(existingUserGame.last_rarity_sync) : null;
            const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
            needRarityRefresh = !lastRaritySync || lastRaritySync < thirtyDaysAgo;
          }
          
          const needTrophies = isNewGame || earnedChanged || needRarityRefresh || syncFailed;

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

          if (!needTrophies) {
            // No changes detected - update user_games and skip trophy fetch
            const userGameData = {
              user_id: userId,
              game_title_id: gameTitle.id,
              platform_id: platform.id,
              completion_percent: apiProgress,
              total_trophies: apiTotalTrophies,
              earned_trophies: apiEarnedTrophies,
              last_rarity_sync: new Date().toISOString(),
              bronze_trophies: earned.bronze || 0,
              silver_trophies: earned.silver || 0,
              gold_trophies: earned.gold || 0,
              platinum_trophies: earned.platinum || 0,
              has_platinum: (earned.platinum || 0) > 0,
              last_played_at: title.lastUpdatedDateTime,
              sync_failed: false,
              sync_error: null,
            };
            
            if (existingUserGame && existingUserGame.last_trophy_earned_at) {
              userGameData.last_trophy_earned_at = existingUserGame.last_trophy_earned_at;
            }
            
            await supabase
              .from('user_games')
              .upsert(userGameData, { onConflict: 'user_id,game_title_id,platform_id' });

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
            console.error(`❌ Failed to fetch trophies for ${title.trophyTitleName} - skipping user_games update to prevent data inconsistency`);
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

          // Now that we successfully fetched trophy data, update user_games
          const userGameData = {
            user_id: userId,
            game_title_id: gameTitle.id,
            platform_id: platform.id,
            completion_percent: apiProgress,
            total_trophies: apiTotalTrophies,
            earned_trophies: apiEarnedTrophies,
            last_rarity_sync: new Date().toISOString(),
            bronze_trophies: earned.bronze || 0,
            silver_trophies: earned.silver || 0,
            gold_trophies: earned.gold || 0,
            platinum_trophies: earned.platinum || 0,
            has_platinum: (earned.platinum || 0) > 0,
            last_played_at: title.lastUpdatedDateTime,
            sync_failed: false,
            sync_error: null,
            last_sync_attempt: new Date().toISOString(),
          };
          
          // Preserve last_trophy_earned_at if it exists (will be updated later after processing trophies)
          if (existingUserGame && existingUserGame.last_trophy_earned_at) {
            userGameData.last_trophy_earned_at = existingUserGame.last_trophy_earned_at;
          }
          
          await supabase
            .from('user_games')
            .upsert(userGameData, { onConflict: 'user_id,game_title_id,platform_id' });

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

            const achievementData = {
              game_title_id: gameTitle.id,
              platform: 'psn',
              platform_version: platformCode, // PS3, PS4, PS5, PSVITA
              platform_achievement_id: trophyMeta.trophyId.toString(),
              name: trophyMeta.trophyName,
              description: trophyMeta.trophyDetail,
              icon_url: trophyMeta.trophyIconUrl,
              psn_trophy_type: trophyMeta.trophyType,
              rarity_global: rarityPercent,
              is_platinum: trophyMeta.trophyType === 'platinum',
              include_in_score: trophyMeta.trophyType !== 'platinum',
              is_dlc: isDLC,
              dlc_name: dlcName,
            };

            // Only include proxied_icon_url if upload succeeded
            if (proxiedIconUrl) {
              achievementData.proxied_icon_url = proxiedIconUrl;
            }

            // Check if achievement exists
            const { data: existing } = await supabase
              .from('achievements')
              .select('id, proxied_icon_url')
              .eq('game_title_id', gameTitle.id)
              .eq('platform', 'psn')
              .eq('platform_achievement_id', trophyMeta.trophyId.toString())
              .maybeSingle();

            let achievementRecord;
            if (existing) {
              // Update existing
              const { data } = await supabase
                .from('achievements')
                .update(achievementData)
                .eq('id', existing.id)
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
                    achievement_id: achievementRecord.id,
                    earned_at: userTrophy.earnedDateTime,
                  },
                  {
                    onConflict: 'user_id,achievement_id',
                  }
                );

              totalTrophies++;
            }
          }

          // Update user_games with the most recent trophy earned date
          if (mostRecentTrophyDate) {
            await supabase
              .from('user_games')
              .update({
                last_trophy_earned_at: mostRecentTrophyDate.toISOString(),
              })
              .eq('user_id', userId)
              .eq('game_title_id', gameTitle.id)
              .eq('platform_id', platform.id);
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
          
          // If trophy fetch/processing failed, mark the game with sync_failed flag if we have gameTitle/platform
          // This prevents data inconsistency where user_games says has_platinum but no achievements exist
          if (gameTitle?.id && platform?.id) {
            try {
              await supabase
                .from('user_games')
                .update({
                  sync_failed: true,
                  sync_error: error.message?.substring(0, 255),
                  last_sync_attempt: new Date().toISOString(),
                })
                .eq('user_id', userId)
                .eq('game_title_id', gameTitle.id)
                .eq('platform_id', platform.id);
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
        for (const title of batch) {
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
      await supabase.rpc('calculate_user_achievement_statusxp');
      await supabase.rpc('calculate_user_game_statusxp');
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
