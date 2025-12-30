-- Fix user_ai_daily_usage table: Add source column if it doesn't exist
-- This fixes the "column 'source' does not exist" error for premium users

-- Add source column if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'user_ai_daily_usage' 
        AND column_name = 'source'
    ) THEN
        ALTER TABLE user_ai_daily_usage 
        ADD COLUMN source TEXT CHECK (source IN ('daily_free', 'pack', 'premium'));
        
        -- Update existing rows to have 'daily_free' as default
        UPDATE user_ai_daily_usage 
        SET source = 'daily_free' 
        WHERE source IS NULL;
    END IF;
END $$;
