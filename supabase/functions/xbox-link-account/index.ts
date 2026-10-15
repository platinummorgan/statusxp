import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createXboxLinkHandler } from './handler.ts';
serve(createXboxLinkHandler({ createClient, env: name => Deno.env.get(name), fetch }));
