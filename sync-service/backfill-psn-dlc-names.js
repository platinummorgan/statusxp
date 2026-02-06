#!/usr/bin/env node

/**
 * Backfill PSN DLC names for existing achievements
 * This updates the metadata field without requiring a full resync
 * Usage: node backfill-psn-dlc-names.js
 */

import dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

import { createClient } from '@supabase/supabase-js';
import { getTitleTrophyGroups } from 'psn-api';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials in .env.local');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function backfillDlcNames() {
  console.log('\n🔧 Starting PSN DLC name backfill...\n');
  
  try {
    // Get all unique PSN games that have achievements
    const { data: games, error: gamesError } = await supabase
      .from('games')
      .select('platform_id, platform_game_id, name, metadata')
      .in('platform_id', [1, 2]) // PS4 and PS5
      .order('name');
    
    if (gamesError) throw gamesError;
    
    console.log(`📚 Found ${games.length} PSN games\n`);
    
    let updatedGames = 0;
    let updatedAchievements = 0;
    
    for (const game of games) {
      const npCommunicationId = game.metadata?.np_communication_id;
      const hasTrophyGroups = game.metadata?.has_trophy_groups;
      
      if (!npCommunicationId) {
        console.log(`⚠️  Skipping ${game.name} - no np_communication_id`);
        continue;
      }
      
      if (!hasTrophyGroups) {
        console.log(`⏭️  Skipping ${game.name} - no DLC groups`);
        continue;
      }
      
      console.log(`\n🎮 Processing: ${game.name}`);
      console.log(`   Platform ID: ${game.platform_id}, Game ID: ${game.platform_game_id}`);
      
      // You'll need to provide PSN authorization here
      // This requires the user's PSN access token
      console.log(`   ⚠️  Need PSN authorization to fetch trophy groups`);
      console.log(`   Run a manual sync instead, or add PSN auth to this script\n`);
      
      // Example of what would happen:
      // const authorization = { accessToken: '...' };
      // const { trophyGroups } = await getTitleTrophyGroups(authorization, npCommunicationId, 'trophy');
      // const trophyGroupMap = new Map();
      // trophyGroupMap.set('default', 'Base Game');
      // trophyGroups.forEach(group => {
      //   trophyGroupMap.set(group.trophyGroupId, group.trophyGroupName);
      // });
      
      // Get all achievements for this game
      // const { data: achievements } = await supabase
      //   .from('achievements')
      //   .select('platform_achievement_id, metadata')
      //   .eq('platform_id', game.platform_id)
      //   .eq('platform_game_id', game.platform_game_id);
      
      // Update each achievement's metadata
      // for (const ach of achievements) {
      //   const trophyGroupId = ach.metadata?.trophy_group_id || 'default';
      //   const isDlc = trophyGroupId !== 'default';
      //   const dlcName = trophyGroupMap.get(trophyGroupId) || (isDlc ? `DLC ${trophyGroupId}` : null);
      //   
      //   const newMetadata = {
      //     ...ach.metadata,
      //     is_dlc: isDlc,
      //     dlc_name: dlcName
      //   };
      //   
      //   await supabase
      //     .from('achievements')
      //     .update({ metadata: newMetadata })
      //     .eq('platform_id', game.platform_id)
      //     .eq('platform_game_id', game.platform_game_id)
      //     .eq('platform_achievement_id', ach.platform_achievement_id);
      // }
    }
    
    console.log(`\n✅ Backfill complete!`);
    console.log(`   Games updated: ${updatedGames}`);
    console.log(`   Achievements updated: ${updatedAchievements}\n`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

console.log('\n⚠️  NOTE: This script requires PSN authentication');
console.log('The safer option is to just run a normal PSN sync from the app');
console.log('The upsert logic will UPDATE existing achievements without duplicating\n');

backfillDlcNames();
