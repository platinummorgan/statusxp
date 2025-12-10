-- Add AI guide columns to achievements table
-- This allows caching of AI-generated achievement guides

-- Add column for AI-generated guide text
ALTER TABLE achievements 
ADD COLUMN IF NOT EXISTS ai_guide TEXT;

-- Add column to track when the guide was generated
ALTER TABLE achievements 
ADD COLUMN IF NOT EXISTS ai_guide_generated_at TIMESTAMPTZ;

-- Add column for YouTube video ID (optional)
ALTER TABLE achievements 
ADD COLUMN IF NOT EXISTS youtube_video_id TEXT;

-- Add index for querying achievements that have guides
CREATE INDEX IF NOT EXISTS idx_achievements_ai_guide 
ON achievements(ai_guide_generated_at) 
WHERE ai_guide IS NOT NULL;

-- Add comment to explain the columns
COMMENT ON COLUMN achievements.ai_guide IS 'AI-generated guide text explaining how to unlock this achievement';
COMMENT ON COLUMN achievements.ai_guide_generated_at IS 'Timestamp when the AI guide was generated';
COMMENT ON COLUMN achievements.youtube_video_id IS 'YouTube video ID for video guide (optional)';
