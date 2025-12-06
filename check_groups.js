import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = 'https://ksriqcmumjkemtfjuedm.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MTQxODQsImV4cCI6MjA4MDI5MDE4NH0.svxzehEtMDUQjF-stp7GL_LmRKQOFu_6PxI0IgbLVoQ';

const supabase = createClient(supabaseUrl, supabaseKey);

// Query to check DLC groups
const { data, error } = await supabase.rpc('check_dlc_groups');

if (error) {
  console.error('Error:', error);
} else {
  console.log('Games with DLC trophy groups:');
  console.table(data);
}

// Alternative: Direct SQL query
const query = `
SELECT 
  gt.title,
  gt.psn_has_trophy_groups,
  COUNT(DISTINCT t.psn_trophy_group_id) as trophy_group_count,
  STRING_AGG(DISTINCT t.psn_trophy_group_id, ', ' ORDER BY t.psn_trophy_group_id) as groups,
  COUNT(t.id) as total_trophies
FROM game_titles gt
LEFT JOIN trophies t ON t.game_title_id = gt.id
WHERE gt.id IN (
  SELECT game_title_id 
  FROM trophies 
  GROUP BY game_title_id 
  HAVING COUNT(DISTINCT psn_trophy_group_id) > 1
)
GROUP BY gt.id, gt.title, gt.psn_has_trophy_groups
ORDER BY trophy_group_count DESC, total_trophies DESC
LIMIT 20;
`;

console.log('\nRunning query...');
const { data: results, error: queryError } = await supabase.rpc('exec_sql', { sql: query });
console.log(results || queryError);
