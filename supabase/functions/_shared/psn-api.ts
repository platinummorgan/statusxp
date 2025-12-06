/**
 * PSN API Client
 * 
 * Implements authentication and trophy data fetching from PlayStation Network.
 * Based on the psn-api library patterns.
 */

const AUTH_BASE_URL = 'https://ca.account.sony.com/api/authz/v3/oauth';
const TROPHY_BASE_URL = 'https://m.np.playstation.com/api/trophy';
const USER_BASE_URL = 'https://m.np.playstation.com/api/userProfile/v1/internal/users';

export interface AuthorizationPayload {
  accessToken: string;
  refreshToken?: string;
  expiresIn?: number;
  tokenType?: string;
}

export interface TrophyTitle {
  npServiceName: 'trophy' | 'trophy2';
  npCommunicationId: string;
  trophySetVersion: string;
  trophyTitleName: string;
  trophyTitleDetail?: string;
  trophyTitleIconUrl: string;
  trophyTitlePlatform: string;
  hasTrophyGroups: boolean;
  definedTrophies: {
    bronze: number;
    silver: number;
    gold: number;
    platinum: number;
  };
  progress?: number;
  earnedTrophies?: {
    bronze: number;
    silver: number;
    gold: number;
    platinum: number;
  };
  lastUpdatedDateTime?: string;
}

export interface Trophy {
  trophyId: number;
  trophyHidden: boolean;
  trophyType: 'bronze' | 'silver' | 'gold' | 'platinum';
  trophyName: string;
  trophyDetail: string;
  trophyIconUrl: string;
  trophyGroupId: string;
  earned?: boolean;
  earnedDateTime?: string;
  trophyEarnedRate?: string;
  trophyRare?: number;
  trophyProgressTargetValue?: string;
}

export interface UserTrophyProfileSummary {
  accountId: string;
  trophyLevel: number;
  progress: number;
  tier: number;
  earnedTrophies: {
    bronze: number;
    silver: number;
    gold: number;
    platinum: number;
  };
}

export interface PSNUserProfile {
  onlineId: string;
  accountId: string;
  npId: string;
  avatarUrls: Array<{
    size: string;
    avatarUrl: string;
  }>;
  plus: number; // 0 or 1
  aboutMe: string;
  languagesUsed: string[];
  isPlus: boolean;
  isOfficiallyVerified: boolean;
}

export interface TrophyGroup {
  trophyGroupId: string;
  trophyGroupName: string;
  trophyGroupDetail: string;
  trophyGroupIconUrl: string;
  definedTrophies: {
    bronze: number;
    silver: number;
    gold: number;
    platinum: number;
  };
}

/**
 * Exchange NPSSO token for access code
 */
export async function exchangeNpssoForAccessCode(npssoToken: string): Promise<string> {
  const queryParams = new URLSearchParams({
    access_type: 'offline',
    client_id: '09515159-7237-4370-9b40-3806e67c0891',
    redirect_uri: 'com.scee.psxandroid.scecompcall://redirect',
    response_type: 'code',
    scope: 'psn:mobile.v2.core psn:clientapp',
  });

  const requestUrl = `${AUTH_BASE_URL}/authorize?${queryParams.toString()}`;

  const response = await fetch(requestUrl, {
    headers: {
      Cookie: `npsso=${npssoToken}`,
    },
    redirect: 'manual',
  });

  const locationHeader = response.headers.get('location');
  if (!locationHeader || !locationHeader.includes('?code=')) {
    throw new Error('Failed to retrieve PSN access code. Is your NPSSO token valid?');
  }

  const url = new URL(locationHeader);
  const code = url.searchParams.get('code');
  
  if (!code) {
    throw new Error('No code found in redirect URL');
  }

  return code;
}

/**
 * Exchange access code for auth tokens
 */
