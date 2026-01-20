import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

Deno.serve(async (req) => {
  try {
    console.log('[PSN SYNC TEST] Starting PSN sync test')
    
    // Check environment variables
    const syncServiceSecret = Deno.env.get('SYNC_SERVICE_SECRET')
    console.log('[ENV CHECK] SYNC_SERVICE_SECRET exists:', !!syncServiceSecret)
    console.log('[ENV CHECK] SYNC_SERVICE_SECRET value:', syncServiceSecret)
    
    // Test the authentication to Railway
    const railwayUrl = 'https://statusxp-production.up.railway.app/sync/psn'
    console.log('[RAILWAY TEST] Testing Railway connection to:', railwayUrl)
    
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${syncServiceSecret}`
    }
    console.log('[RAILWAY TEST] Request headers:', JSON.stringify(headers, null, 2))
    
    const testPayload = {
      userId: '68de8222-9da5-4362-ac9b-96b302a7d455',
      syncType: 'test',
      test: true
    }
    
    console.log('[RAILWAY TEST] Sending test request...')
    const response = await fetch(railwayUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(testPayload)
    })
    
    console.log('[RAILWAY TEST] Response status:', response.status)
    console.log('[RAILWAY TEST] Response headers:', JSON.stringify(Object.fromEntries(response.headers.entries()), null, 2))
    
    const responseText = await response.text()
    console.log('[RAILWAY TEST] Response body:', responseText)
    
    return new Response(
      JSON.stringify({
        syncServiceSecret: syncServiceSecret ? 'EXISTS' : 'MISSING',
        railwayResponse: {
          status: response.status,
          headers: Object.fromEntries(response.headers.entries()),
          body: responseText
        }
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[PSN SYNC TEST] Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})