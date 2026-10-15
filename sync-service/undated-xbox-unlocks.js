export function partitionXboxUnlockRows(rows, evidenceSource) {
  const dated = [];
  const undated = [];
  for (const row of rows) {
    if (row.earned_at) dated.push(row);
    else {
      const { earned_at, ...key } = row;
      undated.push({ ...key, evidence_source: evidenceSource });
    }
  }
  return { dated, undated };
}

export async function saveUndatedXboxUnlocks(client, rows, chunkSize = 200) {
  for (let offset = 0; offset < rows.length; offset += chunkSize) {
    const { error } = await client.from('user_undated_achievements').upsert(rows.slice(offset, offset + chunkSize), {
      onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
    });
    if (error) throw new Error(`Failed to save confirmed undated unlocks: ${error.message}`);
  }
}
