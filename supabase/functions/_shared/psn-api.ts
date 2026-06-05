/**
 * PSN API Client
 * 
 * Implements authentication and trophy data fetching from PlayStation Network.
 * Based on the psn-api library patterns.
 */

const AUTH_BASE_URL = 'https://ca.account.sony.com/api/authz/v3/oauth';
const TROPHY_BASE_URL = 'https://m.np.playstation.com/api/trophy';
const USER_BASE_URL = 'https://m.np.playstation.com/api/userProfile/v1/internal/users';
const USER_LEGACY_BASE_URL = 'https://us-prof.np.community.playstation.net/userProfile/v1/users';
const BASIC_PROFILE_BASE_URL = 'https://web.np.playstation.com/api/basicProfile/v1/profile/users';

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function compactText(value: string, maxLength = 500): string {
  const compacted = value.replace(/\s+/g, ' ').trim();
  return compacted.length > maxLength ? `${compacted.slice(0, maxLength)}...` : compacted;
}

function extractResponseMessage(parsed: unknown, rawText: string): string {
  if (isRecord(parsed)) {
    const error = parsed.error;
    if (typeof error === 'string') return compactText(error);

    if (isRecord(error)) {
      const message = error.message || error.error_description || error.reason || error.code;
      if (typeof message === 'string' || typeof message === 'number') {
        return compactText(String(message));
      }

      try {
        return compactText(JSON.stringify(error));
      } catch {
        return 'Unknown PSN error';
      }
    }

    const message = parsed.message || parsed.error_description || parsed.reason;
    if (typeof message === 'string' || typeof message === 'number') {
      return compactText(String(message));
    }
  }

  return rawText ? compactText(rawText) : 'No response body';
}

async function parseJsonOrText(response: Response): Promise<{ parsed: unknown; rawText: string }> {
  const rawText = await response.text();
  if (!rawText) return { parsed: null, rawText };

  try {
    return { parsed: JSON.parse(rawText), rawText };
  } catch {
    return { parsed: null, rawText };
  }
}

async function parsePsnJsonResponse<T>(response: Response, action: string): Promise<T> {
  const { parsed, rawText } = await parseJsonOrText(response);

  if (!response.ok) {
    const statusText = response.statusText || 'Unknown status';
    throw new Error(
      `${action} failed (${response.status} ${statusText}): ${extractResponseMessage(parsed, rawText)}`
    );
  }

  if (isRecord(parsed) && parsed.error) {
    throw new Error(`${action} failed: ${extractResponseMessage(parsed, rawText)}`);
  }

  return parsed as T;
}

function psnApiHeaders(authorization: AuthorizationPayload): HeadersInit {
  return {
    'Authorization': `Bearer ${authorization.accessToken}`,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Accept-Language': 'en-US',
  };
}

async function psnGetJson<T>(
  requestUrl: string,
  authorization: AuthorizationPayload,
  action: string
): Promise<T> {
  const response = await fetch(requestUrl, {
    headers: psnApiHeaders(authorization),
  });

  return await parsePsnJsonResponse<T>(response, action);
}

function normalizeAvatarUrls(profile: Record<string, unknown>): Array<{ size: string; avatarUrl: string }> {
  const avatarUrls: Array<{ size: string; avatarUrl: string }> = [];

  const legacyAvatars = profile.avatarUrls;
  if (Array.isArray(legacyAvatars)) {
    for (const avatar of legacyAvatars) {
      if (!isRecord(avatar)) continue;
      const avatarUrl = avatar.avatarUrl || avatar.url;
      if (typeof avatarUrl !== 'string') continue;
      avatarUrls.push({
        size: typeof avatar.size === 'string' ? avatar.size : '',
        avatarUrl,
      });
    }
  }

  const basicAvatars = profile.avatars;
  if (Array.isArray(basicAvatars)) {
    for (const avatar of basicAvatars) {
      if (!isRecord(avatar)) continue;
      const avatarUrl = avatar.avatarUrl || avatar.url;
      if (typeof avatarUrl !== 'string') continue;
      avatarUrls.push({
        size: typeof avatar.size === 'string' ? avatar.size : '',
        avatarUrl,
      });
    }
  }

  return avatarUrls;
}

function normalizePsnUserProfile(rawProfile: unknown, fallbackAccountId: string): PSNUserProfile {
  let profile: unknown = rawProfile;
  if (isRecord(rawProfile)) {
    if (isRecord(rawProfile.profile)) {
      profile = rawProfile.profile;
    } else if (Array.isArray(rawProfile.profiles) && rawProfile.profiles.length > 0) {
      profile = rawProfile.profiles[0];
    }
  }

  if (!isRecord(profile)) {
    throw new Error('Failed to fetch user profile: unexpected profile response');
  }

  const onlineId = profile.onlineId;
  if (typeof onlineId !== 'string' || onlineId.trim().length === 0) {
    throw new Error('Failed to fetch user profile: missing onlineId');
  }

  const rawAccountId = profile.accountId || (isRecord(rawProfile) ? rawProfile.accountId : null);
  const accountId =
    typeof rawAccountId === 'string' && rawAccountId.trim().length > 0
      ? rawAccountId
      : fallbackAccountId;

  const rawPlus = profile.plus ?? profile.isPlus;
  const plus = typeof rawPlus === 'number' ? rawPlus : rawPlus === true ? 1 : 0;

  return {
    onlineId,
    accountId,
    npId: typeof profile.npId === 'string' ? profile.npId : '',
    avatarUrls: normalizeAvatarUrls(profile),
    plus,
    aboutMe: typeof profile.aboutMe === 'string' ? profile.aboutMe : '',
    languagesUsed: Array.isArray(profile.languagesUsed)
      ? profile.languagesUsed.filter((language): language is string => typeof language === 'string')
      : Array.isArray(profile.languages)
        ? profile.languages.filter((language): language is string => typeof language === 'string')
        : [],
    isPlus: plus === 1,
    isOfficiallyVerified: profile.isOfficiallyVerified === true,
  };
}

