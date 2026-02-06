/**
 * Activity Feed Generation
 * 
 * Generates AI-powered stories for the activity feed based on user stat changes
 */

import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/**
 * Generate AI story for a stat change
 */
export async function generateActivityStory(username, change) {
  const prompt = buildPrompt(username, change);
  
  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `You are a hype announcer for StatusXP, a gaming achievement tracker. 
                    Generate short, enthusiastic social media posts about user accomplishments.
                    Keep it casual, fun, and varied - no two posts should sound identical.
                    Use emojis sparingly (0-1 per post). Max 150 characters.
                    ALWAYS include before/after values in parentheses like (6000 → 6500).`
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.9, // High creativity for variety
      max_tokens: 60,
    });
    
    const storyText = response.choices[0].message.content.trim();
    return {
      success: true,
      story: storyText,
      model: 'gpt-4o-mini'
    };
  } catch (error) {
    console.error('❌ AI generation failed:', error.message);
    return {
      success: false,
      story: buildTemplateStory(username, change),
      model: null,
      error: error.message
    };
  }
}

/**
 * Build AI prompt based on change type
 */
function buildPrompt(username, change) {
  const { type, oldValue, newValue, change: amount, changeType, gameTitle } = change;
  
  switch (type) {
    case 'statusxp_gain':
      return `${username} just gained ${amount} StatusXP (${oldValue} → ${newValue}).
              Change magnitude: ${changeType}.
              ALWAYS include before/after values in parentheses.
              Write a ${changeType === 'massive' ? 'very exciting' : 'upbeat'} announcement.
              Examples of tone:
              - Small: "Nice! ${username} added 47 StatusXP (5,234 → 5,281)."
              - Large: "${username} is crushing it! 🔥 Gained 847 StatusXP (10,500 → 11,347)!"
              - Massive: "WHOA! ${username} just EXPLODED with 2,134 StatusXP (15k → 17k)!"`;
              
    case 'platinum_milestone':
      const ordinal = getOrdinal(newValue);
      const isMilestone = isMilestoneNumber(newValue);
      return `${username} just earned their ${ordinal} platinum trophy in ${gameTitle}.
              Platinum count increased from ${oldValue} to ${newValue}.
              Write an enthusiastic announcement celebrating this ${isMilestone ? 'SPECIAL milestone' : 'achievement'}.
              Examples:
              - Regular: "${username} platinumed ${gameTitle}! That's #${newValue}! 🏆"
              - Milestone (100th): "HUGE MILESTONE! ${username} just got their 100TH PLATINUM in ${gameTitle}! 🎉"`;
              
    case 'trophy_detail':
      const trophyParts = [];
      if (change.goldCount > 0) trophyParts.push(`${change.goldCount} Gold`);
      if (change.silverCount > 0) trophyParts.push(`${change.silverCount} Silver`);
      if (change.bronzeCount > 0) trophyParts.push(`${change.bronzeCount} Bronze`);
      const trophyList = trophyParts.join(', ');
      
      return `${username} earned ${trophyList} trophies in ${gameTitle}.
              Gold: ${change.oldGold} → ${change.oldGold + change.goldCount}
              Silver: ${change.oldSilver} → ${change.oldSilver + change.silverCount}
              Bronze: ${change.oldBronze} → ${change.oldBronze + change.bronzeCount}
              Write a celebratory announcement mentioning the trophy types.
              Examples:
              - "${username} snagged 15 Bronze trophies in God of War! (0 → 15)"
              - "Trophy hunt! ${username} grabbed 2 Gold, 5 Silver in Elden Ring!"
              - "${username} cleaned up! 1 Gold, 3 Silver, 10 Bronze in Dishonored."`;
              
    case 'gamerscore_gain':
      return `${username} increased their Xbox Gamerscore from ${oldValue} to ${newValue} (+${amount}).
              Write a celebratory announcement with gaming personality.
              MUST include before/after values.
              Examples:
              - "${username} jumped 500 Gamerscore (6000 → 6500). Keep grinding!"
              - "Xbox grind! ${username} gained 250 Gamerscore (15k → 15,250)!"`;
              
    case 'steam_achievement_gain':
      return `${username} earned ${amount} Steam achievements.
              Total achievements: ${oldValue} → ${newValue}.
              Write a short, fun announcement with before/after values.
              Examples:
              - "${username} unlocked ${amount} Steam achievements! (${oldValue} → ${newValue})"
              - "Steam grind! ${username} added ${amount} more achievements."`;
              
    default:
      return `${username} accomplished something in StatusXP. Write a short, fun announcement.`;
  }
}

/**
 * Fallback template if AI fails
 */
function buildTemplateStory(username, change) {
  switch (change.type) {
    case 'statusxp_gain':
      return `${username} gained ${change.change} StatusXP (${change.oldValue} → ${change.newValue})`;
      
    case 'platinum_milestone':
      return `${username} earned their ${getOrdinal(change.newValue)} platinum in ${change.gameTitle}`;
      
    case 'trophy_detail':
      const trophyParts = [];
      if (change.goldCount > 0) trophyParts.push(`${change.goldCount} Gold`);
      if (change.silverCount > 0) trophyParts.push(`${change.silverCount} Silver`);
      if (change.bronzeCount > 0) trophyParts.push(`${change.bronzeCount} Bronze`);
      return `${username} earned ${trophyParts.join(', ')} in ${change.gameTitle}`;
      
    case 'gamerscore_gain':
      return `${username} increased Gamerscore by ${change.change} (${change.oldValue} → ${change.newValue})`;
      
    case 'steam_achievement_gain':
      return `${username} earned ${change.change} Steam achievements (${change.oldValue} → ${change.newValue})`;
      
    default:
      return `${username} made progress in StatusXP`;
  }
}

/**
 * Helper: Get ordinal suffix (1st, 2nd, 3rd, etc.)
 */
function getOrdinal(num) {
  const suffixes = ['th', 'st', 'nd', 'rd'];
  const v = num % 100;
  return num + (suffixes[(v - 20) % 10] || suffixes[v] || suffixes[0]);
}

/**
 * Helper: Check if number is a milestone (100, 500, 1000, etc.)
 */
function isMilestoneNumber(num) {
  return num % 100 === 0 || num % 50 === 0 || num === 1 || num === 10 || num === 25;
}

/**
 * Categorize change magnitude for AI tone
 */
export function categorizeChange(amount, type) {
  if (type === 'statusxp') {
    if (amount < 100) return 'small';
    if (amount < 500) return 'medium';
    if (amount < 1000) return 'large';
    return 'massive';
  }
  
  if (type === 'gamerscore') {
    if (amount < 100) return 'small';
    if (amount < 500) return 'medium';
    if (amount < 1000) return 'large';
    return 'massive';
  }
  
  if (type === 'steam_achievements') {
    if (amount < 10) return 'small';
    if (amount < 50) return 'medium';
    if (amount < 100) return 'large';
    return 'massive';
  }
  
  return 'medium';
}
