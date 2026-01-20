// ============================================================================
// IGDB Game Platform Validator
// ============================================================================
// Validates game platforms against IGDB API to prevent backwards compat issues

import fetch from 'node-fetch';

// IGDB Platform IDs mapped to our platform_ids
const IGDB_PLATFORM_MAP = {
  // PlayStation
  48: 2,   // PS4 → platform_id 2
  167: 1,  // PS5 → platform_id 1
  9: 5,    // PS3 → platform_id 5
  46: 9,   // PSVita → platform_id 9
  
  // Xbox
  12: 10,  // Xbox 360 → platform_id 10
  49: 11,  // Xbox One → platform_id 11
  169: 12, // Xbox Series X|S → platform_id 12
  
  // NOTE: PC (IGDB ID 6) intentionally NOT mapped to avoid conflicts with PS3 (platform_id 5)
  // PC platforms are filtered out during PlayStation/Xbox syncs
};

// Platform families for filtering IGDB results
const PLAYSTATION_PLATFORMS = [1, 2, 5, 9]; // PS5, PS4, PS3, Vita
const XBOX_PLATFORMS = [10, 11, 12]; // 360, One, Series X

const PLATFORM_PRIORITY = {
  // Lower number = older platform (prioritize older for backwards compat)
  2: 1,   // PS4
  1: 2,   // PS5
  5: 0,   // PS3
  9: 0,   // PSVita
  10: 1,  // Xbox 360
  11: 2,  // Xbox One
  12: 3,  // Xbox Series X
};

class IGDBValidator {
  constructor(clientId, clientSecret) {
    this.clientId = clientId;
    this.clientSecret = clientSecret;
    this.accessToken = null;
    this.tokenExpiry = null;
    this.cache = new Map(); // Cache game platform lookups
  }

  async authenticate() {
    if (this.accessToken && this.tokenExpiry && Date.now() < this.tokenExpiry) {
      return this.accessToken;
    }

    try {
      const response = await fetch(
        `https://id.twitch.tv/oauth2/token?client_id=${this.clientId}&client_secret=${this.clientSecret}&grant_type=client_credentials`,
        { method: 'POST' }
      );

      const data = await response.json();
      this.accessToken = data.access_token;
      this.tokenExpiry = Date.now() + (data.expires_in * 1000) - 60000; // Refresh 1 min early
      
      return this.accessToken;
    } catch (error) {
      console.error('❌ IGDB authentication failed:', error.message);
      return null;
    }
  }

  async queryGame(gameName) {
    // Check cache first
    if (this.cache.has(gameName)) {
      return this.cache.get(gameName);
    }

    const token = await this.authenticate();
    if (!token) {
      return null;
    }

    try {
      const query = `
        search "${gameName}";
        fields name, platforms;
        limit 1;
      `;

      const response = await fetch('https://api.igdb.com/v4/games', {
        method: 'POST',
        headers: {
          'Client-ID': this.clientId,
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'text/plain',
        },
        body: query,
      });

      const games = await response.json();
      
      if (!games || games.length === 0) {
        console.log(`⚠️  IGDB: No match found for "${gameName}"`);
        return null;
      }

      const game = games[0];
      const result = {
        name: game.name,
        igdbPlatforms: game.platforms || [],
        ourPlatforms: (game.platforms || [])
          .map(igdbId => IGDB_PLATFORM_MAP[igdbId])
          .filter(id => id !== undefined),
      };

      // Cache result
      this.cache.set(gameName, result);
      
      return result;
    } catch (error) {
      console.error('❌ IGDB query failed:', error.message);
      return null;
    }
  }

