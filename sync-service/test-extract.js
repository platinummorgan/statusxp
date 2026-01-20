        return;
      }
      
      const batch = ownedGames.slice(i, i + BATCH_SIZE);
      logMemory(`Before processing Steam batch ${i / BATCH_SIZE + 1}`);
      if (MAX_CONCURRENT <= 1) {
        for (let batchIndex = 0; batchIndex < batch.length; batchIndex++) {
          const game = batch[batchIndex];
          
          // Check for cancellation every 5 games within batch
          if (batchIndex > 0 && batchIndex % 5 === 0) {
            const { data: cancelCheck } = await supabase
              .from('profiles')
              .select('steam_sync_status')
              .eq('id', userId)
              .maybeSingle();
            
            if (cancelCheck?.steam_sync_status === 'cancelling') {
              console.log('Steam sync cancelled by user (mid-batch)');
              await supabase
                .from('profiles')
                .update({ 
                  steam_sync_status: 'stopped',
                  steam_sync_progress: 0 
                })
                .eq('id', userId);
              
              await supabase
                .from('steam_sync_logs')
                .update({
                  status: 'cancelled',
                  completed_at: new Date().toISOString(),
                })
                .eq('id', syncLogId);
              
              return;
            }
          }
          
          // Declare variables outside try block so catch can access them
          let gameTitle = null;
          
          try {
            console.log(`Processing Steam app ${game.appid} - ${game.name}`);
            
            // Get app details to check if it's DLC
            let appDetailsData;
            try {
              const appDetailsResponse = await fetch(
                `https://store.steampowered.com/api/appdetails?appids=${game.appid}`
              );
              const appDetailsContentType = appDetailsResponse.headers.get('content-type');
              if (appDetailsResponse.ok && appDetailsContentType?.includes('application/json')) {
                appDetailsData = await appDetailsResponse.json();
              }
            } catch (e) {
              console.log(`⚠️ App details fetch failed for ${game.appid}: ${e.message}`);
            }
            if (!appDetailsData) {
              appDetailsData = { [game.appid]: { data: { type: 'game' } } };
            }
            const appDetails = appDetailsData?.[game.appid]?.data;
            const isDLC = appDetails?.type === 'dlc';
            const dlcName = isDLC ? appDetails?.name : null;
            const baseGameAppId = isDLC ? appDetails?.fullgame?.appid : null;
            
            console.log(`App ${game.appid} is ${isDLC ? 'DLC' : 'base game'}${isDLC ? ` (base: ${baseGameAppId})` : ''}`);
            
            // Get game schema (achievements list)
            const schemaResponse = await fetch(
              `https://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/?key=${apiKey}&appid=${game.appid}`
            );
            console.log('Schema fetch status:', schemaResponse.status);
            
            // Check if response is JSON before parsing
            const contentType = schemaResponse.headers.get('content-type');
            if (!schemaResponse.ok || !contentType?.includes('application/json')) {
              console.log(`⚠️ Schema fetch failed for ${game.appid} (status ${schemaResponse.status}, type ${contentType}) - skipping game`);
              continue;
            }
            
            const schemaData = await schemaResponse.json();
            const achievements = schemaData.game?.availableGameStats?.achievements || [];

            if (achievements.length === 0) continue;

            // Get player achievements to check counts
            const playerAchievementsResponse = await fetch(
              `https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/?key=${apiKey}&steamid=${steamId}&appid=${game.appid}`
            );
            console.log('Player achievements fetch status:', playerAchievementsResponse.status);
            
            // Check player achievements response is JSON
            const playerContentType = playerAchievementsResponse.headers.get('content-type');
            if (!playerAchievementsResponse.ok || !playerContentType?.includes('application/json')) {
              console.log(`⚠️ Player achievements fetch failed for ${game.appid} (status ${playerAchievementsResponse.status}) - skipping game`);
              continue;
            }
            
            const playerAchievementsData = await playerAchievementsResponse.json();
            const playerAchievements = playerAchievementsData.playerstats?.achievements || [];

            // Quick count check
            const unlockedCount = playerAchievements.filter(a => a.achieved === 1).length;
            const totalCount = achievements.length;

            console.log(`📱 Platform: Steam (ID ${platformId})`);
            
            // Find or create game using Steam appid
            const trimmedName = game.name.trim();
            const { data: existingGame } = await supabase
              .from('games')
              .select('platform_game_id, cover_url, metadata')
              .eq('platform_id', platformId)
              .eq('platform_game_id', game.appid.toString())
              .maybeSingle();
            
            if (existingGame) {
              // Update cover if we don't have one
              if (!existingGame.cover_url) {
                const { error: updateError } = await supabase
                  .from('games')
                  .update({ 
                    cover_url: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`
                  })
                  .eq('platform_id', platformId)
                  .eq('platform_game_id', existingGame.platform_game_id);
                
                if (updateError) {
                  console.error('❌ Failed to update game cover:', game.name, 'Error:', updateError);
                }
              }
              gameTitle = existingGame;
            } else {
              // Create new game with V2 composite key
              const { data: newGame, error: insertError } = await supabase
                .from('games')
                .insert({
                  platform_id: platformId,
                  platform_game_id: game.appid.toString(),
                  name: trimmedName,
                  cover_url: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`,
                  metadata: {
                    steam_app_id: game.appid,
                    platform_version: 'Steam',
                    is_dlc: isDLC,
                    dlc_name: dlcName,
                    base_game_app_id: baseGameAppId,
                  },
                })
                .select()
                .single();
              
              if (insertError) {
                console.error('❌ Failed to insert game:', game.name, 'Error:', insertError);
                continue;
              }
              gameTitle = newGame;
            }

            if (!gameTitle) continue;

            // Cheap diff: Check if game data changed
            const existingUserGame = userGamesMap.get(`${gameTitle.platform_game_id}_${platformId}`);
            const isNewGame = !existingUserGame;
            const countsChanged = existingUserGame && 
              (existingUserGame.total_achievements !== totalCount || existingUserGame.achievements_earned !== unlockedCount);
            const syncFailed = existingUserGame && existingUserGame.sync_failed === true;
            
            // Check if rarity is stale (>30 days old)
            let needRarityRefresh = false;
            if (!isNewGame && !countsChanged && !syncFailed && existingUserGame) {
              const lastRaritySync = existingUserGame.last_rarity_sync ? new Date(existingUserGame.last_rarity_sync) : null;
              const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
              needRarityRefresh = !lastRaritySync || lastRaritySync < thirtyDaysAgo;
            }
            
            // BUG FIX: Check if achievements were never processed (achievements_earned > 0 but no user_achievements)
            // This happens if initial sync failed to process achievements
            let missingAchievements = false;
            if (!isNewGame && !countsChanged && !needRarityRefresh && existingUserGame?.achievements_earned > 0) {
              const { count: uaCount } = await supabase
                .from('user_achievements')
                .select('user_id', { count: 'exact', head: true })
                .eq('user_id', userId)
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle.platform_game_id);
              
              missingAchievements = (uaCount || 0) < unlockedCount;
              if (missingAchievements) {
                console.log(`🔄 MISSING ACHIEVEMENTS: ${game.name} shows ${unlockedCount} earned but ${uaCount || 0} synced - reprocessing`);
              }
            }
            
            const needsProcessing = isNewGame || countsChanged || needRarityRefresh || missingAchievements || syncFailed;
            if (syncFailed) {
              console.log(`🔄 RETRY FAILED SYNC: ${game.name} (previous sync failed)`);
            }
            if (!needsProcessing) {
              console.log(`⏭️  Skip ${game.name} - no changes`);
              processedGames++;
              const progressPercent = Math.floor((processedGames / ownedGames.length) * 100);
              await supabase.from('profiles').update({ steam_sync_progress: progressPercent }).eq('id', userId);
              continue;
            }
            
            if (needRarityRefresh) {
              console.log(`🔄 RARITY REFRESH: ${game.name} (>30 days since last rarity sync)`);
            }

            // Calculate progress
            const progress = achievements.length > 0 ? (unlockedCount / achievements.length) * 100 : 0;

            // Fetch global achievement percentages for rarity data
            const globalStats = {};
            try {
              const globalResponse = await fetch(
                `https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=${game.appid}&format=json`
              );

              const globalContentType = globalResponse.headers.get('content-type');
              if (globalResponse.ok && globalContentType?.includes('application/json')) {
                const globalData = await globalResponse.json();
                if (globalData.achievementpercentages?.achievements) {
                  for (const ach of globalData.achievementpercentages.achievements) {
                    globalStats[ach.name] = ach.percent;
                  }
                }
              }
            } catch (error) {
              console.log(`Could not fetch global stats for ${game.name}:`, error.message);
            }

            // Find most recent achievement unlock time
            let lastTrophyEarnedAt = null;
            for (const achievement of achievements) {
              const playerAch = playerAchievements.find(a => a.apiname === achievement.name);
              if (playerAch && playerAch.achieved === 1 && playerAch.unlocktime > 0) {
                const unlockDate = new Date(playerAch.unlocktime * 1000);
                if (!lastTrophyEarnedAt || unlockDate > lastTrophyEarnedAt) {
                  lastTrophyEarnedAt = unlockDate;
                }
              }
            }

            // Upsert user_progress with V2 fields
            await supabase
              .from('user_progress')
              .upsert({
                user_id: userId,
                platform_id: platformId,
                platform_game_id: gameTitle.platform_game_id,
                total_achievements: achievements.length,
                achievements_earned: unlockedCount,
                completion_percent: progress,
                last_trophy_earned_at: lastTrophyEarnedAt ? lastTrophyEarnedAt.toISOString() : null,
                sync_failed: false,
                sync_error: null,
                last_sync_attempt: new Date().toISOString(),
                metadata: {
                  platform_version: 'Steam',
                  is_dlc: isDLC,
                  dlc_name: dlcName,
                  base_game_app_id: baseGameAppId,
                },
              }, {
                onConflict: 'user_id,platform_id,platform_game_id',
              });

            // TODO OPTIMIZATION: This achievement processing loop is N+1 (2-3 DB calls per achievement)
            // Should batch upsert achievements with unique constraint on (platform_id, platform_game_id, platform_achievement_id)
            // Then batch upsert user_achievements. Same issue as PSN/Xbox - major performance bottleneck.
            // Current: 100 achievements = 200-300 DB calls. Batch: 100 achievements = 2 DB calls.
            // Process achievements
            for (let j = 0; j < achievements.length; j++) {
              const achievement = achievements[j];
              const playerAchievement = playerAchievements.find(a => a.apiname === achievement.name);
              const rarityPercent = globalStats[achievement.name] || 0;

              // Calculate StatusXP based on rarity (V2 unified tiers)
              let baseStatusXP = 10;
              let rarityMultiplier = 1.00;
              
              if (rarityPercent > 25) {
                baseStatusXP = 10;
                rarityMultiplier = 1.00;
              } else if (rarityPercent > 10) {
                baseStatusXP = 13;
                rarityMultiplier = 1.25;
              } else if (rarityPercent > 5) {
                baseStatusXP = 18;
                rarityMultiplier = 1.75;
              } else if (rarityPercent > 1) {
                baseStatusXP = 23;
                rarityMultiplier = 2.25;
              } else {
                baseStatusXP = 30;
                rarityMultiplier = 3.00;
              }

              // Proxy the icon if available
              const iconUrl = achievement.icon || '';
              const proxiedIconUrl = iconUrl ? await uploadExternalIcon(iconUrl, achievement.name, 'steam', supabase) : null;

              // Upsert achievement with V2 composite keys and StatusXP
              const achievementData = {
                platform_id: platformId,
                platform_game_id: gameTitle.platform_game_id,
                platform_achievement_id: achievement.name,
                name: achievement.displayName || achievement.name,
                description: achievement.description || '',
                icon_url: iconUrl,
                rarity_global: rarityPercent,
                base_status_xp: baseStatusXP,
                rarity_multiplier: rarityMultiplier,
                is_platinum: false, // Steam doesn't have platinums
                include_in_score: true, // All Steam achievements count
                metadata: {
                  platform_version: 'Steam',
                  steam_hidden: achievement.hidden === 1,
                  is_dlc: isDLC,
                  dlc_name: dlcName,
                },
              };

              // Only include proxied_icon_url if upload succeeded
              if (proxiedIconUrl) {
                achievementData.proxied_icon_url = proxiedIconUrl;
              }

              // Upsert achievement with composite key
              const { data: achievementRecord, error: achError } = await supabase
                .from('achievements')
                .upsert(achievementData, {
                  onConflict: 'platform_id,platform_game_id,platform_achievement_id',
                })
                .select()
                .single();

              if (achError) {
                console.error(`❌ Failed to upsert achievement ${achievement.name}:`, achError.message);
                continue;
              }

              if (!achievementRecord) continue;

              // Upsert user_achievement if unlocked
              if (playerAchievement && playerAchievement.achieved === 1) {
                // SAFETY: Steam should never have platinums
                if (achievementRecord.is_platinum) {
                  console.log(`⚠️ [VALIDATION BLOCKED] Steam achievement marked as platinum: ${achievement.name}`);
                  continue;
                }

                await supabase
                  .from('user_achievements')
                  .upsert({
                    user_id: userId,
                    platform_id: platformId,
                    platform_game_id: gameTitle.platform_game_id,
                    platform_achievement_id: achievement.name,
                    earned_at: new Date(playerAchievement.unlocktime * 1000).toISOString(),
                  }, {
                    onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
                  });
                
                totalAchievements++;
              }
            }

            processedGames++;
            const progressPercent = Math.floor((processedGames / ownedGames.length) * 100);
            
            // Update progress
            await supabase
              .from('profiles')
              .update({ steam_sync_progress: progressPercent })
              .eq('id', userId);

            console.log(`Processed ${processedGames}/${ownedGames.length} games (${progressPercent}%)`);
            // brief pause to yield to the event loop and let memory settle
            await new Promise((r) => setTimeout(r, 25));
            
          } catch (error) {
            console.error(`Error processing game ${game.name}:`, error);
            
            // Mark sync as failed for this game
            try {
              await supabase
                .from('user_progress')
                .update({
                  sync_failed: true,
                  sync_error: (error.message || String(error)).substring(0, 255),
                  last_sync_attempt: new Date().toISOString(),
                })
                .eq('user_id', userId)
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle?.platform_game_id);
            } catch (updateErr) {
              console.error('Failed to mark sync_failed:', updateErr);
            }
            
            // Continue with next game
          }
        }
      }
      
      logMemory(`After processing Steam batch ${i / BATCH_SIZE + 1}`);
    }

    // Calculate StatusXP for all achievements and games
    console.log('Calculating StatusXP values...');
    try {
      await supabase.rpc('refresh_statusxp_leaderboard');
      console.log('✅ StatusXP calculation complete');
