import test from 'node:test';
import assert from 'node:assert/strict';
import { finalizeGameImport } from './game-import-progress.js';

function fixture(definitions, earned, { countError, writeError } = {}) {
  const saved = [];
  return { saved, from(table) {
    const query = { select() { return this; }, eq() { return this; },
      then(resolve) { return Promise.resolve({ count: table === 'achievements' ? definitions : earned,
        error: countError }).then(resolve); },
      async upsert(row) { saved.push(row); return { error: writeError }; } };
    return query;
  } };
}
const payload = { user_id: 'user', platform_id: 11, platform_game_id: 'game',
  achievements_earned: 3, total_achievements: 10, current_score: 30, metadata: { custom: true } };

test('complete import publishes verified progress and retains metadata', async () => {
  const db = fixture(10, 3);
  const result = await finalizeGameImport(db, payload, { fetchedDefinitions: 10 });
  assert.equal(result.completion_percentage, 30);
  assert.equal(result.metadata.achievement_import_complete, true);
  assert.equal(result.metadata.sync_failed, false);
  assert.equal(result.metadata.custom, true);
});
test('partial earned writes retain reported counts but reject success and require retry', async () => {
  const db = fixture(10, 1);
  await assert.rejects(finalizeGameImport(db, payload, { fetchedDefinitions: 10 }), /Incomplete/);
  assert.equal(db.saved[0].achievements_earned, 3);
  assert.equal(db.saved[0].metadata.sync_failed, true);
});
test('failed definitions reject success even if unlocked writes succeeded', async () => {
  const db = fixture(5, 3);
  await assert.rejects(finalizeGameImport(db, payload, { fetchedDefinitions: 10 }), /Incomplete/);
});
test('unknown catalogue remains explicitly unknown with reported progress retained', async () => {
  const db = fixture(0, 0);
  await assert.rejects(finalizeGameImport(db, { ...payload, total_achievements: 0 }), /Incomplete/);
  assert.equal(db.saved[0].metadata.total_achievements_known, false);
  assert.equal(db.saved[0].achievements_earned, 3);
});
test('empty fetch cannot declare a previously imported scored game complete', async () => {
  await assert.rejects(finalizeGameImport(fixture(10, 3), payload), /Incomplete/);
});

test('a locked catalogue cannot complete an Xbox import with positive gamerscore and no unlocks', async () => {
  const db = fixture(10, 0);
  await assert.rejects(finalizeGameImport(db, { ...payload, achievements_earned: 0 },
    { fetchedDefinitions: 10 }), /Incomplete/);
  assert.equal(db.saved[0].metadata.sync_failed, true);
  assert.equal(db.saved[0].metadata.achievement_import_complete, false);
  assert.equal(db.saved[0].current_score, 30);
});
test('a larger persisted catalogue and earned count cannot be lowered', async () => {
  const result = await finalizeGameImport(fixture(12, 4), payload, { fetchedDefinitions: 10 });
  assert.equal(result.total_achievements, 12);
  assert.equal(result.achievements_earned, 4);
});
test('count query failure does not publish unverified progress', async () => {
  const db = fixture(10, 3, { countError: { message: 'offline' } });
  await assert.rejects(finalizeGameImport(db, payload), /Cannot verify/);
  assert.equal(db.saved.length, 0);
});
test('summary write errors fail the import', async () => {
  await assert.rejects(finalizeGameImport(fixture(10, 3, { writeError: { message: 'offline' } }), payload,
    { fetchedDefinitions: 10 }), /Failed to save/);
});
