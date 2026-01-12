-- Add AI guide columns to achievements table for caching generated guides

-- Check if columns exist and add them if they don't
DO $$ 
BEGIN
    -- Add ai_guide column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'achievements' AND column_name = 'ai_guide') THEN
        ALTER TABLE achievements ADD COLUMN ai_guide text;
        COMMENT ON COLUMN achievements.ai_guide IS 'AI-generated guide content for this achievement';
    END IF;
    
    -- Add ai_guide_generated_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'achievements' AND column_name = 'ai_guide_generated_at') THEN
        ALTER TABLE achievements ADD COLUMN ai_guide_generated_at timestamptz;
        COMMENT ON COLUMN achievements.ai_guide_generated_at IS 'Timestamp when AI guide was generated';
    END IF;
END $$;

-- Create index on ai_guide_generated_at for performance
CREATE INDEX IF NOT EXISTS idx_achievements_ai_guide_generated_at 
ON achievements(ai_guide_generated_at) 
WHERE ai_guide_generated_at IS NOT NULL;

-- Create index on ai_guide for performance (partial index for non-null values)
CREATE INDEX IF NOT EXISTS idx_achievements_ai_guide_exists 
ON achievements(id) 
WHERE ai_guide IS NOT NULL AND ai_guide != '';

-- Also add to trophies table for compatibility
DO $$ 
BEGIN
    -- Add ai_guide column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'trophies' AND column_name = 'ai_guide') THEN
        ALTER TABLE trophies ADD COLUMN ai_guide text;
        COMMENT ON COLUMN trophies.ai_guide IS 'AI-generated guide content for this trophy';
    END IF;
    
    -- Add ai_guide_generated_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'trophies' AND column_name = 'ai_guide_generated_at') THEN
        ALTER TABLE trophies ADD COLUMN ai_guide_generated_at timestamptz;
        COMMENT ON COLUMN trophies.ai_guide_generated_at IS 'Timestamp when AI guide was generated';
    END IF;
END $$;

-- Create indexes on trophies table
CREATE INDEX IF NOT EXISTS idx_trophies_ai_guide_generated_at 
ON trophies(ai_guide_generated_at) 
WHERE ai_guide_generated_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_trophies_ai_guide_exists 
ON trophies(id) 
WHERE ai_guide IS NOT NULL AND ai_guide != '';