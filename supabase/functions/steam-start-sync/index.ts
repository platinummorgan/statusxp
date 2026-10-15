import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createPlatformStartHandler } from '../_shared/platform-sync-handler.ts';
import { quotaResponse } from '../_shared/provider-quota.ts';
serve(createPlatformStartHandler('steam', { createClient, env: (name) => Deno.env.get(name), fetch, quotaResponse }));
