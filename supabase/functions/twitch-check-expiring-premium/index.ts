/**
 * Twitch Premium Expiry Check
 * 
 * Scheduled function that runs daily to check for Twitch premium memberships
 * expiring in 3 days and sends notifications to users.
 * 
 * Should be configured to run via Supabase cron job or called via HTTP POST
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ExpiringUser {
  user_id: string;
  expires_at: string;
  email?: string;
  username?: string;
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Create Supabase admin client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Calculate the date range we're checking for
    // We want users whose premium expires in 3 days (day 30 of their subscription)
    const threeDaysFromNow = new Date();
    threeDaysFromNow.setDate(threeDaysFromNow.getDate() + 3);
    
    const fourDaysFromNow = new Date();
    fourDaysFromNow.setDate(fourDaysFromNow.getDate() + 4);

    console.log(`Checking for Twitch premium expiring between ${threeDaysFromNow.toISOString()} and ${fourDaysFromNow.toISOString()}`);

    // Find users with Twitch premium expiring in 3 days
    const { data: expiringPremiums, error: queryError } = await supabaseAdmin
      .from('user_premium_status')
      .select(`
        user_id,
        expires_at,
        profiles!inner(
          email,
          username
        )
      `)
      .eq('premium_source', 'twitch')
      .eq('is_premium', true)
      .gte('expires_at', threeDaysFromNow.toISOString())
      .lt('expires_at', fourDaysFromNow.toISOString());

    if (queryError) {
      console.error('Error querying expiring premiums:', queryError);
      throw queryError;
    }

    if (!expiringPremiums || expiringPremiums.length === 0) {
      console.log('No Twitch premium memberships expiring in 3 days');
      return new Response(
        JSON.stringify({
          message: 'No expiring memberships found',
          checked_at: new Date().toISOString(),
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`Found ${expiringPremiums.length} Twitch premium memberships expiring in 3 days`);

    // Process each expiring user
    const notifications = [];
    for (const premium of expiringPremiums) {
      try {
        const profile = (premium as any).profiles;
        const email = profile?.email;
        const username = profile?.username;

        console.log(`Processing user ${premium.user_id} (${username || 'unknown'})`);

        // TODO: Send actual notification
        // Options:
        // 1. In-app notification via notifications table
        // 2. Email notification via SendGrid/Resend
        // 3. Push notification via FCM
        
        // For now, just create an in-app notification
        const { error: notifError } = await supabaseAdmin
          .from('notifications')
          .insert({
            user_id: premium.user_id,
            type: 'premium_expiring',
            title: 'Twitch Premium Ending Soon',
            message: 'Your StatusXP premium membership from Twitch will end in 3 days. Make sure your Twitch subscription is active to keep your premium benefits!',
            data: {
              expires_at: premium.expires_at,
              source: 'twitch',
            },
            created_at: new Date().toISOString(),
          });

        if (notifError) {
          console.error(`Failed to create notification for user ${premium.user_id}:`, notifError);
        } else {
          console.log(`✅ Notification created for user ${premium.user_id}`);
          notifications.push({
            user_id: premium.user_id,
            username,
            email,
            expires_at: premium.expires_at,
          });
        }
      } catch (error) {
        console.error(`Error processing user ${premium.user_id}:`, error);
      }
    }

    return new Response(
      JSON.stringify({
        message: `Processed ${expiringPremiums.length} expiring memberships`,
        notifications: notifications.length,
        users: notifications,
        checked_at: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );

  } catch (error) {
    console.error('Error checking expiring premium:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to check expiring premium',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
