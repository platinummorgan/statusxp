/**
 * Activity Feed Generation
 * 
 * Generates AI-powered stories for the activity feed based on user stat changes
 */

import OpenAI from 'openai';

// Lazy initialization - only create OpenAI client if API key exists
let openai = null;
function getOpenAIClient() {
  if (!process.env.OPENAI_API_KEY) {
    return null;
  }
  if (!openai) {
    openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }
  return openai;
}

/**
 * Generate AI story for a stat change
 */
export async function generateActivityStory(username, change) {
  const client = getOpenAIClient();
  
  // If no OpenAI API key, fallback to template stories immediately
  if (!client) {
    console.warn('⚠️  OPENAI_API_KEY not set - using template stories instead');
    return {
      success: false,
      story: buildTemplateStory(username, change),
      model: null,
      error: 'OPENAI_API_KEY not configured'
    };
  }
  
  const prompt = buildPrompt(username, change);
  
  try {
    const response = await client.chat.completions.create({
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
    
    const storyText = sanitizeStoryText(response.choices[0].message.content.trim());
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
      if (gameTitle === 'Multiple games' || amount > 1) {
        return `${username} just added ${amount} platinum trophies across multiple games.
                Platinum count increased from ${oldValue} to ${newValue}.
                Write an enthusiastic announcement that is flashy but clear this was ACROSS MULTIPLE GAMES, not one title.
                Keep the before/after values.`;
      }
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
      
      let rarityInfo = '';
      if (change.rareTrophies && change.rareTrophies.length > 0) {
        const rarest = change.rareTrophies[0]; // Get the rarest one
        rarityInfo = ` INCLUDING A RARE ${rarest.type?.toUpperCase()} trophy "${rarest.name}" (${rarest.rarity}% rarity)!`;
      }
      
      return `${username} earned ${trophyList} trophies in ${gameTitle}${rarityInfo}.
              Gold: ${change.oldGold} → ${change.oldGold + change.goldCount}
              Silver: ${change.oldSilver} → ${change.oldSilver + change.silverCount}
              Bronze: ${change.oldBronze} → ${change.oldBronze + change.bronzeCount}
              ${rarityInfo ? 'IMPORTANT: Call out the rare trophy with excitement! Use emojis like 🔥 💎 ⚡ for ultra-rare (<5%).' : ''}
              Write a celebratory announcement mentioning the trophy types${rarityInfo ? ' and ESPECIALLY the rare trophy' : ''}.
              Examples:
              - "${username} snagged 15 Bronze trophies in God of War! (0 → 15)"
              - "Trophy hunt! ${username} grabbed 2 Gold, 5 Silver in Elden Ring!"
              ${rarityInfo ? '- "Holy grind! ${username} got 4 Bronze + an ULTRA RARE Silver (0.8%!) in Dark Souls 🔥"' : ''}
              - "${username} cleaned up! 1 Gold, 3 Silver, 10 Bronze in Dishonored."`;
              
    case 'gamerscore_gain':
      const gameContext = gameTitle ? ` in ${gameTitle}` : '';
      if (typeof change.statusxpChange === 'number') {
        return `${username} increased their Xbox Gamerscore from ${oldValue} to ${newValue} (+${amount})${gameContext}, and gained ${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew}).
                Write a celebratory announcement with gaming personality.
                MUST include BOTH Gamerscore change and StatusXP change with before/after values.
                Examples:
                - "${username} jumped 500 Gamerscore (6000 → 6500) in Halo Infinite and earned 120 StatusXP (10,120 → 10,240)!"
                - "Xbox grind! ${username} gained 250 Gamerscore in Forza and +63 StatusXP!"`;
      }
      return `${username} increased their Xbox Gamerscore from ${oldValue} to ${newValue} (+${amount})${gameContext}.
              Write a celebratory announcement with gaming personality.
              MUST include before/after values and game title if provided.
              Examples:
              - "${username} jumped 500 Gamerscore (6000 → 6500) in Halo Infinite!"
              - "Xbox grind! ${username} gained 250 Gamerscore in Forza Horizon (15k → 15,250)!"`;
              
    case 'steam_achievement_gain':
      const steamGameContext = gameTitle ? ` in ${gameTitle}` : '';
      if (typeof change.statusxpChange === 'number') {
        return `${username} earned ${amount} Steam achievements${steamGameContext} (${oldValue} → ${newValue}), gaining ${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew}).
                Write a fun announcement mentioning BOTH Steam achievements and StatusXP gain.
                MUST include before/after values.
                Examples:
                - "${username} unlocked ${amount} Steam achievements in Elden Ring and earned ${change.statusxpChange} StatusXP!"
                - "Steam grind! ${username} added ${amount} achievements in Baldur's Gate 3 (${oldValue} → ${newValue}) +${change.statusxpChange} StatusXP."`;
      }
      return `${username} earned ${amount} Steam achievements${steamGameContext}.
              Total achievements: ${oldValue} → ${newValue}.
              Write a short, fun announcement with before/after values and game title if provided.
              Examples:
              - "${username} unlocked ${amount} Steam achievements in Elden Ring! (${oldValue} → ${newValue})"
              - "Steam grind! ${username} added ${amount} more achievements in Baldur's Gate 3!"`;
    
    case 'trophy_with_statusxp':
      const trophyParts2 = [];
      if (change.goldCount > 0) trophyParts2.push(`${change.goldCount} Gold`);
      if (change.silverCount > 0) trophyParts2.push(`${change.silverCount} Silver`);
      if (change.bronzeCount > 0) trophyParts2.push(`${change.bronzeCount} Bronze`);
      const trophyList2 = trophyParts2.join(', ');
      const hasPlatinumMilestone = typeof change.platinumChange === 'number' && change.platinumChange > 0;
      
      let rarityInfo2 = '';
      if (change.rareTrophies && change.rareTrophies.length > 0) {
        const rarest2 = change.rareTrophies[0];
        rarityInfo2 = ` INCLUDING A RARE ${rarest2.type?.toUpperCase()} "${rarest2.name}" (${rarest2.rarity}% rarity)`;
      }
      
      if (gameTitle === 'Multiple games' || (typeof change.gameCount === 'number' && change.gameCount > 1)) {
        return `${username} earned ${trophyList2} trophies across ${change.gameCount || 'multiple'} games${rarityInfo2}, gaining ${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew}).${hasPlatinumMilestone ? ` They also moved platinum count (${change.platinumOld} → ${change.platinumNew}).` : ''}
                IMPORTANT: Do NOT name a single game as if all trophies came from that one game.
                Make it clear this was a multi-game sync burst.
                ${rarityInfo2 ? 'Call out the rare trophy with enthusiasm.' : ''}
                Write a punchy, social feed style line.`;
      }
      return `${username} earned ${trophyList2} trophies in ${gameTitle}${rarityInfo2}, gaining ${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew}).${hasPlatinumMilestone ? ` They also moved platinum count (${change.platinumOld} → ${change.platinumNew}).` : ''}
              Trophy counts - Gold: ${change.oldGold} → ${change.oldGold + change.goldCount}, Silver: ${change.oldSilver} → ${change.oldSilver + change.silverCount}, Bronze: ${change.oldBronze} → ${change.oldBronze + change.bronzeCount}
              ${hasPlatinumMilestone ? `Platinum count changed: ${change.platinumOld} → ${change.platinumNew}` : ''}
              ${rarityInfo2 ? 'IMPORTANT: Call out the rare trophy with enthusiasm! Use emojis like 🔥 💎 ⚡ for ultra-rare (<5%).' : ''}
              Write a celebratory announcement mentioning BOTH trophy details${rarityInfo2 ? ' (ESPECIALLY the rare one)' : ''} AND StatusXP gain.${hasPlatinumMilestone ? ' Also mention the platinum milestone in the same single story.' : ''}
              Examples:
              - "${username} snagged 8 Bronze in Nexomon: Extinction, earning 13 StatusXP (59,239 → 59,252)!"
              - "Trophy spree! ${username} got 5 Silver, 10 Bronze in Elden Ring for 247 StatusXP (12k → 12.2k)!"
              ${hasPlatinumMilestone ? `- "${username} cleaned up in ${gameTitle}: ${trophyList2} plus a platinum bump (${change.platinumOld} → ${change.platinumNew}) and +${change.statusxpChange} StatusXP!"` : ''}
              ${rarityInfo2 ? '- "LEGENDARY! ${username} got 4 Bronze + an ULTRA RARE Silver (0.3%!) 🔥 Earned 156 StatusXP in Dark Souls!"' : ''}
              - "${username} cleaned up! 2 Gold, 3 Silver in Dishonored netted 189 StatusXP!"`;
    
    case 'gamerscore_with_statusxp':
      const xboxGameContext = gameTitle ? ` in ${gameTitle}` : '';
      return `${username} increased their Xbox Gamerscore from ${oldValue} to ${newValue} (+${amount})${xboxGameContext}, gaining ${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew}).
              Write a celebratory announcement mentioning BOTH Gamerscore, game title (if provided), AND StatusXP gain.
              Examples:
              - "${username} jumped 500 Gamerscore in Halo Infinite for 125 StatusXP (6000G → 6500G)!"
              - "Xbox grind! ${username} gained 250G in Forza and 63 StatusXP!"`;
    
    case 'steam_with_statusxp':
      const steamCombinedContext = gameTitle ? ` in ${gameTitle}` : '';
      return `${username} earned ${amount} Steam achievements${steamCombinedContext} (${oldValue} → ${newValue}), gaining ${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew}).
              Write a fun announcement mentioning BOTH Steam achievements, game title (if provided), AND StatusXP gain.
              Examples:
              - "${username} unlocked ${amount} Steam achievements in Elden Ring for ${change.statusxpChange} StatusXP!"
              - "Steam grind! ${username} added ${amount} achievements in Baldur's Gate 3, earning ${change.statusxpChange} StatusXP!"`;
              
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
      if (change.gameTitle === 'Multiple games' || change.change > 1) {
        return `${username} added ${change.change} platinum trophies across multiple games (${change.oldValue} → ${change.newValue})`;
      }
      return `${username} earned their ${getOrdinal(change.newValue)} platinum in ${change.gameTitle}`;
      
    case 'trophy_detail':
      const trophyParts3 = [];
      if (change.goldCount > 0) trophyParts3.push(`${change.goldCount} Gold`);
      if (change.silverCount > 0) trophyParts3.push(`${change.silverCount} Silver`);
      if (change.bronzeCount > 0) trophyParts3.push(`${change.bronzeCount} Bronze`);
      let rareSuffix = '';
      if (change.rareTrophies && change.rareTrophies.length > 0) {
        const rarest = change.rareTrophies[0];
        rareSuffix = ` including a rare ${rarest.type} (${rarest.rarity}%)`;
      }
      return `${username} earned ${trophyParts3.join(', ')} in ${change.gameTitle}${rareSuffix}`;
      
    case 'gamerscore_gain':
      const gameContext2 = change.gameTitle ? ` in ${change.gameTitle}` : '';
      if (typeof change.statusxpChange === 'number') {
        return `${username} gained ${change.change} Gamerscore${gameContext2} and ${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew})`;
      }
      return `${username} increased Gamerscore by ${change.change} (${change.oldValue} → ${change.newValue})${gameContext2}`;
      
    case 'steam_achievement_gain':
      const steamContext = change.gameTitle ? ` in ${change.gameTitle}` : '';
      if (typeof change.statusxpChange === 'number') {
        return `${username} earned ${change.change} Steam achievements${steamContext} and gained ${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew})`;
      }
      return `${username} earned ${change.change} Steam achievements (${change.oldValue} → ${change.newValue})${steamContext}`;
    
    case 'trophy_with_statusxp':
      const trophyParts4 = [];
      if (change.goldCount > 0) trophyParts4.push(`${change.goldCount} Gold`);
      if (change.silverCount > 0) trophyParts4.push(`${change.silverCount} Silver`);
      if (change.bronzeCount > 0) trophyParts4.push(`${change.bronzeCount} Bronze`);
      let rareSuffix2 = '';
      if (change.rareTrophies && change.rareTrophies.length > 0) {
        const rarest = change.rareTrophies[0];
        rareSuffix2 = ` including a rare ${rarest.type} (${rarest.rarity}%)`;
      }
      if (change.gameTitle === 'Multiple games' || (typeof change.gameCount === 'number' && change.gameCount > 1)) {
        if (typeof change.platinumChange === 'number' && change.platinumChange > 0) {
          return `${username} had a massive multi-game sync: ${trophyParts4.join(', ')} trophies, +${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew}), platinums (${change.platinumOld} → ${change.platinumNew})`;
        }
        return `${username} had a massive multi-game sync: ${trophyParts4.join(', ')} trophies and +${change.statusxpChange} StatusXP (${change.statusxpOld} → ${change.statusxpNew})`;
      }
      if (typeof change.platinumChange === 'number' && change.platinumChange > 0) {
        return `${username} earned ${trophyParts4.join(', ')} in ${change.gameTitle}${rareSuffix2}, gained ${change.statusxpChange} StatusXP, and moved platinum count (${change.platinumOld} → ${change.platinumNew})`;
      }
      return `${username} earned ${trophyParts4.join(', ')} in ${change.gameTitle}${rareSuffix2}, gaining ${change.statusxpChange} StatusXP`;
    
    case 'gamerscore_with_statusxp':
      const xboxCombinedContext = change.gameTitle ? ` in ${change.gameTitle}` : '';
      return `${username} gained ${change.change} Gamerscore${xboxCombinedContext} and ${change.statusxpChange} StatusXP`;
    
    case 'steam_with_statusxp':
      const steamCombinedContext2 = change.gameTitle ? ` in ${change.gameTitle}` : '';
      return `${username} earned ${change.change} Steam achievements${steamCombinedContext2} and gained ${change.statusxpChange} StatusXP`;
      
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

function sanitizeStoryText(text) {
  if (!text) return text;
  // Remove wrapping quotes if the model returns a quoted sentence.
  return text.replace(/^["']+/, '').replace(/["']+$/, '').trim();
}
