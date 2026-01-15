-- Fix check_spike_week to use explicit schema
CREATE OR REPLACE FUNCTION public.check_spike_week(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  max_completions_in_week INTEGER;
BEGIN
  -- Use explicit schema reference
  SELECT COUNT(*) INTO max_completions_in_week
  FROM public.user_games
  WHERE user_id = p_user_id
    AND has_platinum = true;
  
  RETURN COALESCE(max_completions_in_week, 0) >= 3;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';
