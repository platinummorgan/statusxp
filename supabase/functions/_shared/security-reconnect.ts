export async function completeSecurityReconnect(
  admin:any, owner:string, platform:'psn'|'xbox'|'steam', accountId:string, credential:string,
) {
  const normalized=platform==='steam'?credential.toLowerCase():credential;
  const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(normalized));
  const hash=Array.from(new Uint8Array(digest),byte=>byte.toString(16).padStart(2,'0')).join('');
  return await admin.rpc('complete_verified_security_reconnect',{
    p_user_id:owner,p_platform:platform,p_verified_account_id:accountId,p_verified_credential_hash:hash,
  });
}
