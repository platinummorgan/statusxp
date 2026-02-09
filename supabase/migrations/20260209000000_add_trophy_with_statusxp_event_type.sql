-- Add trophy_with_statusxp to allowed event types
-- This event type is used for trophy spree stories that combine trophy counts with StatusXP context

ALTER TABLE activity_feed 
DROP CONSTRAINT IF EXISTS activity_feed_event_type_check;
ALTER TABLE activity_feed
ADD CONSTRAINT activity_feed_event_type_check 
CHECK (event_type IN (
  'statusxp_gain',
  'platinum_milestone',
  'gamerscore_gain',
  'trophy_detail',
  'steam_achievement_gain',
  'trophy_with_statusxp'
));
