import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.10.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

serve(async (req) => {
  const signature = req.headers.get('stripe-signature')
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')

  if (!signature || !webhookSecret) {
    return new Response('Missing signature or webhook secret', { status: 400 })
  }

  try {
    const body = await req.text()
    const event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret)

    console.log('✅ Webhook received:', event.type)

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session
        const userId = session.client_reference_id || session.metadata?.user_id

        if (!userId) {
          console.error('❌ No user ID in checkout session')
          break
        }

        // Check if this is an AI pack purchase (mode: 'payment') or subscription (mode: 'subscription')
        if (session.mode === 'payment' && session.metadata?.credits) {
          // AI Pack purchase
          const credits = parseInt(session.metadata.credits)
          const packType = session.metadata.pack_type
          
          console.log(`🎁 Adding ${credits} AI credits for user: ${userId} (pack: ${packType})`)
          
          // Add AI credits to user's balance
          const { error: creditError } = await supabase.rpc('add_ai_credits', {
            p_user_id: userId,
            p_credits: credits,
          })
          
          if (creditError) {
            console.error('❌ Error adding AI credits:', creditError)
          } else {
            console.log('✅ AI credits added successfully')
          }
        } else {
          // Premium subscription activation
          console.log(`💎 Activating premium for user: ${userId}`)
          console.log(`📧 Customer email: ${session.customer_email}`)

          const { error: updateError } = await supabase
            .from('user_premium_status')
            .upsert({
              user_id: userId,
              is_premium: true,
              premium_since: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            }, {
              onConflict: 'user_id'
            })

          if (updateError) {
            console.error('❌ Error updating premium status:', updateError)
          } else {
            console.log('✅ Premium status activated successfully')
          }
        }

        break
      }

      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription
        
        // Get customer email from Stripe
        const customer = await stripe.customers.retrieve(subscription.customer as string) as Stripe.Customer
        const customerEmail = customer.email
        
        if (!customerEmail) {
          console.error('❌ No customer email in subscription')
          break
        }

        // Look up user by email using service role
        const { data: authData, error: authError } = await supabase.auth.admin.listUsers()
        const user = authData?.users.find(u => u.email === customerEmail)

        if (!user) {
          console.error('❌ User not found for email:', customerEmail)
          break
        }

        const isActive = subscription.status === 'active'
        console.log(`🔄 Subscription updated for user ${user.id}: ${subscription.status}`)

        const { error: updateError } = await supabase
          .from('user_premium_status')
          .update({
            is_premium: isActive,
            updated_at: new Date().toISOString(),
          })
          .eq('user_id', user.id)

        if (updateError) {
          console.error('❌ Error updating subscription status:', updateError)
        } else {
          console.log('✅ Subscription status updated')
        }

        break
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription
        
        // Get customer email from Stripe
        const customer = await stripe.customers.retrieve(subscription.customer as string) as Stripe.Customer
        const customerEmail = customer.email
        
        if (!customerEmail) {
          console.error('❌ No customer email in subscription')
          break
        }

        // Look up user by email using service role
        const { data: authData, error: authError } = await supabase.auth.admin.listUsers()
        const user = authData?.users.find(u => u.email === customerEmail)

        if (!user) {
          console.error('❌ User not found for email:', customerEmail)
          break
        }

        console.log(`🚫 Subscription cancelled for user ${user.id}`)

        const { error: updateError } = await supabase
          .from('user_premium_status')
          .update({
            is_premium: false,
            premium_expires_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('user_id', user.id)

        if (updateError) {
          console.error('❌ Error cancelling premium:', updateError)
        } else {
          console.log('✅ Premium cancelled successfully')
        }

        break
      }

      default:
        console.log(`⚠️ Unhandled event type: ${event.type}`)
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('❌ Webhook error:', error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
