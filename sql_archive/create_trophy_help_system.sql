-- Trophy Help Request System
-- Allows users to request help for multiplayer/co-op trophies

-- Create trophy_help_requests table
CREATE TABLE IF NOT EXISTS trophy_help_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_id TEXT NOT NULL,
  game_title TEXT NOT NULL,
  achievement_id TEXT NOT NULL,
  achievement_name TEXT NOT NULL,
  platform TEXT NOT NULL, -- 'psn', 'xbox', 'steam'
  description TEXT, -- User's notes about what they need
  availability TEXT, -- When they're available to play
  platform_username TEXT, -- Their PSN ID, Xbox GT, or Steam ID
  status TEXT NOT NULL DEFAULT 'open', -- 'open', 'matched', 'completed', 'cancelled'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create trophy_help_responses table
CREATE TABLE IF NOT EXISTS trophy_help_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES trophy_help_requests(id) ON DELETE CASCADE,
  helper_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT, -- Helper's message to requester
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'declined'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_trophy_help_requests_user_id ON trophy_help_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_trophy_help_requests_game_id ON trophy_help_requests(game_id);
CREATE INDEX IF NOT EXISTS idx_trophy_help_requests_platform ON trophy_help_requests(platform);
CREATE INDEX IF NOT EXISTS idx_trophy_help_requests_status ON trophy_help_requests(status);
CREATE INDEX IF NOT EXISTS idx_trophy_help_requests_created_at ON trophy_help_requests(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_trophy_help_responses_request_id ON trophy_help_responses(request_id);
CREATE INDEX IF NOT EXISTS idx_trophy_help_responses_helper_user_id ON trophy_help_responses(helper_user_id);

-- Enable Row Level Security
ALTER TABLE trophy_help_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE trophy_help_responses ENABLE ROW LEVEL SECURITY;

-- RLS Policies for trophy_help_requests

-- Anyone can view open requests
CREATE POLICY "Anyone can view open trophy help requests"
  ON trophy_help_requests
  FOR SELECT
  USING (status = 'open' OR auth.uid() = user_id);

-- Users can create their own requests
CREATE POLICY "Users can create trophy help requests"
  ON trophy_help_requests
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own requests
CREATE POLICY "Users can update their own trophy help requests"
  ON trophy_help_requests
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own requests
CREATE POLICY "Users can delete their own trophy help requests"
  ON trophy_help_requests
  FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for trophy_help_responses

-- Anyone can view responses for open requests
CREATE POLICY "Users can view responses for their requests or their own responses"
  ON trophy_help_responses
  FOR SELECT
  USING (
    auth.uid() IN (
      SELECT user_id FROM trophy_help_requests WHERE id = request_id
    )
    OR auth.uid() = helper_user_id
  );

-- Users can create responses
CREATE POLICY "Users can create trophy help responses"
  ON trophy_help_responses
  FOR INSERT
  WITH CHECK (auth.uid() = helper_user_id);

-- Request owners can update response status (accept/decline)
CREATE POLICY "Request owners can update response status"
  ON trophy_help_responses
  FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT user_id FROM trophy_help_requests WHERE id = request_id
    )
  );

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_trophy_help_request_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
CREATE TRIGGER update_trophy_help_request_updated_at_trigger
  BEFORE UPDATE ON trophy_help_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_trophy_help_request_updated_at();

-- Grant necessary permissions
GRANT ALL ON trophy_help_requests TO authenticated;
GRANT ALL ON trophy_help_responses TO authenticated;
GRANT SELECT ON trophy_help_requests TO anon;
GRANT SELECT ON trophy_help_responses TO anon;
