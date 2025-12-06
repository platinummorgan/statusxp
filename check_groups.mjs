import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://ksriqcmumjkemtfjuedm.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MTQxODQsImV4cCI6MjA4MDI5MDE4NH0.svxzehEtMDUQjF-stp7GL_LmRKQOFu_6PxI0IgbLVoQ';

const supabase = createClient(supabaseUrl, supabaseKey);

console.log('Checking DLC trophy groups...\n');

// 1. Count total games
const { count: totalGames } = await supabase
  .from('game_titles')
  .select('*', { count: 'exact', head: true });

console.log(`Total games in database: ${totalGames}`);

// 2. Count games with psn_has_trophy_groups = true
const { count: gamesWithGroups } = await supabase
  .from('game_titles')
  .select('*', { count: 'exact', head: true })
  .eq('psn_has_trophy_groups', true);

console.log(`Games marked as having trophy groups: ${gamesWithGroups}`);

// 3. Count total trophies
const { count: totalTrophies } = await supabase
  .from('trophies')
  .select('*', { count: 'exact', head: true });

console.log(`Total trophies in database: ${totalTrophies}`);

// 4. Sample trophies with different group IDs
const { data: sampleTrophies } = await supabase
  .from('trophies')
  .select('psn_trophy_group_id, game_titles!inner(title)')
  .neq('psn_trophy_group_id', 'default')
  .limit(10);

if (sampleTrophies && sampleTrophies.length > 0) {
  console.log(`\n✅ DLC trophy groups found! Sample:`);
  sampleTrophies.forEach(t => {
    console.log(`  - ${t.game_titles.title}: Group ${t.psn_trophy_group_id}`);
  });
} else {
  console.log(`\n❌ No DLC trophy groups found (all trophies have group_id = 'default')`);
}

// 5. Get games with multiple trophy groups
const { data: games } = await supabase
  .from('game_titles')
  .select('title, psn_has_trophy_groups')
  .eq('psn_has_trophy_groups', true)
  .limit(5);

if (games && games.length > 0) {
  console.log(`\nGames flagged as having DLC:`);
  games.forEach(g => {
    console.log(`  - ${g.title}`);
  });
}
