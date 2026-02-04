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

// Get a sample of achievements with corrupted URLs
const { data, error } = await supabase
  .from('achievements')
  .select('platform_id, platform_achievement_id, name, icon_url, proxied_icon_url')
  .in('platform_id', [1, 2, 5, 9])
  .like('icon_url', '%supabase%')
  .limit(5);

if (error) {
  console.error('Error:', error);
} else {
  console.log('Sample achievements with corrupted icon_url:\n');
  data.forEach(a => {
    console.log(`${a.name}`);
    console.log(`  icon_url: ${a.icon_url?.substring(0, 100)}`);
    console.log(`  proxied: ${a.proxied_icon_url?.substring(0, 100)}\n`);
  });
}

process.exit(0);
