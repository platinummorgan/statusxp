-- Fix add_ai_pack_credits function to explicitly reference public schema
CREATE OR REPLACE FUNCTION public.add_ai_pack_credits(
  p_user_id uuid,
  p_pack_type character varying,
  p_credits integer,
  p_price numeric,
  p_platform character varying
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Add credits to user's account with explicit schema
  INSERT INTO public.user_ai_credits (user_id, pack_credits)
  VALUES (p_user_id, p_credits)
  ON CONFLICT (user_id)
  DO UPDATE SET 
    pack_credits = public.user_ai_credits.pack_credits + p_credits,
    updated_at = NOW();

  -- Record purchase with explicit schema
  INSERT INTO public.user_ai_pack_purchases (user_id, pack_type, credits_purchased, price_paid, platform)
  VALUES (p_user_id, p_pack_type, p_credits, p_price, p_platform);

  -- Return new credit balance
  RETURN json_build_object(
    'success', true,
    'new_balance', (SELECT pack_credits FROM public.user_ai_credits WHERE user_id = p_user_id)
  );
END;
$function$;

-- Grant execute to service role
GRANT EXECUTE ON FUNCTION public.add_ai_pack_credits TO service_role;
GRANT EXECUTE ON FUNCTION public.add_ai_pack_credits TO authenticated;
