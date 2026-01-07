-- Fix the UPDATE statement in mark_game_groups_for_refresh() to include WHERE clause
-- This fixes the "UPDATE requires a WHERE clause" error when inserting game_titles

CREATE OR REPLACE FUNCTION mark_game_groups_for_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE game_groups_refresh_queue SET needs_refresh = true WHERE id = 1;
  RETURN NEW;
END;
$$;
