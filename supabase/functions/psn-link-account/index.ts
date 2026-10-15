import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { exchangeNpssoForAccessCode, exchangeAccessCodeForAuthTokens, extractAccountIdFromAccessToken,
 getUserTrophyProfileSummary, getUserProfile } from '../_shared/psn-api.ts';
import { uploadExternalAvatar } from '../_shared/avatar-storage.ts';
import { createPsnLinkHandler } from './handler.ts';
serve(createPsnLinkHandler({ createClient,env:(name)=>Deno.env.get(name),fetch,
 exchangeNpssoForAccessCode,exchangeAccessCodeForAuthTokens,extractAccountIdFromAccessToken,
 getUserTrophyProfileSummary,getUserProfile,uploadExternalAvatar }));
