export function steamOwnedGames(payload) {
  const response = payload?.response;
  const count = response?.game_count;
  if (!Number.isSafeInteger(count) || count < 0) {
    throw new Error('Steam did not provide an accessible games list. Set Steam Game details visibility to Public, then sync again. Existing stats have been retained.');
  }
  const games = response.games ?? (count === 0 ? [] : null);
  if (!Array.isArray(games) || games.length !== count || games.some(game => !Number.isSafeInteger(game?.appid) || game.appid <= 0)) {
    throw new Error('Steam returned an incomplete games list. Try syncing again. Existing stats have been retained.');
  }
  return games;
}
export function psnTitlePage(payload) {
  if (!Array.isArray(payload?.trophyTitles)) {
    throw new Error('PlayStation did not provide a valid trophy games list. Try syncing again. Existing stats have been retained.');
  }
  return payload.trophyTitles;
}
