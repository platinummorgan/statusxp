import test from 'node:test';
import assert from 'node:assert/strict';
import { computePsnStatusXpFields } from './psn-statusxp.js';

test('Platinums receive five times the rarity component with the same floor', () => {
  const fields = computePsnStatusXpFields({ rarityPercent: '0.1', isPlatinum: true });
  assert.equal(fields.include_in_score, true);
  assert.equal(fields.is_platinum, true);
  assert.equal(Number(fields.base_status_xp.toFixed(2)), 57.83);
});

test('Platinum rarity changes update its points without removing the Platinum flag', () => {
  const fields = computePsnStatusXpFields({ rarityPercent: 0.2, isPlatinum: true });
  assert.equal(fields.is_platinum, true);
  assert.equal(Number(fields.base_status_xp.toFixed(2)), 57.66);
});

test('only Platinum rarity components increase; ordinary tiers and missing rarity retain their rules', () => {
  for (const rarityPercent of [0, '0', 0.1, 50, 100, null, undefined, 'unknown', -1, 101]) {
    const platinum = computePsnStatusXpFields({ rarityPercent, isPlatinum: true });
    const ordinary = computePsnStatusXpFields({ rarityPercent, isPlatinum: false });
    assert.ok(Math.abs(platinum.base_status_xp - (0.5 + 5 * (ordinary.base_status_xp - 0.5))) < 1e-12);
    assert.equal(ordinary.include_in_score, true);
    assert.equal(ordinary.is_platinum, false);
  }
  assert.equal(computePsnStatusXpFields({ rarityPercent: 0, isPlatinum: true }).base_status_xp, 58);
  assert.equal(computePsnStatusXpFields({ rarityPercent: 0, isPlatinum: false }).base_status_xp, 12);
  assert.equal(Number(computePsnStatusXpFields({ rarityPercent: 1, isPlatinum: true }).base_status_xp.toFixed(2)), 56.29);
  assert.equal(Number(computePsnStatusXpFields({ rarityPercent: 99, isPlatinum: true }).base_status_xp.toFixed(2)), 0.5);
  assert.equal(computePsnStatusXpFields({ rarityPercent: null, isPlatinum: true }).base_status_xp, 0.5);
});
