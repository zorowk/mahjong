import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluate } from './kernel.mjs';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

test('live Wolfram: UTF-8, actions, replay, analysis, review and invalid imports', { timeout: 120_000 }, async () => {
  const initial = await evaluate({ Operation: 'NewGame', Seed: 42 });
  assert.equal(initial.Game.RuleSetVersion, 'xiaogan-kawuxing-1.1');
  assert.match(initial.Game.Events[0].Wall[0], /^[1-9][筒条]$|^[中发白]$/u);
  assert.equal(initial.Observation.Hand.length, 14);
  assert.equal(initial.Observation.WallCount, 44);
  assert.equal(initial.Observation.Wall, undefined);
  const action = initial.LegalActions.find(a => a.Type === 'Discard');
  const analyzed = await evaluate({ Operation: 'Analyze', Game: initial.Game, Action: action });
  assert.equal(analyzed.Analysis.AnalysisRevision, '2026-10-kawuxing-v3');
  assert.ok(analyzed.Explanation.includes('当前牌效模型'));
  const discarded = await evaluate({ Operation: 'Step', Game: initial.Game, Action: action });
  assert.equal(discarded.Observation.Phase, 'Response');
  let next = discarded;
  for (let n = 0; n < 2; n++) next = await evaluate({ Operation: 'Step', Game: next.Game, Action: next.LegalActions.find(a => a.Type === 'Pass') });
  assert.equal(next.Player, 2);
  assert.equal(next.Observation.Hand.length, 14);
  assert.equal(next.Observation.WallCount, 43);
  const replay = await evaluate({ Operation: 'Replay', Game: next.Game });
  assert.deepEqual(replay.Observation, next.Observation);
  const historical = await evaluate({ Operation: 'Replay', Game: next.Game, EventOffset: 4 });
  assert.deepEqual(historical.Observation, initial.Observation);
  const review = await evaluate({ Operation: 'Review', Game: next.Game, Player: 1 });
  assert.equal(review.DecisionAnalyses.length, 1);
  assert.equal(review.Explanations.length, review.Reviews.length);
  const bad = structuredClone(next.Game); bad.Events[0].Wall[0] = 'invalid';
  assert.equal((await evaluate({ Operation: 'Replay', Game: bad })).Error, 'InvalidInitialWall');
  assert.equal((await evaluate({ Operation: 'Step', Game: next.Game, Action: { Type: 'Draw', Player: 1, Tile: '1筒' } })).Error, 'InvalidDraw');
  assert.equal((await evaluate({ Operation: 'NewGame', Seed: 'bad' })).Error, 'InvalidSeed');
});

test('HTTP pages and local-only API', { timeout: 30_000 }, async () => {
  const child = spawn(process.execPath, [fileURLToPath(new URL('server.mjs', import.meta.url))], { env: { ...process.env, MAHJONG_PORT: '0' }, stdio: ['ignore', 'pipe', 'pipe'] });
  try {
    const base = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('ServerStartupTimeout')), 5000);
      child.once('error', e => { clearTimeout(timer); reject(e); });
      child.once('exit', code => { clearTimeout(timer); reject(new Error(`ServerExited:${code}`)); });
      child.stdout.once('data', data => { clearTimeout(timer); resolve(data.toString().trim().replace('Local: ', '')); });
    });
    assert.equal((await fetch(`${base}/game`)).status, 200);
    assert.equal((await fetch(`${base}/game.js`)).status, 200);
    assert.equal((await fetch(`${base}/api`)).status, 403);
    assert.equal((await fetch(`${base}/../src/Rules.wl`)).status, 404);
    assert.equal((await fetch(`${base}/api`, { method: 'POST', headers: { 'Content-Type': 'application/json', Origin: 'https://untrusted.example' }, body: '{}' })).status, 403);
    const response = await fetch(`${base}/api`, { method: 'POST', headers: { 'Content-Type': 'application/json', Origin: base }, body: JSON.stringify({ Operation: 'NewGame', Seed: 7 }) });
    assert.equal(response.status, 200);
    assert.equal((await response.json()).Observation.Hand.length, 14);
  } finally { child.kill('SIGTERM'); }
});
