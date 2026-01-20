// Quick monitoring script for PSN sync progress
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://ksriqcmumjkemtfjuedm.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDcxNDE4NCwiZXhwIjoyMDgwMjkwMTg0fQ.tGA4TM9AjAomtriuotavNlr6RGllgin_9AVEAS5HDOE'
);

const userId = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

async function checkStatus() {
  console.clear();
  console.log('='.repeat(80));
  console.log('PSN SYNC MONITOR - Press Ctrl+C to exit');
  console.log('='.repeat(80));
  console.log();

  // 1. Sync status
  const { data: profile } = await supabase
    .from('profiles')
    .select('psn_sync_status, psn_sync_progress, psn_sync_error, last_psn_sync_at')
    .eq('id', userId)
    .single();

  console.log('📊 SYNC STATUS:');
  console.log(`   Status: ${profile?.psn_sync_status || 'not started'}`);
  console.log(`   Progress: ${profile?.psn_sync_progress || 0}%`);
  console.log(`   Error: ${profile?.psn_sync_error || 'none'}`);
  console.log(`   Last Sync: ${profile?.last_psn_sync_at || 'never'}`);
  console.log();

  // 2. Achievement counts
  const { data: achievements } = await supabase
    .from('user_achievements')
    .select('achievement_id, achievements!inner(platform)')
    .eq('user_id', userId);

  const psnCount = achievements?.filter(a => a.achievements.platform === 'psn').length || 0;
  const xboxCount = achievements?.filter(a => a.achievements.platform === 'xbox').length || 0;
  const steamCount = achievements?.filter(a => a.achievements.platform === 'steam').length || 0;

  console.log('🏆 ACHIEVEMENT COUNTS:');
  console.log(`   PSN: ${psnCount} (expected: 9,399 + 5 = 9,404)`);
  console.log(`   Xbox: ${xboxCount} (expected: 309 + 8 = 317)`);
  console.log(`   Steam: ${steamCount} (expected: 581)`);
  console.log(`   Total: ${psnCount + xboxCount + steamCount}`);
  console.log();

  // 3. Test games status
  const testGames = [
    'Gems of War',
    'DRAGON QUEST HEROES II',
    'Terraria',
    'DOGFIGHTER -WW2-',
    'Sky: Children of the Light'
  ];

  console.log('🎮 TEST GAMES STATUS:');
  for (const gameName of testGames) {
    const { data: gameData } = await supabase
      .from('user_games')
      .select(`
        earned_trophies,
        game_titles!inner(name),
        achievements:game_titles!inner(achievements(id))
      `)
      .eq('user_id', userId)
      .eq('game_titles.name', gameName)
      .single();

    if (gameData) {
      const achievementIds = gameData.game_titles.achievements.map(a => a.id);
      
      const { count } = await supabase
        .from('user_achievements')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId)
        .in('achievement_id', achievementIds);

      const status = gameData.earned_trophies > 0 && count === 0 ? '❌ MISSING' : 
                     count > 0 ? '✅ WRITTEN' : '⚪ NO DATA';
      
      console.log(`   ${status} ${gameName}: ${count || 0}/${gameData.earned_trophies} achievements`);
    }
  }
  console.log();
  console.log('Refreshing in 3 seconds...');
}

// Run every 3 seconds
setInterval(checkStatus, 3000);
checkStatus();
