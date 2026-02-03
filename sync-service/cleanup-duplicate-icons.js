/**
 * Cleanup script to delete duplicate achievement icons
 * Keeps only the newest version of each icon (by timestamp in filename)
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

async function cleanupDuplicateIcons() {
  console.log('🧹 Starting cleanup of duplicate achievement icons...\n');

  let offset = 0;
  const batchSize = 1000;
  let totalDeleted = 0;
  let totalChecked = 0;

  while (true) {
    console.log(`Fetching batch at offset ${offset}...`);
    
    // Fetch files from achievement-icons folder
    const { data: files, error } = await supabase.storage
      .from('avatars')
      .list('achievement-icons', {
        limit: batchSize,
        offset: offset,
        sortBy: { column: 'name', order: 'asc' }
      });

    if (error) {
      console.error('Error fetching files:', error);
      break;
    }

    if (!files || files.length === 0) {
      console.log('No more files to process.');
      break;
    }

    console.log(`Processing ${files.length} folders...`);

    // Process each platform folder
    for (const folder of files) {
      if (!folder.name) continue;
      
      // Get all files in this platform folder
      const { data: iconFiles, error: iconError } = await supabase.storage
        .from('avatars')
        .list(`achievement-icons/${folder.name}`, {
          limit: 10000,
          sortBy: { column: 'name', order: 'desc' } // Newest first
        });

      if (iconError || !iconFiles) {
        console.error(`Error fetching icons for ${folder.name}:`, iconError);
        continue;
      }

      // Group files by base achievement ID (without timestamp)
      const groupedFiles = {};
      for (const file of iconFiles) {
        // Parse filename: achievementId_timestamp.ext or achievementId.ext
        const match = file.name.match(/^(.+?)(?:_\d+)?\.(\w+)$/);
        if (!match) continue;

        const baseId = match[1];
        if (!groupedFiles[baseId]) {
          groupedFiles[baseId] = [];
        }
        groupedFiles[baseId].push(file);
      }

      // Delete all but the newest file for each achievement
      for (const [baseId, versions] of Object.entries(groupedFiles)) {
        totalChecked++;
        
        if (versions.length > 1) {
          // Sort by name descending (newest timestamp first)
          versions.sort((a, b) => b.name.localeCompare(a.name));
          
          // Keep the first (newest), delete the rest
          const toDelete = versions.slice(1);
          
          console.log(`  ${folder.name}/${baseId}: Keeping ${versions[0].name}, deleting ${toDelete.length} duplicates`);
          
          for (const file of toDelete) {
            const filePath = `achievement-icons/${folder.name}/${file.name}`;
            const { error: deleteError } = await supabase.storage
              .from('avatars')
              .remove([filePath]);

            if (deleteError) {
              console.error(`    ❌ Failed to delete ${filePath}:`, deleteError.message);
            } else {
              totalDeleted++;
            }
          }
        }
      }
    }

    offset += batchSize;
    
    // Safety check - don't run forever
    if (offset > 100000) {
      console.log('Safety limit reached, stopping.');
      break;
    }
  }

  console.log('\n✨ Cleanup complete!');
  console.log(`📊 Checked ${totalChecked} unique achievements`);
  console.log(`🗑️  Deleted ${totalDeleted} duplicate files`);
}

cleanupDuplicateIcons()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('💥 Cleanup failed:', error);
    process.exit(1);
  });
