import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { getTwitchBroadcasterToken } from './twitch-broadcaster-token.ts';
type TwitchSubscriptionSettings={broadcaster:string|undefined;token:string|undefined;client:string|undefined;request:typeof fetch;renew?:()=>Promise<string>};
async function subscriptionSettings():Promise<TwitchSubscriptionSettings> {
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
 const deps={rpc:(name:string,args?:Record<string,unknown>)=>db.rpc(name,args),request:fetch,
  clientId:Deno.env.get('TWITCH_CLIENT_ID')??'',clientSecret:Deno.env.get('TWITCH_CLIENT_SECRET')??'',
  broadcasterId:Deno.env.get('TWITCH_BROADCASTER_ID')??'',legacyToken:Deno.env.get('TWITCH_BROADCASTER_TOKEN')};
 return {broadcaster:deps.broadcasterId,client:deps.clientId,token:await getTwitchBroadcasterToken(deps),request:fetch,renew:()=>getTwitchBroadcasterToken(deps,true)};
}
export async function currentTwitchSubscription(
  userId: string,
  suppliedSettings?: TwitchSubscriptionSettings,
): Promise<boolean> {
  const settings=suppliedSettings??await subscriptionSettings();
  const { broadcaster, token, client } = settings;
  if (!broadcaster || !token || !client) {
    throw new Error("Twitch subscription check unavailable");
  }
  const url = new URL("https://api.twitch.tv/helix/subscriptions");
  url.search = new URLSearchParams({
    broadcaster_id: broadcaster,
    user_id: userId,
  }).toString();
  let response = await settings.request(url, {
    headers: { Authorization: `Bearer ${token}`, "Client-Id": client },
    signal: AbortSignal.timeout(10000),
  });
  if(response.status===401&&settings.renew){
    await response.body?.cancel();
    const fresh=await settings.renew();
    response=await settings.request(url,{headers:{Authorization:`Bearer ${fresh}`,'Client-Id':client},signal:AbortSignal.timeout(10000)});
  }
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error("Twitch subscription check failed");
  }
  const data = await response.json();
  if (!Array.isArray(data.data)) {
    throw new Error("Invalid subscription response");
  }
  return data.data.some((row: { user_id?: string; broadcaster_id?: string }) =>
    row.user_id === userId && row.broadcaster_id === broadcaster
  );
}
