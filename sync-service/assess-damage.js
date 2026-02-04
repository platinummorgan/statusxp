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

console.log('📊 Assessing icon_url column corruption...\n');

// PlayStation
const { count: psnTotal } = await supabase
  .from('achievements')
  .select('*', { count: 'exact', head: true })
  .in('platform_id', [1, 2, 5, 9]);

const { count: psnCorrect } = await supabase
  .from('achievements')
  .select('*', { count: 'exact', head: true })
  .in('platform_id', [1, 2, 5, 9])
  .or('icon_url.like.%image.api.playstation.com%,icon_url.like.%psnobj.prod.dl.playstation.net%');

const { count: psnCorrupted } = await supabase
  .from('achievements')
  .select('*', { count: 'exact', head: true })
  .in('platform_id', [1, 2, 5, 9])
  .like('icon_url', '%supabase%');

console.log('PlayStation (PS3/PS4/PS5/Vita):');
console.log(`  Total: ${psnTotal}`);
console.log(`  ✅ Correct (external CDN): ${psnCorrect}`);
console.log(`  ❌ Corrupted (Supabase URL): ${psnCorrupted}`);
console.log(`  ⚠️  Missing/Other: ${psnTotal - psnCorrect - psnCorrupted}\n`);

// Steam
const { count: steamTotal } = await supabase
  .from('achievements')
  .select('*', { count: 'exact', head: true })
  .in('platform_id', [4, 8]);

const { count: steamCorrect } = await supabase
  .from('achievements')
  .select('*', { count: 'exact', head: true })
  .in('platform_id', [4, 8])
  .or('icon_url.like.%steamcdn%,icon_url.like.%steamstatic%,icon_url.like.%cloudflare.steamstatic%');

const { count: steamCorrupted } = await supabase
  .from('achievements')
  .select('*', { count: 'exact', head: true })
  .in('platform_id', [4, 8])
  .like('icon_url', '%supabase%');

console.log('Steam:');
console.log(`  Total: ${steamTotal}`);
console.log(`  ✅ Correct (external CDN): ${steamCorrect}`);
console.log(`  ❌ Corrupted (Supabase URL): ${steamCorrupted}`);
console.log(`  ⚠️  Missing/Other: ${steamTotal - steamCorrect - steamCorrupted}\n`);

console.log('TOTAL CORRUPTION:');
console.log(`  ${psnCorrupted + steamCorrupted} achievements have Supabase URLs in icon_url column`);
console.log(`  These will be fixed when users sync their accounts`);

process.exit(0);
