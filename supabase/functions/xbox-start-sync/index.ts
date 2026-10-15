import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { quotaResponse } from '../_shared/provider-quota.ts';
import { createXboxStartHandler } from './handler.ts';
serve(createXboxStartHandler({ createClient, env: name => Deno.env.get(name), fetch, quotaResponse }));
