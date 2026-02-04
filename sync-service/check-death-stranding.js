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

// Find Death Stranding 2
const { data: games } = await supabase
  .from('games')
  .select('*')
  .ilike('name', '%death stranding%2%')
  .limit(5);

console.log('Death Stranding 2 games found:');
games?.forEach(g => {
  console.log(`  ID: ${g.id}, Platform: ${g.platform_id}, Name: ${g.name}`);
});

if (games && games.length > 0) {
  const game = games[0];
  console.log(`\nChecking achievements for: ${game.name} (game_id: ${game.id})\n`);
  
  const { data: achievements } = await supabase
    .from('achievements')
    .select('platform_achievement_id, name, icon_url, proxied_icon_url')
    .eq('platform_id', game.platform_id)
    .eq('platform_game_id', game.platform_game_id)
    .limit(10);
  
  console.log('Sample achievements:');
  achievements?.forEach(a => {
    console.log(`\n${a.name} (ID: ${a.platform_achievement_id})`);
    console.log(`  icon_url: ${a.icon_url || 'NULL'}`);
    console.log(`  proxied: ${a.proxied_icon_url || 'NULL'}`);
  });
}

process.exit(0);
