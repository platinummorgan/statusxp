import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function deleteAllPSNProxies() {
  console.log('Deleting ALL PSN proxy files from storage...\n');
  
  // Get all files
  const { data: files, error: listError } = await supabase.storage
    .from('avatars')
    .list('achievement-icons/psn', {
      limit: 10000
    });
  
  if (listError) {
    console.error('Error listing files:', listError);
    return;
  }
  
  console.log(`Found ${files.length} files to delete\n`);
  
  // Delete in batches
  const batchSize = 100;
  for (let i = 0; i < files.length; i += batchSize) {
    const batch = files.slice(i, i + batchSize);
    const filePaths = batch.map(f => `achievement-icons/psn/${f.name}`);
    
    const { error } = await supabase.storage
      .from('avatars')
      .remove(filePaths);
    
    if (error) {
      console.error(`Error deleting batch ${i}-${i+batch.length}:`, error);
    } else {
      console.log(`Deleted ${filePaths.length} files (${i + filePaths.length}/${files.length})`);
    }
  }
  
  console.log('\n✅ All PSN proxy files deleted');
  
  // Clear database
  console.log('\nClearing proxied_icon_url from database...\n');
  const { error: dbError } = await supabase
    .from('achievements')
    .update({ proxied_icon_url: null })
    .in('platform_id', [1, 2, 5, 9]);
  
  if (dbError) {
    console.error('Database error:', dbError);
  } else {
    console.log('✅ Database cleared');
  }
}

deleteAllPSNProxies();
