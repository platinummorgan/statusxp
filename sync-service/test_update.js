import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function testUpdate() {
  console.log('Testing UPDATE with WHERE clause...');
  
  // Find a game title
  const { data: game, error: selectError } = await supabase
    .from('game_titles')
    .select('id, name, cover_url')
    .limit(1)
    .single();
  
  if (selectError) {
    console.error('Error selecting game:', selectError);
    return;
  }
  
  console.log('Found game:', game);
  
  // Try to update it
  const { data, error } = await supabase
    .from('game_titles')
    .update({ cover_url: game.cover_url || 'test_url' })
    .eq('id', game.id);
  
  if (error) {
    console.error('❌ UPDATE ERROR:', error);
  } else {
    console.log('✅ UPDATE succeeded');
  }
}

testUpdate().catch(console.error);
