import test from 'node:test';
import assert from 'node:assert/strict';

import { containsUnexpectedJapanese } from './activity-feed-generator.js';

test('allows Japanese characters inside an official game title', () => {
  assert.equal(
    containsUnexpectedJapanese('Michael gained 50 StatusXP in 黒神話 (10 → 60).', {
      gameTitle: '黒神話',
    }),
    false,
  );
});

test('rejects Japanese surrounding commentary', () => {
  assert.equal(
    containsUnexpectedJapanese('Michaelは黒神話で50 StatusXPを獲得しました。', {
      gameTitle: '黒神話',
    }),
    true,
  );
});

test('allows a supplied Japanese trophy name in English commentary', () => {
  assert.equal(
    containsUnexpectedJapanese('Michael unlocked “旅の始まり” in Wuchang!', {
      gameTitle: 'Wuchang',
      rareTrophies: [{ name: '旅の始まり' }],
    }),
    false,
  );
});
