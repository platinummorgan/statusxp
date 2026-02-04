/**
 * Faster cleanup - delete old duplicates via SQL
 */

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

async function fastCleanup() {
  console.log('🧹 Fast cleanup: Deleting timestamped duplicates via SQL...\n');

  // Delete all files with timestamps in filename (keep only files without timestamps)
  // Pattern: achievement-icons/{platform}/{id}_{timestamp}.{ext}
  const { data, error } = await supabase.rpc('exec', {
    sql: `
      DELETE FROM storage.objects 
      WHERE bucket_id = 'avatars' 
        AND name LIKE 'achievement-icons/%/%_%_%.%'
        AND name ~ 'achievement-icons/[^/]+/[^/]+_[0-9]+\\.[a-z]+$';
    `
  });

  if (error) {
    console.error('❌ SQL execution failed:', error);
    console.log('\nTrying alternative approach with storage API...');
    
    // Alternative: Get list and batch delete
    const { data: files } = await supabase.storage
      .from('avatars')
      .list('achievement-icons', { limit: 100000 });
    
    if (!files) {
      console.error('Failed to list files');
      return;
    }

    let totalDeleted = 0;
    for (const folder of files) {
      const { data: icons } = await supabase.storage
        .from('avatars')
        .list(`achievement-icons/${folder.name}`, { limit: 100000 });
      
      if (!icons) continue;

      // Find files with timestamps (name contains underscore followed by numbers)
      const toDelete = icons
        .filter(f => /_\d+\.\w+$/.test(f.name))
        .map(f => `achievement-icons/${folder.name}/${f.name}`);

      if (toDelete.length === 0) continue;

      console.log(`Deleting ${toDelete.length} files from ${folder.name}...`);

      // Delete in batches of 100
      for (let i = 0; i < toDelete.length; i += 100) {
        const batch = toDelete.slice(i, i + 100);
        const { error } = await supabase.storage.from('avatars').remove(batch);
        
        if (error) {
          console.error(`  ❌ Batch ${i}-${i+batch.length} failed:`, error.message);
        } else {
          totalDeleted += batch.length;
          console.log(`  ✅ Deleted ${batch.length} files (total: ${totalDeleted})`);
        }
      }
    }

    console.log(`\n✨ Deleted ${totalDeleted} duplicate files`);
  } else {
    console.log('✨ SQL cleanup complete!', data);
  }
}

fastCleanup()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('💥 Cleanup failed:', error);
    process.exit(1);
  });