  /**
   * Validates if a platform_id is correct for a game
   * Returns the correct platform_id to use (oldest available if multiple)
   * @param {string} gameName - Name of the game
   * @param {number} detectedPlatformId - Platform detected by sync service
   * @param {string} platformFamily - 'playstation' or 'xbox' to filter results
   */
  async validatePlatform(gameName, detectedPlatformId, platformFamily = 'playstation') {
    const igdbResult = await this.queryGame(gameName);
    
    if (!igdbResult || igdbResult.ourPlatforms.length === 0) {
      console.log(`⚠️  IGDB: No platform data for "${gameName}", using detected platform ${detectedPlatformId}`);
      return detectedPlatformId; // Fallback to detected platform
    }

    // Filter platforms by family (remove PC/other consoles)
    const familyPlatforms = platformFamily === 'playstation' ? PLAYSTATION_PLATFORMS : XBOX_PLATFORMS;
    const filteredPlatforms = igdbResult.ourPlatforms.filter(id => familyPlatforms.includes(id));
    
    if (filteredPlatforms.length === 0) {
      console.log(`⚠️  IGDB: "${gameName}" has no ${platformFamily} platforms in IGDB, using detected ${detectedPlatformId}`);
      return detectedPlatformId;
    }

    // Check if detected platform is in filtered list
    if (filteredPlatforms.includes(detectedPlatformId)) {
      console.log(`✅ IGDB: "${gameName}" confirmed on platform ${detectedPlatformId}`);
      
      // Don't do backwards compat here - that's handled by the sync service
      // Just confirm the game exists on the detected platform
      return detectedPlatformId;
    }

    // Detected platform NOT in IGDB filtered list
    const correctPlatform = this.getOldestPlatform(filteredPlatforms, null);
    
    // Sanity check: Only allow platform changes that represent ACTUAL backwards compatibility
    // PS4/PS3/Vita have NO backwards compat with each other (different architectures)
    const allowedBackwardsCompat = {
      1: [2],         // PS5 can play PS4 games (native backwards compat)
      12: [11, 10],   // Series X can play One and 360 games
      11: [10]        // Xbox One can play 360 games
      // PS4, PS3, Vita: NO entries = NO backwards compat allowed
    };
    
    const validBackwardsCompatPlatforms = allowedBackwardsCompat[detectedPlatformId] || [];
    if (!validBackwardsCompatPlatforms.includes(correctPlatform)) {
      console.log(`⚠️  IGDB: "${gameName}" found on ${correctPlatform}, but detected as ${detectedPlatformId} - NOT a valid backwards compat platform, using detected platform`);
      console.log(`   IGDB platforms: ${filteredPlatforms.join(', ')}, Detected: ${detectedPlatformId}`);
      return detectedPlatformId;
    }
    
    console.log(`⚠️  IGDB: "${gameName}" not found on platform ${detectedPlatformId}, correcting to ${correctPlatform}`);
    console.log(`   IGDB says ${platformFamily} platforms: ${filteredPlatforms.join(', ')}`);
    
    return correctPlatform;
  }

  /**
   * Get the oldest (lowest priority) platform from a list
   * Prioritizes backwards compatible platforms
   */
  getOldestPlatform(platformIds, currentPlatform) {
    if (platformIds.length === 0) return currentPlatform;
    if (platformIds.length === 1) return platformIds[0];

    // Sort by priority (lower priority number = older platform)
    const sorted = platformIds.sort((a, b) => {
      const priorityA = PLATFORM_PRIORITY[a] ?? 999;
      const priorityB = PLATFORM_PRIORITY[b] ?? 999;
      return priorityA - priorityB;
    });

    return sorted[0];
  }

  clearCache() {
    this.cache.clear();
  }
}

// Singleton instance
let validator = null;

export function initIGDBValidator() {
  const clientId = process.env.IGDB_CLIENT_ID;
  const clientSecret = process.env.IGDB_CLIENT_SECRET;
  
  if (!clientId || !clientSecret) {
    console.warn('⚠️  IGDB credentials not provided, platform validation disabled');
    return null;
  }
  
  validator = new IGDBValidator(clientId, clientSecret);
  return validator;
}

export function getIGDBValidator() {
  return validator;
}
