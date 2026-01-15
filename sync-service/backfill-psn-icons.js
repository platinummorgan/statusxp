// Backfill proxied_icon_url for existing PSN achievements
import { createClient } from '@supabase/supabase-js';
import { uploadExternalIcon } from './icon-proxy-utils.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function backfillPsnIcons() {
  console.log('🔄 Starting PSN icon backfill...');
  
  // Fetch ALL PSN achievements without proxied URLs (paginated)
  let allAchievements = [];
  let from = 0;
  const pageSize = 1000;
  
  while (true) {
    const { data, error, count } = await supabase
      .from('achievements')
      .select('id, platform_achievement_id, icon_url', { count: 'exact' })
      .eq('platform', 'psn')
      .is('proxied_icon_url', null)
      .not('icon_url', 'is', null)
      .range(from, from + pageSize - 1);
    
    if (error) {
      console.error('❌ Failed to fetch achievements:', error);
      return;
    }
    
    if (data.length === 0) break;
    
    allAchievements = allAchievements.concat(data);
    console.log(`📄 Fetched ${allAchievements.length} of ${count} achievements...`);
    
    if (data.length < pageSize) break;
    from += pageSize;
  }
  
  const achievements = allAchievements;
  console.log(`📊 Total PSN achievements to backfill: ${achievements.length}`);
  
  let successCount = 0;
  let failCount = 0;
  
  // Process in batches to avoid overwhelming the system
  const BATCH_SIZE = 50;
  for (let i = 0; i < achievements.length; i += BATCH_SIZE) {
    const batch = achievements.slice(i, i + BATCH_SIZE);
    
    console.log(`\n🔄 Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(achievements.length / BATCH_SIZE)}`);
    
    const promises = batch.map(async (achievement) => {
      try {
        const proxiedUrl = await uploadExternalIcon(
          achievement.icon_url,
          achievement.platform_achievement_id,
          'psn',
          supabase
        );
        
        if (proxiedUrl) {
          await supabase
            .from('achievements')
            .update({ proxied_icon_url: proxiedUrl })
            .eq('id', achievement.id);
          
          successCount++;
          return true;
        } else {
          failCount++;
          return false;
        }
      } catch (error) {
        console.error(`Failed to proxy ${achievement.platform_achievement_id}:`, error.message);
        failCount++;
        return false;
      }
    });
    
    await Promise.all(promises);
    
    console.log(`✅ Success: ${successCount} | ❌ Failed: ${failCount}`);
    
    // Small delay between batches
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  console.log('\n🎉 Backfill complete!');
  console.log(`✅ Successfully proxied: ${successCount}`);
  console.log(`❌ Failed: ${failCount}`);
  
  // Exit successfully
  process.exit(0);
}

backfillPsnIcons().catch(error => {
  console.error('❌ Backfill failed:', error);
  process.exit(1);
});