export async function exchangeAccessCodeForAuthTokens(accessCode: string): Promise<AuthorizationPayload> {
  const requestUrl = `${AUTH_BASE_URL}/token`;

  const response = await fetch(requestUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic MDk1MTUxNTktNzIzNy00MzcwLTliNDAtMzgwNmU2N2MwODkxOnVjUGprYTV0bnRCMktxc1A=',
    },
    body: new URLSearchParams({
      code: accessCode,
      redirect_uri: 'com.scee.psxandroid.scecompcall://redirect',
      grant_type: 'authorization_code',
      token_format: 'jwt',
    }),
  });

  if (!response.ok) {
    throw new Error(`Failed to exchange access code: ${response.statusText}`);
  }

  const data = await response.json();

  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresIn: data.expires_in,
    tokenType: data.token_type,
  };
}

/**
 * Exchange refresh token for new access token
 */
export async function exchangeRefreshTokenForAuthTokens(refreshToken: string): Promise<AuthorizationPayload> {
  const requestUrl = `${AUTH_BASE_URL}/token`;

  const response = await fetch(requestUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic MDk1MTUxNTktNzIzNy00MzcwLTliNDAtMzgwNmU2N2MwODkxOnVjUGprYTV0bnRCMktxc1A=',
    },
    body: new URLSearchParams({
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
      token_format: 'jwt',
      scope: 'psn:mobile.v2.core psn:clientapp',
    }),
  });

  if (!response.ok) {
    throw new Error(`Failed to refresh token: ${response.statusText}`);
  }

  const data = await response.json();

  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresIn: data.expires_in,
    tokenType: data.token_type,
  };
}

/**
 * Get user's trophy profile summary
 */
