-- Drop display_case_items and related objects
-- Date: 2026-01-25

BEGIN;

-- Drop trigger and policy if table still exists
DROP TRIGGER IF EXISTS trigger_update_display_case_items_updated_at ON public.display_case_items;
DROP POLICY IF EXISTS display_case_items_user_policy ON public.display_case_items;

-- Drop table (cascades indexes/constraints)
DROP TABLE IF EXISTS public.display_case_items CASCADE;

-- Drop helper function
DROP FUNCTION IF EXISTS public.update_display_case_items_updated_at();

COMMIT;
