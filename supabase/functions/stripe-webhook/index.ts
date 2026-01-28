import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.10.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

serve(async (req) => {
  console.log('🔔 Webhook request received')
  
  const signature = req.headers.get('stripe-signature')
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')

  if (!signature || !webhookSecret) {
    console.log('❌ Missing signature or webhook secret')
    return new Response('Missing signature or webhook secret', { status: 400 })
  }

  try {
    const body = await req.text()
    console.log('📦 Body received, constructing event...')
    const event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret)

    console.log('✅ Webhook received:', event.type)
    console.log('📋 Event data:', JSON.stringify(event.data.object, null, 2))

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
          const priceUsd = session.amount_total ? session.amount_total / 100 : 0
          
          console.log(`🎁 Adding ${credits} AI credits for user: ${userId} (pack: ${packType}, price: $${priceUsd})`)
          
          // Add AI credits to user's balance using the correct function signature
          const { error: creditError } = await supabase.rpc('add_ai_pack_credits', {
            p_user_id: userId,
            p_pack_type: packType,
            p_credits: credits,
            p_price: priceUsd,
            p_platform: 'web',
          })
          
          if (creditError) {
            console.error('❌ Error adding AI credits:', creditError)
          } else {
            console.log('✅ AI credits added successfully to user_ai_credits.pack_credits')
          }
        } else {
          // Premium subscription activation via Stripe
          console.log(`💎 Activating Stripe premium for user: ${userId}`);
          console.log(`📧 Customer email: ${session.customer_email}`);

          // Check existing premium status
          const { data: existingPremium } = await supabase
            .from('user_premium_status')
            .select('premium_source, is_premium')
            .eq('user_id', userId)
            .single();

          // Stripe can overwrite Twitch, but NOT Apple/Google
          if (existingPremium?.is_premium && 
              (existingPremium.premium_source === 'apple' || existingPremium.premium_source === 'google')) {
            console.log(`⚠️ User has ${existingPremium.premium_source} IAP - not overwriting with Stripe`);
            
            // Create notification about existing subscription (generic message)
            await supabase.from('notifications').insert({
              user_id: userId,
              type: 'subscription_conflict',
              title: 'Active Subscription Detected',
              message: 'You already have an active premium subscription. Please cancel your existing subscription or wait until it expires before purchasing a new one.',
              created_at: new Date().toISOString(),
            });
            break;
          }

          // Stripe overwrites Twitch (lower priority)
          const { error: updateError } = await supabase
            .from('user_premium_status')
            .upsert({
              user_id: userId,
              is_premium: true,
              premium_source: 'stripe',
              premium_since: new Date().toISOString(),
              expires_at: null, // Stripe subscriptions managed by Stripe
              updated_at: new Date().toISOString(),
            }, {
              onConflict: 'user_id'
            });

          if (updateError) {
            console.error('❌ Error updating premium status:', updateError);
          } else {
            console.log('✅ Stripe premium status activated successfully');
            
            // If we overwrote Twitch, notify user (generic message)
            if (existingPremium?.premium_source === 'twitch') {
              await supabase.from('notifications').insert({
                user_id: userId,
                type: 'subscription_changed',
                title: 'Premium Source Updated',
                message: 'Your premium subscription source has been updated. Your previous subscription has been replaced.',
                created_at: new Date().toISOString(),
              });
            }
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
    console.error('❌ Webhook error:', error)
    console.error('❌ Error message:', error.message)
    console.error('❌ Error stack:', error.stack)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
