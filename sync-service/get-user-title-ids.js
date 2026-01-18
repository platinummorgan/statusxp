import { createClient } from '@supabase/supabase-js';
import 'dotenv/config';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Get user's title history with all title IDs
async function getUserTitleIds(userId) {
  // Get auth tokens
  const { data: profile } = await supabase
    .from('profiles')
    .select('xbox_xuid, xbox_user_hash, xbox_access_token')
    .eq('id', userId)
    .single();

  if (!profile || !profile.xbox_xuid) {
    throw new Error('User not found or Xbox not linked');
  }

  const { xbox_xuid: xuid, xbox_user_hash: userHash, xbox_access_token: token } = profile;

  // Fetch title history
  const response = await fetch(
    `https://titlehub.xboxlive.com/users/xuid(${xuid})/titles/titlehistory/decoration/achievement`,
    {
      headers: {
        'x-xbl-contract-version': '2',
        'Accept-Language': 'en-US',
        Authorization: `XBL3.0 x=${userHash};${token}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Xbox API error: ${response.status}`);
  }

  const data = await response.json();
  const titles = data.titles || [];

  console.log(`\nFound ${titles.length} total games\n`);
  console.log('Game Name → Title ID');
  console.log('='.repeat(60));

  const titleMap = {};
  for (const title of titles) {
    console.log(`${title.name} → ${title.titleId}`);
    titleMap[title.name] = title.titleId;
  }

  return titleMap;
}

// Usage: node get-user-title-ids.js [user_id]
const userId = process.argv[2] || '8fef7fd4-581d-4ef9-9d48-482eff31c69d';
getUserTitleIds(userId).catch(console.error);
