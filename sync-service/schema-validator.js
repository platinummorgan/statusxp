/**
 * Validates database schema before sync starts
 * Prevents silent failures from column mismatches
 */

export async function validateUserProgressSchema(supabase) {
  console.log('🔍 Validating user_progress schema...');
  
  // Try to query with all expected columns
  const { data, error } = await supabase
    .from('user_progress')
    .select('user_id, platform_id, platform_game_id, achievements_earned, total_achievements, completion_percentage, metadata, synced_at')
    .limit(1);
  
  if (error) {
    console.error('❌ SCHEMA VALIDATION FAILED:', error);
    console.error('💡 Code expects columns that don\'t exist in database');
    throw new Error(`Schema validation failed: ${error.message}`);
  }
  
  console.log('✅ Schema validation passed');
  return true;
}
