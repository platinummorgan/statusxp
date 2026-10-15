import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createPlatformStartHandler } from '../_shared/platform-sync-handler.ts';
import { quotaResponse } from '../_shared/provider-quota.ts';
import { exchangeRefreshTokenForAuthTokens } from '../_shared/psn-api.ts';
serve(createPlatformStartHandler('psn', { createClient, env: (name) => Deno.env.get(name), fetch, quotaResponse, refreshPsn: exchangeRefreshTokenForAuthTokens }));
