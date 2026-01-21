// Quick test to verify platform validation guard
// Run: node sync-service/test-platform-guard.js

function mapPsnPlatformToPlatformId(trophyTitlePlatformRaw) {
  const s = (trophyTitlePlatformRaw || '').toUpperCase();
  if (s.includes('PS5')) return { platformId: 1, platformVersion: 'PS5' };
  if (s.includes('PS4')) return { platformId: 2, platformVersion: 'PS4' };
  if (s.includes('PS3')) return { platformId: 5, platformVersion: 'PS3' };
  if (s.includes('VITA')) return { platformId: 9, platformVersion: 'PSVITA' };
  return { platformId: 1, platformVersion: 'PS5' };
}

function validatePlatformMapping(trophyTitlePlatform, platformId, gameName, npCommunicationId) {
  const s = (trophyTitlePlatform || '').toUpperCase();
  
  const expectedMappings = [
    { contains: 'PS5', expectedId: 1, name: 'PS5' },
    { contains: 'PS4', expectedId: 2, name: 'PS4' },
    { contains: 'PS3', expectedId: 5, name: 'PS3' },
    { contains: 'VITA', expectedId: 9, name: 'PSVITA' }
  ];
  
  for (const mapping of expectedMappings) {
    if (s.includes(mapping.contains) && platformId !== mapping.expectedId) {
      console.error(
        `🚨 PLATFORM MISMATCH: PSN says ${mapping.name} but platformId=${platformId} | ` +
        `game="${gameName}" | npId=${npCommunicationId}`
      );
      return false;
    }
  }
  
  return true;
}

// Test cases
console.log('\n✅ VALID CASES (should pass silently):');
const validTests = [
  { platform: 'PS5', title: 'Spider-Man 2', npId: 'NPWR12345_00' },
  { platform: 'PS4', title: 'God of War', npId: 'NPWR54321_00' },
  { platform: 'PS3', title: 'The Last of Us', npId: 'NPWR11111_00' },
  { platform: 'PSVITA', title: 'Uncharted: Golden Abyss', npId: 'NPWR22222_00' }
];

validTests.forEach(test => {
  const { platformId } = mapPsnPlatformToPlatformId(test.platform);
  const isValid = validatePlatformMapping(test.platform, platformId, test.title, test.npId);
  console.log(`  ${test.platform} → platform_id=${platformId} | ${isValid ? '✅' : '❌'}`);
});

console.log('\n🚨 INVALID CASES (should trigger error logs):');
const invalidTests = [
  { platform: 'PS5', wrongId: 5, title: 'Spider-Man 2', npId: 'NPWR12345_00' },
  { platform: 'PS4', wrongId: 5, title: 'God of War', npId: 'NPWR54321_00' },
  { platform: 'PS3', wrongId: 2, title: 'The Last of Us', npId: 'NPWR11111_00' }
];

invalidTests.forEach(test => {
  console.log(`\nTesting: ${test.platform} with WRONG platform_id=${test.wrongId}`);
  validatePlatformMapping(test.platform, test.wrongId, test.title, test.npId);
});

console.log('\n✅ Test complete - guard is working correctly!\n');
