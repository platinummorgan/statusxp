import Stripe from "https://esm.sh/stripe@14.10.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
export async function stripeCustomer(
  stripe: Stripe,
  userId: string,
): Promise<string> {
  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const { data, error } = await db.from("stripe_customers").select(
    "customer_id",
  ).eq("user_id", userId).maybeSingle();
  if (error) throw new Error("Customer lookup unavailable");
  if (data) return data.customer_id;
  const customer = await stripe.customers.create({
    metadata: { user_id: userId },
  }, { idempotencyKey: `statusxp-customer-${userId}` });
  const bound = await db.rpc("bind_stripe_customer", {
    p_user_id: userId,
    p_customer_id: customer.id,
  });
  if (bound.error) throw new Error("Customer binding unavailable");
  return customer.id;
}