function extractNumericAccountId(value: unknown): string | null {
  if (typeof value !== 'string' && typeof value !== 'number') return null;

  const text = String(value);
  if (/^\d{10,}$/.test(text)) return text;

  const namedMatch = text.match(/(?:accountId|account_id|account)\D+(\d{10,})/i);
  if (namedMatch) return namedMatch[1];

  return null;
}

export function extractAccountIdFromAccessToken(accessToken: string): string | null {
  try {
    const payload = accessToken.split('.')[1];
    if (!payload) return null;

    const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
    const claims = JSON.parse(atob(padded));

    if (!isRecord(claims)) return null;

    const claimKeys = ['accountId', 'account_id', 'userId', 'user_id', 'sub', 'uid', 'id'];
    for (const key of claimKeys) {
      const accountId = extractNumericAccountId(claims[key]);
      if (accountId) return accountId;
    }

    return null;
  } catch {
    return null;
  }
}

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
    const errorText = await response.text().catch(() => '');
    throw new Error(
      `Failed to retrieve PSN access code (${response.status} ${response.statusText || 'Unknown status'}). ` +
        `Is your NPSSO token valid?${errorText ? ` ${compactText(errorText)}` : ''}`
    );
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

  const data = await parsePsnJsonResponse<Record<string, unknown>>(response, 'Exchange PSN access code');

  if (typeof data.access_token !== 'string') {
    throw new Error('Exchange PSN access code failed: missing access token');
  }

  return {
    accessToken: data.access_token,
    refreshToken: typeof data.refresh_token === 'string' ? data.refresh_token : undefined,
    expiresIn: typeof data.expires_in === 'number' ? data.expires_in : undefined,
    tokenType: typeof data.token_type === 'string' ? data.token_type : undefined,
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

  const data = await parsePsnJsonResponse<Record<string, unknown>>(response, 'Refresh PSN token');

  if (typeof data.access_token !== 'string') {
    throw new Error('Refresh PSN token failed: missing access token');
  }

  return {
    accessToken: data.access_token,
    refreshToken: typeof data.refresh_token === 'string' ? data.refresh_token : undefined,
    expiresIn: typeof data.expires_in === 'number' ? data.expires_in : undefined,
    tokenType: typeof data.token_type === 'string' ? data.token_type : undefined,
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

  return await psnGetJson<UserTrophyProfileSummary>(
    requestUrl,
    authorization,
    'Fetch trophy profile summary'
  );
}

/**
 * Get user's PSN profile (onlineId, avatar, PS Plus status, etc.)
 */
export async function getUserProfile(
  authorization: AuthorizationPayload,
  accountId: string
): Promise<PSNUserProfile> {
  const fields = [
    'npId',
    'onlineId',
    'accountId',
    'avatarUrls',
    'plus',
    'aboutMe',
    'languagesUsed',
    'isOfficiallyVerified',
  ].join(',');

  const legacyRequestUrl = `${USER_LEGACY_BASE_URL}/${accountId}/profile2?${new URLSearchParams({ fields })}`;

  try {
    const data = await psnGetJson<unknown>(
      legacyRequestUrl,
      authorization,
      'Fetch legacy user profile'
    );
    return normalizePsnUserProfile(data, accountId);
  } catch (legacyProfileError) {
    console.warn(
      'Legacy PSN profile endpoint failed, trying basic profile endpoint:',
      (legacyProfileError as Error).message
    );
  }

  const basicRequestUrl = `${BASIC_PROFILE_BASE_URL}/${accountId}`;
  const data = await psnGetJson<unknown>(
    basicRequestUrl,
    authorization,
    'Fetch basic user profile'
  );

  return normalizePsnUserProfile(data, accountId);
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

  return await psnGetJson<{ trophyTitles: TrophyTitle[]; totalItemCount: number }>(
    requestUrl,
    authorization,
    'Fetch user titles'
  );
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

  return await psnGetJson<{
    trophySetVersion: string;
    trophyTitleName: string;
    trophyTitleIconUrl: string;
    trophyTitlePlatform: string;
    definedTrophies: { bronze: number; silver: number; gold: number; platinum: number };
    trophyGroups: TrophyGroup[];
  }>(requestUrl, authorization, 'Fetch trophy groups');
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

  return await psnGetJson<{
    trophySetVersion: string;
    hasTrophyGroups: boolean;
    trophies: Trophy[];
    totalItemCount: number;
  }>(requestUrl, authorization, 'Fetch title trophies');
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

  return await psnGetJson<{
    trophySetVersion: string;
    hasTrophyGroups: boolean;
    lastUpdatedDateTime: string;
    trophies: Trophy[];
    totalItemCount: number;
  }>(requestUrl, authorization, 'Fetch user trophies');
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

  return await psnGetJson<{
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
  }>(requestUrl, authorization, 'Fetch trophy group earnings');
}
