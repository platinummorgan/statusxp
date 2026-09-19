// Recovery performs a fresh upstream scan and uses the same admission policy.
export async function admitRecoverySync(client, userId, platform) {
  try {
    const { data, error } = await client.rpc('admit_provider_request', {
      p_user_id: userId, p_provider: `sync_${platform}`,
    });
    return !error && data?.allowed === true;
  } catch {
    return false;
  }
}
