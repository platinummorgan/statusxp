// Test OpenXBL title endpoint for Happy Wars
const titleId = '1761060600';
const apiKey = process.env.OPENXBL_API_KEY;

const response = await fetch(`https://xbl.io/api/v2/achievements/title/${titleId}`, {
  headers: {
    'x-authorization': apiKey,
  },
});

console.log('Status:', response.status);
const data = await response.json();
console.log('Response:', JSON.stringify(data, null, 2));

// Check if achievements have rarity data
if (data.achievements) {
  const withRarity = data.achievements.filter(a => a.rarity).length;
  console.log(`\nAchievements with rarity: ${withRarity}/${data.achievements.length}`);
}
