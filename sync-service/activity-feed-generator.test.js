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

import { buildTemplateStory, buildStoryFacts, renderStoryDraft, generateActivityStory } from './activity-feed-generator.js';
const change = { source: 'psn', gameTitle: 'PAINT BALL', gameCount: 2, platinumChange: 2, platinumNew: 4255, goldCount: 22 };
test('fallback names stacked games and preserves platinum facts', () => {
 const story = buildTemplateStory('Player', change);
 assert.match(story, /2 platinums/); assert.match(story, /22 Gold/); assert.match(story, /PAINT BALL/); assert.match(story, /4,255/);
});
test('imports never claim newly earned trophies', () => {
 assert.match(buildTemplateStory('Player', { ...change, isImport: true }), /previously earned/);
});
test('AI cannot change numbers, omit a game, or inject extra placeholders', () => {
 const facts = buildStoryFacts('Player', change);
 assert.equal(renderStoryDraft('{PLAYER} earned 999 trophies {GAMES}. {EXTRA}', facts), null);
 assert.equal(renderStoryDraft('{PLAYER} earned {ACTIVITY}. {EXTRA}', facts), null);
 assert.equal(renderStoryDraft('{PLAYER} earned {ACTIVITY} {GAMES}. {BAD} {EXTRA}', facts), null);
 assert.equal(renderStoryDraft('{PLAYER} set a world record with {ACTIVITY} {GAMES}. {EXTRA}', facts), null);
 assert.match(renderStoryDraft('Another goal checked off! {PLAYER} earned {ACTIVITY} {GAMES}. {EXTRA}', facts), /2 platinums/);
});
test('truncated AI output falls back to a complete accurate story', async () => {
 const result = await generateActivityStory('Player', change, { client: { chat: { completions: { create: async () => ({ choices: [{ finish_reason: 'length', message: { content: 'unfinished' } }] }) } } } });
 assert.equal(result.success, false); assert.match(result.story, /PAINT BALL/);
});
test('valid AI prose preserves non-English proper names verbatim', async () => {
 const result = await generateActivityStory('Player', { ...change, gameTitle: '黒神話' }, { client: { chat: { completions: { create: async () => ({ choices: [{ finish_reason: 'stop', message: { content: '{PLAYER} earned {ACTIVITY} {GAMES}. {EXTRA}' } }] }) } } } });
 assert.equal(result.success, true); assert.match(result.story, /黒神話/);
});

test('empty optional facts do not reject an otherwise complete AI story', () => {
 const facts = buildStoryFacts('Dex-Morgan', { source: 'psn', gameTitle: 'Oblivion', gameCount: 1, bronzeCount: 2 });
 assert.equal(renderStoryDraft('{PLAYER} picked up {ACTIVITY} {GAMES}.', facts), 'Dex-Morgan picked up 2 Bronze in Oblivion.');
});
test('accepts expanded facts with conjunctions and punctuation inside trophy quotes', () => {
 const facts = buildStoryFacts('Dex-Morgan', { source: 'psn', gameTitle: 'Oblivion', gameCount: 1, silverCount: 2, bronzeCount: 4, highlight: { name: 'Guildmaster, Thieves Guild' } });
 const story = renderStoryDraft('Dex-Morgan unlocked “Guildmaster, Thieves Guild.” Their haul: 2 Silver and 4 Bronze in Oblivion.', facts);
 assert.ok(story); assert.match(story, /2 Silver, 4 Bronze/); assert.match(story, /Thieves Guild/);
 assert.equal(renderStoryDraft('Dex-Morgan unlocked “Guildmaster, Thieves Guild.” Their haul: 20 Silver and 4 Bronze in Oblivion.', facts), null);
});
test('a supplied highlight is required and survives fallback', () => {
 const c = { source: 'psn', gameTitle: 'Oblivion', gameCount: 1, bronzeCount: 2, highlight: { name: 'Silencer, Dark Brotherhood' } };
 assert.equal(renderStoryDraft('{PLAYER} earned {ACTIVITY} {GAMES}.', buildStoryFacts('Dex', c)), null);
 assert.match(buildTemplateStory('Dex', c), /Silencer, Dark Brotherhood/);
});
