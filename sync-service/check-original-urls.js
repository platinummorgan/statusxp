import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '..', '.env') });

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Check if ANY PlayStation achievements still have original PSN URLs
const { data: psnUrls, error: psnError } = await supabase
  .from('achievements')
  .select('platform_id, platform_achievement_id, icon_url')
  .in('platform_id', [1, 2, 5, 9])
  .not('icon_url', 'like', '%supabase%')
  .limit(10);

console.log('\nPlayStation achievements with ORIGINAL (non-Supabase) URLs:');
console.log('Count:', psnUrls?.length || 0);
if (psnUrls?.length > 0) {
  psnUrls.slice(0, 3).forEach(a => {
    console.log(`  ${a.platform_achievement_id}: ${a.icon_url}`);
  });
}

// Check Xbox and Steam too
const { data: xboxUrls } = await supabase
  .from('achievements')
  .select('platform_id, platform_achievement_id, icon_url')
  .in('platform_id', [10, 11, 12])
  .not('icon_url', 'like', '%supabase%')
  .limit(10);

console.log('\nXbox achievements with ORIGINAL URLs:');
console.log('Count:', xboxUrls?.length || 0);

const { data: steamUrls } = await supabase
  .from('achievements')
  .select('platform_id, platform_achievement_id, icon_url')
  .in('platform_id', [4, 8])
  .not('icon_url', 'like', '%supabase%')
  .limit(10);

console.log('\nSteam achievements with ORIGINAL URLs:');
console.log('Count:', steamUrls?.length || 0);

// Total counts
const { count: totalPsn } = await supabase
  .from('achievements')
  .select('*', { count: 'exact', head: true })
  .in('platform_id', [1, 2, 5, 9])
  .like('icon_url', '%supabase%');

console.log(`\n📊 PlayStation achievements with Supabase in icon_url: ${totalPsn}`);

process.exit(0);
