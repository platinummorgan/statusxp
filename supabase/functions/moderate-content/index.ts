import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const { text } = await req.json()

    if (!text || typeof text !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Text is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Call OpenAI Moderation API
    const moderationResponse = await fetch('https://api.openai.com/v1/moderations', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        input: text,
      }),
    })

    if (!moderationResponse.ok) {
      throw new Error(`OpenAI API error: ${moderationResponse.statusText}`)
    }

    const moderationData = await moderationResponse.json()
    const result = moderationData.results[0]

    // Check if content is flagged
    const isSafe = !result.flagged
    
    // Get flagged categories
    const flaggedCategories: string[] = []
    if (result.flagged) {
      for (const [category, flagged] of Object.entries(result.categories)) {
        if (flagged) {
          flaggedCategories.push(category)
        }
      }
    }

    return new Response(
      JSON.stringify({
        is_safe: isSafe,
        reason: flaggedCategories.length > 0 
          ? `Content flagged for: ${flaggedCategories.join(', ')}`
          : null,
        categories: result.categories,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    console.error('Moderation error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})
