import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
test('every clickable tile has WL-generated analysis and traceable coach evidence', async () => {
  const data = JSON.parse(await readFile(new URL('data/training-example.json', import.meta.url)));
  assert.equal(data.Hand.length, 14);
  assert.deepEqual(new Set(data.Choices.map(c => c.Tile)), new Set(data.Hand));
  for (const c of data.Choices) {
    assert.equal(c.Analysis.SelectedAction.Tile, c.Tile);
    assert.equal(c.Evidence.Evidence.Selected, c.Tile);
    assert.equal(c.Analysis.AnalysisRevision, data.AnalysisRevision);
    assert.ok(c.Explanation.length > 0);
    assert.ok(c.Analysis.BestActions.length > 0);
    for (const e of c.Analysis.ActionEvaluations) {
      assert.equal(e.Features.Ukeire, e.Features.EffectiveTiles.reduce((n, t) => n + t.Count, 0));
    }
  }
});
