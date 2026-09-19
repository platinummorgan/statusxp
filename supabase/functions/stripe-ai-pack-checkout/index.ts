import { stripeCustomer } from '../_shared/stripe-customer.ts'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.10.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
  timeout: 20000,
  maxNetworkRetries: 1,
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  if (req.method !== 'POST') return new Response('Use POST', {status:405,headers:corsHeaders})

  try {
    const authHeader = req.headers.get('Authorization')
    const jwt = authHeader?.replace(/^Bearer\s+/i, '')
    
    if (!jwt) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { persistSession: false },
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    })

    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt)
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { packType } = await req.json()
    const catalog: Record<string, {credits:number;price:number}> = {
      small:{credits:20,price:1.99},medium:{credits:60,price:4.99},large:{credits:150,price:9.99},
    }
    if(typeof packType !== 'string' || !Object.hasOwn(catalog,packType)) {
      return new Response(JSON.stringify({error:'Unknown pack'}),{status:400,headers:{...corsHeaders,'Content-Type':'application/json'}})
    }
    const {credits,price}=catalog[packType]
    const packNames:Record<string,string>={small:'AI Pack S - 20 Uses',medium:'AI Pack M - 60 Uses',large:'AI Pack L - 150 Uses'}

    console.log(`Creating AI pack checkout for user: ${user.id}, pack: ${packType}`)

    // Create Stripe Checkout Session for one-time payment
    const customer = await stripeCustomer(stripe, user.id)
    const session = await stripe.checkout.sessions.create({
      customer,
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: packNames[packType] || `AI Pack ${packType}`,
              description: `${credits} AI achievement guide uses`,
            },
            unit_amount: Math.round(price * 100), // Convert to cents
          },
          quantity: 1,
        },
      ],
      mode: 'payment', // One-time payment, not subscription
      client_reference_id: user.id,
      metadata: {
        user_id: user.id,
        pack_type: packType,
        credits: credits.toString(),
      },
      success_url: `https://statusxp.com/`,
      cancel_url: `https://statusxp.com/`,
    })

    console.log(`✅ AI pack checkout session created: ${session.id}`)

    return new Response(
      JSON.stringify({ url: session.url, sessionId: session.id }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('AI checkout creation failed')
    return new Response(
      JSON.stringify({ error: 'Checkout unavailable. Please try again.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
