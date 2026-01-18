/**
 * Backfill missing xbox_title_id values for games in the database
 * Uses Xbox API to fetch titleId for games that only have names
 * 
 * Run with: node backfill-xbox-title-ids.js
 */

import { createClient } from '@supabase/supabase-js';
import 'dotenv/config';

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Xbox API configuration
const XBOX_API_BASE = 'https://titlehub.xboxlive.com';

/**
 * Refresh Xbox authentication tokens
 */
async function refreshXboxAuth(refreshToken, userId) {
  console.log('🔄 Refreshing Xbox tokens...');
  
  const tokenResponse = await fetch('https://login.live.com/oauth20_token.srf', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: '000000004C12AE6F', // Xbox app client ID
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
      redirect_uri: 'https://login.live.com/oauth20_desktop.srf',
    }),
  });

  if (!tokenResponse.ok) {
    const body = await tokenResponse.text();
    throw new Error(`Failed to refresh Xbox token: ${tokenResponse.status} - ${body}`);
  }

  const tokenData = await tokenResponse.json();

  // Exchange for Xbox Live token
  const xblResponse = await fetch('https://user.auth.xboxlive.com/user/authenticate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-xbl-contract-version': '1' },
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
  const userHash = xblData.DisplayClaims.xui[0].uhs;

  // Exchange for XSTS token
  const xstsResponse = await fetch('https://xsts.auth.xboxlive.com/xsts/authorize', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-xbl-contract-version': '1' },
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

  // Update database with new tokens
  await supabase
    .from('profiles')
    .update({
      xbox_access_token: xstsData.Token,
      xbox_refresh_token: tokenData.refresh_token || refreshToken,
      xbox_user_hash: userHash,
      xbox_token_expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    })
    .eq('id', userId);

  console.log('✓ Tokens refreshed successfully\n');

  return {
    token: xstsData.Token,
    userHash: userHash
  };
}

/**
 * Search for a game title in Xbox catalog and return titleId with retries
 */
async function searchXboxTitle(gameName, xboxToken, userHash, retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const response = await fetch(
        `${XBOX_API_BASE}/titles/search?q=${encodeURIComponent(gameName)}&market=US&locale=en-US`,
        {
          headers: {
            'Authorization': `XBL3.0 x=${userHash};${xboxToken}`,
            'x-xbl-contract-version': '2'
          }
        }
      );

      if (!response.ok) {
        // If 500/503, retry with backoff
        if ((response.status === 500 || response.status === 503) && attempt < retries) {
          const delay = attempt * 2000; // 2s, 4s, 6s backoff
          console.log(`   ⏳ Xbox API error ${response.status}, retrying in ${delay/1000}s (attempt ${attempt}/${retries})...`);
          await new Promise(resolve => setTimeout(resolve, delay));
          continue;
        }
        throw new Error(`Xbox API error: ${response.status}`);
      }

      const data = await response.json();

      if (data?.titles?.length > 0) {
        // Return the first matching title
        return {
          titleId: data.titles[0].titleId,
          name: data.titles[0].name,
          modernTitleId: data.titles[0].modernTitleId
        };
      }
      
      return null;
    } catch (error) {
      if (attempt === retries) {
        console.error(`Error searching for "${gameName}":`, error.message);
        return null;
      }
      // Retry on network errors
      const delay = attempt * 2000;
      console.log(`   ⏳ Network error, retrying in ${delay/1000}s (attempt ${attempt}/${retries})...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  return null;
}

/**
 * Get Xbox authentication data from a user who has Xbox connected
 */
async function getXboxAuth() {
  const { data: profile, error } = await supabase
    .from('profiles')
    .select('id, xbox_access_token, xbox_user_hash, xbox_refresh_token')
    .not('xbox_access_token', 'is', null)
    .not('xbox_user_hash', 'is', null)
    .not('xbox_refresh_token', 'is', null)
    .limit(1)
    .single();

  if (error || !profile?.xbox_access_token || !profile?.xbox_user_hash || !profile?.xbox_refresh_token) {
    throw new Error('No Xbox access token/user hash/refresh token found. Ensure at least one user has Xbox connected.');
  }

  return {
    token: profile.xbox_access_token,
    userHash: profile.xbox_user_hash,
    refreshToken: profile.xbox_refresh_token,
    userId: profile.id
  };
}

/**
 * Backfill missing xbox_title_id values
 */
async function backfillXboxTitleIds() {
  console.log('Starting Xbox title ID backfill...\n');

  // Get Xbox authentication data
  console.log('Fetching Xbox authentication...');
  let xboxAuth = await getXboxAuth();
  console.log('✓ Got Xbox token\n');

  // Try to refresh the token immediately to ensure it's valid
  try {
    xboxAuth = await refreshXboxAuth(xboxAuth.refreshToken, xboxAuth.userId);
  } catch (error) {
    console.warn('⚠️ Token refresh failed, will try with existing token:', error.message);
  }

  // Get all game_titles with NULL xbox_title_id that have user_games with Xbox data
  const { data: games, error: fetchError } = await supabase
    .from('game_titles')
    .select(`
      id,
      name,
      xbox_title_id,
      metadata
    `)
    .is('xbox_title_id', null)
    .order('name');

  if (fetchError) {
    throw new Error(`Failed to fetch games: ${fetchError.message}`);
  }

  console.log(`Found ${games.length} games with missing xbox_title_id\n`);

  let updated = 0;
  let notFound = 0;
  let skipped = 0;

  for (const game of games) {
    // Check if any user has Xbox data for this game FIRST
    const { data: userGames } = await supabase
      .from('user_games')
      .select('xbox_current_gamerscore')
      .eq('game_title_id', game.id)
      .gt('xbox_current_gamerscore', 0)
      .limit(1);

    if (!userGames || userGames.length === 0) {
      console.log(`⊘ Skipping "${game.name}" (no Xbox data in user_games)`);
      skipped++;
      continue;
    }
    
    // If we get here, this game has Xbox data from users, so we should backfill it
    // even if it also exists on PSN/Steam (cross-platform games)

    // Search Xbox API for this title
    console.log(`🔍 Searching for "${game.name}"...`);
    const result = await searchXboxTitle(game.name, xboxAuth.token, xboxAuth.userHash);

    if (result) {
      // Update the game_title with the found titleId
      const { error: updateError } = await supabase
        .from('game_titles')
        .update({ 
          xbox_title_id: result.titleId,
          metadata: {
            ...game.metadata,
            xbox_title_id: result.titleId,
            xbox_modern_title_id: result.modernTitleId
          }
        })
        .eq('id', game.id);

      if (updateError) {
        console.error(`✗ Failed to update "${game.name}": ${updateError.message}`);
      } else {
        console.log(`✓ Updated "${game.name}" with titleId: ${result.titleId}`);
        updated++;
      }
    } else {
      console.log(`✗ Could not find Xbox titleId for "${game.name}"`);
      notFound++;
    }

    // Rate limit: wait 1 second between requests to avoid overwhelming API
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  console.log('\n=== Backfill Complete ===');
  console.log(`Updated: ${updated}`);
  console.log(`Not found: ${notFound}`);
  console.log(`Skipped (PSN/Steam): ${skipped}`);
  console.log(`Total processed: ${games.length}`);
}

// Run the backfill
backfillXboxTitleIds()
  .then(() => {
    console.log('\n✓ Backfill completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n✗ Backfill failed:', error.message);
    process.exit(1);
  });
