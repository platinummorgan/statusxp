-- SQL function to get user completion counts for achievements
CREATE OR REPLACE FUNCTION get_user_completions(p_user_id UUID)
RETURNS TABLE (
  xbox_complete INT,
  steam_perfect INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(CASE WHEN pl.code = 'XBOXONE' AND ug.completion_percent = 100 THEN 1 END)::INT as xbox_complete,
    COUNT(CASE WHEN pl.code IN ('Steam') AND ug.completion_percent = 100 THEN 1 END)::INT as steam_perfect
  FROM user_games ug
  JOIN platforms pl ON ug.platform_id = pl.id
  WHERE ug.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;
