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

const { data, error } = await supabase
  .from('achievements')
  .select('platform_id, platform_achievement_id, icon_url, proxied_icon_url')
  .in('platform_id', [1, 2, 5, 9])
  .limit(10);

if (error) {
  console.error('Error:', error);
} else {
  console.log('Sample achievements:');
  data.forEach(a => {
    console.log(`\nID: ${a.platform_achievement_id}`);
    console.log(`  icon_url: ${a.icon_url?.substring(0, 100)}`);
    console.log(`  proxied: ${a.proxied_icon_url?.substring(0, 100)}`);
    console.log(`  icon_url has supabase: ${a.icon_url?.includes('supabase')}`);
  });
}

process.exit(0);
