// Test script to fetch Xbox gamertag and Steam name
// Hard-code values for testing

const XBOX_XUID = '2535444179261763';
const STEAM_ID = '76561198025758586';

// You'll need to provide these from your database
const XBOX_ACCESS_TOKEN = 'eyJlbmMiOiJBMTI4Q0JDK0hTMjU2IiwiYWxnIjoiUlNBLU9BRVAiLCJjdHkiOiJKV1QiLCJ6aXAiOiJERUYiLCJ4NXQiOiIxZlVBejExYmtpWklFaE5KSVZnSDFTdTVzX2cifQ.dwKBD77HeTYtd9pwBBxFRk-6h6lXzeaY9SHhJazAq8aK36VEjZQed3xh1EUag5OHQYoYRUzj9WAGkCJ2oax22JonEXGsrx86drONsxz-itNUHLoXboMfU-irv72iWykdR-zfan1KhMQdrPC3wRuksmoyoktKyk50LVNwIOhhzFQ.RPedPe40NqzAbB0b2UjHnw.U8-lGXoopTl9udmDi3_EF02xmmPI83Q8pNodCOb6sfp46IQcfqIm_QvJbRHi1p1iCInaTsa_Ble2NdxXOSNg9kdV2McPYMKP1s-lSq7Iz3wm05OVfJ5VfVLOQwngKcoB0Pb3VeIWwrnAt2KY93ggD4vK106H04733Bn0Expm2DTBS-N0Q1cfWKCjp7IY1gpALm1_Xbt5y2-DYQBSl03MMX-6sWK5PIyarEYLn6yO3q2zeMGnqzA0bWa06WVGi31LgGZG5khbTTTrdqg6panE-qiJPzUJXuk5BzDjKXgaHG0GbdmxoDimFBKJZCuNbOfCYRL333Pbs0KLA-NrUfs-bOOELfAzEu8iigEjJOfohXvXb5qgRI8hbZzy6ReWfjFrte7sKvbuBbcBkHG2vRS6HyMfphbSHLnbwbmEn0lPlnhsCvvTA58VR2p9fXCL9PF6vnsL8uzrSSBeL3HgZ9LDgivVz6XwlWgMD2YVVHsCiMW_ZrfWgchTCt1ifQossDmm7FGNKHiIIr992nYMn1j_2Yj2TDpxWWNsxS91v35HUh0qAa-6VCPgur-2n_zdxhi_GfZ_siOm4I7sQ7_V-l9-lvHRxF_PPtPehGmCJF2puzoHPFjvtrD5DDTZbyA0O13JoOoYpGgNikzHbX0eXpLmpvraF2ja51elGAPpQrR84Rn2X3eOFahJRaVjeYQL_g5T0xqKQCSkSRbovZ48sAQy0JCuNWMM8DFc-hg1ovDp9uS_joIQtdbxJbw2J7eqQ6mDQ55xR-ffg-rox-aYQDZaaKeRgynxAkh92BxowFEbRXaXeXMYN3O822QL8mtu5mDwnULS1lRZx02Ax-6tUkOWBWEWaZ1SfOnTmndXu1yn6rI_bFbxkJDI30iNyCwXt4R27C17LS8WGySDoBtDso2YU4JkBsX5UB7xhnfhJz7ws6_1sYQ5ZlW1BnBtxp6yO7DKaTTXg7PN5SWbfmSA7cQOhzkGr4ReQmh6rxZqiDzKWSVbpVgfSDllBHVdh6bPvlI-4ex14tYCl5b5k3JlIpYcc_l7_PLOC1RNI6RrFRXSg7yzTkFk_Gdc7kV5v23hLwBcB1YE-mMBsLFRIerTmCTRdfM-UgkanMJW3ts8ANGqVl3hbWfJN8kayoU_zWKZSywXPgBFFdDvIA1mULehn1xgzKxIND7T8dVqUbn4v0whcNaIJGsVBrSB4NqPrddroxM0U5SgJYNXKMdoYbT9qoQb-vce5YyIJ38cTiFKnwuzHCeQcphxMZVDx9KjllZqYNUQz_UJjJEZ8_1_4KQzU9QVk17IN2-mb9NkPNqf2Na2kAM3CnnhmmlOiMY9Amj32OZp_Ub4YY_TKHCeZp436R2X7oK4ohmpffUQq9mQT6-yiq2Uk3DBZ4dZ7LSTLI6r7apeCWMFJExcw_8Qa26liwobqq57zMZU4KUMRDf6LUm_zAoNIxQJw7O-9NIRzL_XQI78eNWCb3ahiK6ngAD0fsVYPR2woop84L55mrPx8CyG45jILb5pW6ZNEuM91VLmAldAUqYvMjVA_c_pzGUubw-D5uRidHYm6UHs00nsYu1D6QgQcM86ofTFi9ywONx82Hg_.B8UkRv4aZYnpQ5rNZicPQo2hebekK7-sYnEdKFNaqIE';
const XBOX_USER_HASH = '8313158208114727716';
const STEAM_API_KEY = 'D60D536DC10F3158F9BB910EDFB17423';

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
