// Publish a game summary only after achievement writes have finished. Provider
// summaries remain useful when detailed imports fail, but must remain retryable.
export async function finalizeGameImport(supabase, payload, { fetchedDefinitions = 0 } = {}) {
  const earnedTable = [10, 11, 12].includes(payload.platform_id) ? 'user_achievement_unlocks' : 'user_achievements';
  const counts = await Promise.all(['achievements', earnedTable].map(async (table) => {
    let query = supabase.from(table).select('*', { count: 'exact', head: true })
      .eq('platform_id', payload.platform_id).eq('platform_game_id', payload.platform_game_id);
    if (table === earnedTable) query = query.eq('user_id', payload.user_id);
    const result = await query;
    if (result.error) throw new Error(`Cannot verify ${table}: ${result.error.message}`);
    if (!Number.isInteger(result.count)) throw new Error(`Missing ${table} count`);
    return result.count;
  }));
  const [definitions, earned] = counts;
  const reportedEarned = Math.max(0, Number(payload.achievements_earned) || 0);
  const total = Math.max(0, Number(payload.total_achievements) || 0, definitions);
  const emptyFetchWithProgress = fetchedDefinitions === 0 && (reportedEarned > 0 || Number(payload.current_score) > 0);
  const xboxScoreWithoutUnlocks = [10, 11, 12].includes(payload.platform_id)
    && Number(payload.current_score) > 0 && earned === 0;
  const incomplete = emptyFetchWithProgress || xboxScoreWithoutUnlocks
    || earned < reportedEarned || definitions < fetchedDefinitions || total < reportedEarned;
  const error = incomplete ? `Incomplete achievement import: saved ${earned}/${reportedEarned} earned and ${definitions}/${fetchedDefinitions} definitions` : null;
  const progress = {
    ...payload,
    achievements_earned: Math.max(reportedEarned, earned),
    total_achievements: total,
    completion_percentage: total > 0 ? Math.min(100, 100 * Math.max(reportedEarned, earned) / total) : 0,
    metadata: {
      ...payload.metadata,
      total_achievements_known: total > 0,
      achievement_import_complete: !incomplete,
      sync_failed: incomplete,
      sync_error: error,
    },
  };
  const result = await supabase.from('user_progress').upsert(progress, {
    onConflict: 'user_id,platform_id,platform_game_id',
  });
  if (result.error) throw new Error(`Failed to save game progress: ${result.error.message}`);
  if (incomplete) throw new Error(error);
  return progress;
}
