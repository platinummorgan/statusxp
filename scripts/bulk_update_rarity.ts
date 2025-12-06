/**
 * Bulk update trophy rarity for all games
 * 
 * Run with: deno run --allow-net --allow-env bulk_update_rarity.ts
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 'YOUR_SUPABASE_URL';
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || 'YOUR_SERVICE_ROLE_KEY';
const USER_ID = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function updateRarityForAllGames() {
  console.log('Starting bulk rarity update...');
  
  // Get user's PSN credentials
  const { data: profile } = await supabase
    .from('profiles')
    .select('psn_account_id, psn_access_token, psn_refresh_token')
    .eq('id', USER_ID)
    .single();
  
  if (!profile?.psn_access_token) {
    console.error('No PSN credentials found');
    return;
  }
  
  // Get all user's games
  const { data: userGames } = await supabase
    .from('user_games')
    .select('game_title_id, game_titles!inner(psn_title_id, name)')
    .eq('user_id', USER_ID);
  
  console.log(`Found ${userGames?.length} games to process`);
  
  let updated = 0;
  
  for (const game of userGames || []) {
    const gameTitle = (game as any).game_titles;
    console.log(`Processing: ${gameTitle.name}`);
    
    try {
      // Call your existing edge function to sync this game
      const response = await fetch(`${SUPABASE_URL}/functions/v1/psn-start-sync`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${profile.psn_access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          forceResync: true,
          syncType: 'full'
        }),
      });
      
      if (response.ok) {
        updated++;
        console.log(`✓ Updated ${gameTitle.name}`);
      } else {
        console.log(`✗ Failed ${gameTitle.name}`);
      }
      
      // Rate limit - wait 1 second between requests
      await new Promise(resolve => setTimeout(resolve, 1000));
      
    } catch (error) {
      console.error(`Error processing ${gameTitle.name}:`, error);
    }
  }
  
  console.log(`\nCompleted! Updated ${updated} out of ${userGames?.length} games`);
}

updateRarityForAllGames();
