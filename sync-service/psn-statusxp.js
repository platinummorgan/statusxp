export function computePsnStatusXpFields({ rarityPercent, isPlatinum }) {
  // Missing rarity follows the same common-trophy default on every PSN tier.
  let baseStatusXP = 0.5;
  const rarityWeight = isPlatinum ? 5 : 1;

  if (rarityPercent != null && !Number.isNaN(Number(rarityPercent))) {
    const rarity = Number(rarityPercent);
    const inverseRarity = Math.max(0, Math.min(1, 1 - rarity / 100));
    baseStatusXP = 0.5 + 11.5 * rarityWeight * Math.pow(inverseRarity, 3);
    baseStatusXP = Math.max(0.5, Math.min(0.5 + 11.5 * rarityWeight, baseStatusXP));
  }

  return {
    base_status_xp: baseStatusXP,
    include_in_score: true,
    is_platinum: Boolean(isPlatinum),
  };
}
