import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { createBroadcasterAuthorizationHandler } from './handler.ts';
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
Deno.serve(createBroadcasterAuthorizationHandler({env:name=>Deno.env.get(name),rpc:(name,args)=>db.rpc(name,args),request:fetch}));
