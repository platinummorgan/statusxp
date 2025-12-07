-- Backfill is_platinum and include_in_score for existing PSN achievements

UPDATE achievements
SET 
  is_platinum = (psn_trophy_type = 'platinum'),
  include_in_score = (psn_trophy_type != 'platinum' OR psn_trophy_type IS NULL)
WHERE platform = 'psn'
  AND (is_platinum IS NULL OR include_in_score IS NULL);

-- Verify the update
SELECT 
  COUNT(*) as total_psn,
  COUNT(*) FILTER (WHERE psn_trophy_type = 'platinum') as platinums_by_type,
  COUNT(*) FILTER (WHERE is_platinum = true) as platinums_by_flag
FROM achievements
WHERE platform = 'psn';
