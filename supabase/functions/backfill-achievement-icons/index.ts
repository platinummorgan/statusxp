import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { platform_ids, batch_size = 50, offset = 0, table = 'achievements' } = await req.json();

    if (!platform_ids || !Array.isArray(platform_ids)) {
      throw new Error("platform_ids array is required");
    }

    if (!['achievements', 'trophies'].includes(table)) {
      throw new Error("table must be 'achievements' or 'trophies'");
    }

    // Fetch achievements/trophies that need backfilling (external URLs only)
    const { data: icons, error: fetchError } = await supabase
      .from(table)
      .select('id, platform_id, platform_achievement_id, icon_url, proxied_icon_url')
      .in('platform_id', platform_ids)
      .not('icon_url', 'is', null)
      .is('proxied_icon_url', null)
      .range(offset, offset + batch_size - 1);

    if (fetchError) {
      throw fetchError;
    }

    if (!icons || icons.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: "No icons need backfilling",
          processed: 0 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Processing ${icons.length} icons from ${table} table...`);

    const results = {
      success: 0,
      failed: 0,
      errors: [] as any[],
    };

    for (const icon of icons) {
      try {
        console.log(`Downloading icon: ${icon.icon_url}`);
        
        // Download the image
        const response = await fetch(icon.icon_url);
        if (!response.ok) {
          throw new Error(`Failed to download: ${response.status} ${response.statusText}`);
        }

        const blob = await response.blob();
        const arrayBuffer = await blob.arrayBuffer();

        // Determine file extension from URL or content type
        const contentType = response.headers.get("content-type") || "image/png";
        const urlExtension = icon.icon_url.split('.').pop()?.split('?')[0];
        const extension = urlExtension && ['png', 'jpg', 'jpeg', 'gif', 'webp'].includes(urlExtension.toLowerCase()) 
          ? urlExtension.toLowerCase() 
          : contentType.split('/')[1] || 'png';

        // Upload to storage with path: achievement-icons/{platform_id}/{platform_achievement_id}.{ext}
        const filePath = `${icon.platform_id}/${icon.platform_achievement_id}.${extension}`;
        
        const { error: uploadError } = await supabase.storage
          .from('achievement-icons')
          .upload(filePath, arrayBuffer, {
            contentType,
            upsert: true,
          });

        if (uploadError) {
          throw uploadError;
        }

        // Get the public URL
        const { data: { publicUrl } } = supabase.storage
          .from('achievement-icons')
          .getPublicUrl(filePath);

        console.log(`Uploaded to: ${publicUrl}`);

        // Update the database with the new URL
        const { error: updateError } = await supabase
          .from(table)
          .update({ 
            proxied_icon_url: publicUrl,
            updated_at: new Date().toISOString()
          })
          .eq('id', icon.id);

        if (updateError) {
          throw updateError;
        }

        results.success++;
        console.log(`✓ Processed ${table} icon ${icon.platform_achievement_id}`);

      } catch (error) {
        results.failed++;
        results.errors.push({
          icon_id: icon.id,
          platform_achievement_id: icon.platform_achievement_id,
          error: error.message,
        });
        console.error(`✗ Failed to process ${table} icon ${icon.platform_achievement_id}:`, error);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        table,
        processed: icons.length,
        ...results,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
