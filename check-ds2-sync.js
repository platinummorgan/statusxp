require('dotenv').config({ path: './sync-service/.env' });
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function checkDeathStranding2() {
  console.log('Checking Death Stranding 2 achievements after sync...\n');
  
  const { data, error } = await supabase
    .from('achievements')
    .select('platform_achievement_id, title, icon_url, proxied_icon_url')
    .eq('platform_id', 2)
    .eq('platform_game_id', 'CUSA29397_00')
    .order('platform_achievement_id')
    .limit(10);
  
  if (error) {
    console.error('Error:', error);
    return;
  }
  
  console.log(`Found ${data.length} achievements\n`);
  
  data.forEach(ach => {
    console.log(`Achievement: ${ach.platform_achievement_id}`);
    console.log(`  Title: ${ach.title}`);
    
    // Check icon_url status
    if (ach.icon_url?.includes('supabase')) {
      console.log(`  ❌ icon_url: CORRUPTED (has Supabase URL)`);
    } else if (ach.icon_url?.includes('image.api.playstation.com')) {
      console.log(`  ✅ icon_url: External PSN URL`);
    } else if (ach.icon_url?.includes('psnobj.prod.dl.playstation.net')) {
      console.log(`  ✅ icon_url: External PSN CDN`);
    } else {
      console.log(`  ⚠️ icon_url: ${ach.icon_url?.substring(0, 60)}`);
    }
    
    // Check proxy status
    if (ach.proxied_icon_url) {
      console.log(`  ✅ proxied_icon_url: ${ach.proxied_icon_url.substring(0, 80)}`);
    } else {
      console.log(`  ❌ proxied_icon_url: NULL`);
    }
    
    console.log();
  });
}

checkDeathStranding2();
