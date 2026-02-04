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

// Get your user ID first
const { data: profile } = await supabase
  .from('profiles')
  .select('id')
  .limit(1)
  .single();

console.log('Testing Flex Room RPC with user:', profile.id);

// Call the RPC exactly like the app does
const { data, error } = await supabase.rpc('get_flex_room_achievements', {
  p_user_id: profile.id
});

if (error) {
  console.error('RPC Error:', error);
} else {
  console.log(`\nReturned ${data.length} achievements\n`);
  
  // Find Death Stranding 2 achievements
  const ds2 = data.filter(a => a.game_name?.includes('DEATH STRANDING 2'));
  
  console.log(`Death Stranding 2 achievements: ${ds2.length}\n`);
  
  ds2.slice(0, 5).forEach(a => {
    console.log(`${a.achievement_name}`);
    console.log(`  icon_url: ${a.icon_url || 'NULL'}`);
    console.log(`  Has icon: ${!!a.icon_url}\n`);
  });
}

process.exit(0);
