-- Drop display_case_items and related objects
-- Date: 2026-01-25

BEGIN;

-- Drop trigger and policy if table still exists (check existence first)
DO $$ BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'display_case_items') THEN
    DROP TRIGGER IF EXISTS trigger_update_display_case_items_updated_at ON public.display_case_items;
    DROP POLICY IF EXISTS display_case_items_user_policy ON public.display_case_items;
    DROP TABLE IF EXISTS public.display_case_items CASCADE;
  END IF;
END $$;

-- Drop helper function
DROP FUNCTION IF EXISTS public.update_display_case_items_updated_at();

COMMIT;
