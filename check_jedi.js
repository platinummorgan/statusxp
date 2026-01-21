const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://ksriqcmumjkemtfjuedm.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODkzNzgwMywiZXhwIjoyMDg0Mjk3ODAzfQ.fOvpjoLly2c-L_ujvfhLZX7OQjM3QO2qA9y4P2reSbE'
);

async function checkJedi() {
  const { data, error } = await supabase
    .from('games')
    .select('platform_id, platform_game_id, name')
    .ilike('name', '%jedi%fallen%')
    .order('platform_id');
  
  if (error) {
    console.error('Error querying games:', error);
    return;
  }
  
  if (data.length === 0) {
    console.log('No Star Wars Jedi games found');
    return;
  }
  
  console.log('Star Wars Jedi: Fallen Order entries:\n');
  data.forEach(game => {
    console.log(`Platform ${game.platform_id}: ${game.name}`);
    console.log(`  platform_game_id (np_communication_id): ${game.platform_game_id}\n`);
  });
  
  if (data.length > 1) {
    const ids = data.map(g => g.platform_game_id);
    const unique = new Set(ids);
    if (unique.size === 1) {
      console.log('⚠️  SAME trophy list ID on multiple platforms (backwards compatible game)');
    } else {
      console.log('✅ DIFFERENT trophy list IDs (separate PS4/PS5 versions)');
    }
  }
}

checkJedi();
