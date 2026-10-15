import {test} from 'node:test';
import assert from 'node:assert/strict';
import {steamOwnedGames,psnTitlePage} from './provider-library-response.js';
test('unavailable Steam library cannot report successful empty sync',()=>{
 for(const payload of [{},{response:{}},{response:{games:[]}},null]) assert.throws(()=>steamOwnedGames(payload),/accessible games list/);
});
test('verified empty Steam library and complete nonempty list are accepted',()=>{
 assert.deepEqual(steamOwnedGames({response:{game_count:0}}),[]);
 assert.deepEqual(steamOwnedGames({response:{game_count:1,games:[{appid:10}]}}),[{appid:10}]);
});
test('partial or malformed Steam library is rejected before importing games',()=>{
 for(const response of [{game_count:2,games:[{appid:10}]},{game_count:1},{game_count:0,games:[{appid:10}]},{game_count:1,games:[{}]}]) assert.throws(()=>steamOwnedGames({response}),/incomplete/);
});
test('missing PSN titles is an error; explicit empty page is accepted',()=>{
 for(const value of [null,{}, {error:'Forbidden'}, {trophyTitles:null}]) assert.throws(()=>psnTitlePage(value),/valid trophy games list/);
 assert.deepEqual(psnTitlePage({trophyTitles:[]}),[]);
});
