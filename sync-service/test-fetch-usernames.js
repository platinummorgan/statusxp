// Test script to fetch Xbox gamertag and Steam name
// Use environment variables for diagnostic account IDs and credentials.

const XBOX_XUID = process.env.TEST_XBOX_XUID || '';
const STEAM_ID = process.env.TEST_STEAM_ID || '';

// Never store diagnostic credentials in source control.
const XBOX_ACCESS_TOKEN = process.env.TEST_XBOX_ACCESS_TOKEN || '';
const XBOX_USER_HASH = process.env.TEST_XBOX_USER_HASH || '';
const STEAM_API_KEY = process.env.STEAM_WEB_API_KEY || process.env.STEAM_API_KEY || '';

async function testFetchUsernames() {
  // Test Xbox gamertag fetch
  console.log('\n=== Testing Xbox Gamertag Fetch ===');
  try {
    const url = `https://profile.xboxlive.com/users/xuid(${XBOX_XUID})/profile/settings?settings=Gamertag`;
    console.log('URL:', url);
    
    const response = await fetch(url, {
      headers: {
        'Authorization': `XBL3.0 x=${XBOX_USER_HASH};${XBOX_ACCESS_TOKEN}`,
        'x-xbl-contract-version': '2',
      },
    });
    
    console.log('Response status:', response.status);
    const data = await response.json();
    console.log('Response data:', JSON.stringify(data, null, 2));
    
    const gamertagSetting = data.profileUsers?.[0]?.settings?.find(s => s.id === 'Gamertag');
    if (gamertagSetting) {
      console.log('✅ Xbox Gamertag:', gamertagSetting.value);
    } else {
      console.log('❌ Could not find gamertag in response');
    }
  } catch (e) {
    console.error('❌ Xbox fetch error:', e.message);
  }
  
  // Test Steam display name fetch
  console.log('\n=== Testing Steam Display Name Fetch ===');
  try {
    const url = `https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=${STEAM_API_KEY}&steamids=${STEAM_ID}`;
    console.log('URL:', url.replace(STEAM_API_KEY, 'API_KEY_HIDDEN'));
    
    const response = await fetch(url);
    console.log('Response status:', response.status);
    const data = await response.json();
    console.log('Response data:', JSON.stringify(data, null, 2));
    
    const player = data.response?.players?.[0];
    if (player) {
      console.log('✅ Steam Display Name:', player.personaname);
    } else {
      console.log('❌ Could not find player in response');
    }
  } catch (e) {
    console.error('❌ Steam fetch error:', e.message);
  }
}

testFetchUsernames();
