import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

Deno.serve(async (req) => {
  try {
    // Check sync status for your specific user
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('id, psn_sync_status, psn_sync_progress, steam_sync_status, steam_sync_progress, xbox_sync_status, xbox_sync_progress')
      .eq('id', '68de8222-9da5-4362-ac9b-96b302a7d455')
      .single()

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { headers: { 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    // Also check sync logs
    const { data: psnLogs } = await supabase
      .from('psn_sync_logs')
      .select('*')
      .eq('user_id', '68de8222-9da5-4362-ac9b-96b302a7d455')
      .order('created_at', { ascending: false })
      .limit(3)

    return new Response(
      JSON.stringify({ profile, psnLogs }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})