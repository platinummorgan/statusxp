import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function checkStorageFiles() {
  console.log('Checking for specific file: achievement-icons/psn/0.png\n');
  
  const { data: files, error } = await supabase.storage
    .from('avatars')
    .list('achievement-icons/psn', {
      search: '0.png'
    });
  
  if (error) {
    console.error('Error:', error);
    return;
  }
  
  console.log(`Found ${files.length} file(s):\n`);
  
  files.forEach(file => {
    console.log(`${file.name} - Created: ${file.created_at}, Updated: ${file.updated_at}, Size: ${file.metadata?.size || 'unknown'}`);
  });
}

checkStorageFiles();