export async function getUserTrophyProfileSummary(
  authorization: AuthorizationPayload,
  accountId: string
): Promise<UserTrophyProfileSummary> {
  const requestUrl = `${TROPHY_BASE_URL}/v1/users/${accountId}/trophySummary`;

  const response = await fetch(requestUrl, {
    headers: {
      'Authorization': `Bearer ${authorization.accessToken}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch trophy profile summary: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * Get user's PSN profile (onlineId, avatar, PS Plus status, etc.)
 */
export async function getUserProfile(
  authorization: AuthorizationPayload,
  accountId: string
): Promise<PSNUserProfile> {
  // Use the basic profile endpoint with minimal fields
  const requestUrl = `https://us-prof.np.community.playstation.net/userProfile/v1/users/${accountId}/profile2?fields=onlineId,avatarUrls,plus`;

  const response = await fetch(requestUrl, {
    headers: {
      'Authorization': `Bearer ${authorization.accessToken}`,
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to fetch user profile (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  const profile = data.profile || data;
  
  // Map plus (0/1) to isPlus boolean
  return {
    ...profile,
    isPlus: profile.plus === 1,
    accountId,
    npId: profile.npId || '',
    aboutMe: profile.aboutMe || '',
    languagesUsed: profile.languagesUsed || [],
    isOfficiallyVerified: profile.isOfficiallyVerified || false,
  };
}

/**
 * Get user's game list with trophy data
 */
export async function getUserTitles(
  authorization: AuthorizationPayload,
  accountId: string,
  options?: {
    limit?: number;
    offset?: number;
  }
): Promise<{ trophyTitles: TrophyTitle[]; totalItemCount: number }> {
  const queryParams = new URLSearchParams({
    limit: (options?.limit || 800).toString(),
    offset: (options?.offset || 0).toString(),
  });

  const requestUrl = `${TROPHY_BASE_URL}/v1/users/${accountId}/trophyTitles?${queryParams.toString()}`;

  const response = await fetch(requestUrl, {
    headers: {
      'Authorization': `Bearer ${authorization.accessToken}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch user titles: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * Get trophy groups for a title
 */
export async function getTitleTrophyGroups(
  authorization: AuthorizationPayload,
  npCommunicationId: string,
  options?: {
    npServiceName?: 'trophy' | 'trophy2';
  }
): Promise<{
  trophySetVersion: string;
  trophyTitleName: string;
  trophyTitleIconUrl: string;
  trophyTitlePlatform: string;
  definedTrophies: { bronze: number; silver: number; gold: number; platinum: number };
  trophyGroups: TrophyGroup[];
}> {
  const queryParams = new URLSearchParams();
  if (options?.npServiceName) {
    queryParams.set('npServiceName', options.npServiceName);
  }

  const requestUrl = `${TROPHY_BASE_URL}/v1/npCommunicationIds/${npCommunicationId}/trophyGroups?${queryParams.toString()}`;

  const response = await fetch(requestUrl, {
    headers: {
      'Authorization': `Bearer ${authorization.accessToken}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch trophy groups: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * Get trophies for a title
 */
export async function getTitleTrophies(
  authorization: AuthorizationPayload,
  npCommunicationId: string,
  trophyGroupId: string,
  options?: {
    npServiceName?: 'trophy' | 'trophy2';
    limit?: number;
    offset?: number;
  }
): Promise<{
  trophySetVersion: string;
  hasTrophyGroups: boolean;
  trophies: Trophy[];
  totalItemCount: number;
}> {
  const queryParams = new URLSearchParams({
    limit: (options?.limit || 100).toString(),
    offset: (options?.offset || 0).toString(),
  });
  
  if (options?.npServiceName) {
    queryParams.set('npServiceName', options.npServiceName);
  }

  const requestUrl = `${TROPHY_BASE_URL}/v1/npCommunicationIds/${npCommunicationId}/trophyGroups/${trophyGroupId}/trophies?${queryParams.toString()}`;

  const response = await fetch(requestUrl, {
    headers: {
      'Authorization': `Bearer ${authorization.accessToken}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch title trophies: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * Get user's earned trophies for a title
 */
export async function getUserTrophiesEarnedForTitle(
  authorization: AuthorizationPayload,
  accountId: string,
  npCommunicationId: string,
  trophyGroupId: string,
  options?: {
    npServiceName?: 'trophy' | 'trophy2';
    limit?: number;
    offset?: number;
  }
): Promise<{
  trophySetVersion: string;
  hasTrophyGroups: boolean;
  lastUpdatedDateTime: string;
  trophies: Trophy[];
  totalItemCount: number;
}> {
  const queryParams = new URLSearchParams({
    limit: (options?.limit || 100).toString(),
    offset: (options?.offset || 0).toString(),
  });
  
  if (options?.npServiceName) {
    queryParams.set('npServiceName', options.npServiceName);
  }

  const requestUrl = `${TROPHY_BASE_URL}/v1/users/${accountId}/npCommunicationIds/${npCommunicationId}/trophyGroups/${trophyGroupId}/trophies?${queryParams.toString()}`;

  const response = await fetch(requestUrl, {
    headers: {
      'Authorization': `Bearer ${authorization.accessToken}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch user trophies: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * Get user's trophy group earnings for a title
 */
export async function getUserTrophyGroupEarningsForTitle(
  authorization: AuthorizationPayload,
  accountId: string,
  npCommunicationId: string,
  options?: {
    npServiceName?: 'trophy' | 'trophy2';
  }
): Promise<{
  trophySetVersion: string;
  hiddenFlag: boolean;
  progress: number;
  earnedTrophies: { bronze: number; silver: number; gold: number; platinum: number };
  trophyGroups: Array<{
    trophyGroupId: string;
    progress: number;
    earnedTrophies: { bronze: number; silver: number; gold: number; platinum: number };
    lastUpdatedDateTime: string;
  }>;
  lastUpdatedDateTime: string;
}> {
  const queryParams = new URLSearchParams();
  if (options?.npServiceName) {
    queryParams.set('npServiceName', options.npServiceName);
  }

  const requestUrl = `${TROPHY_BASE_URL}/v1/users/${accountId}/npCommunicationIds/${npCommunicationId}/trophyGroups?${queryParams.toString()}`;

  const response = await fetch(requestUrl, {
    headers: {
      'Authorization': `Bearer ${authorization.accessToken}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch trophy group earnings: ${response.statusText}`);
  }

  return await response.json();
}
