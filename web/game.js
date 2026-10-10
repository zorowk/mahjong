const $ = id => document.getElementById(id);
let game, pending, historical = false, busy = false;
function controls() {
  document.querySelectorAll('button').forEach(b => { b.disabled = busy || b.dataset.unavailable === 'true'; });
  $('commit').disabled = busy || historical || !pending;
  $('timeline').disabled = busy || !game; $('load').disabled = busy; $('player').disabled = busy;
}
async function call(request) {
  const r = await fetch('/api', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(request) });
  const value = await r.json(); if (!r.ok || value.Error) throw new Error(value.Error || '请求失败'); return value;
}
async function run(fn) {
  if (busy) return; busy = true; $('error').textContent = ''; $('status').textContent = 'Wolfram 正在计算…';
  document.querySelectorAll('button').forEach(b => { b.disabled = true; });
  try { await fn(); } catch (e) { $('error').textContent = e.message; $('status').textContent = '计算未完成，可重试。'; }
  finally { busy = false; controls(); }
}
function render(view) {
  const o = view.Observation;
  if (!historical) game = view.Game;
  pending = undefined; $('feedback').hidden = true; $('hand').replaceChildren(); $('actions').replaceChildren();
  $('status').textContent = view.Result ? `本局结束：${JSON.stringify(view.Result.Balances)}` : `玩家 ${view.Player} · ${o.Phase} · 牌墙剩余 ${o.WallCount} 张${historical ? ' · 历史只读视角' : ''}`;
  $('label').textContent = `玩家 ${view.Player} 的手牌`;
  for (const tile of o.Hand) { const b = document.createElement('button'); b.className = 'tile'; b.textContent = tile;
    const action = view.LegalActions.find(a => a.Type === 'Discard' && a.Tile === tile);
    b.onclick = () => { if (!historical && action) run(async () => { const out = await call({ Operation: 'Analyze', Game: game, Action: action }); pending = action; $('explanation').textContent = out.Explanation; $('evidence').textContent = JSON.stringify(out, null, 2); $('feedback').hidden = false; $('status').textContent = `打${tile}的牌效分析已完成`; }); };
    b.setAttribute('aria-label', `分析打${tile}`); b.dataset.unavailable = String(!action || historical); $('hand').append(b); }
  for (const action of view.LegalActions.filter(a => a.Type !== 'Discard')) { const b = document.createElement('button');
    b.textContent = `${{ Pass: '过', Hu: '胡', Peng: '碰', Gang: '杠', Liangdao: '亮倒并打' }[action.Type] || action.Type} ${action.Tile || ''} ${action.Kind || ''}`;
    b.dataset.unavailable = String(historical); b.onclick = () => { if (!historical) run(async () => render(await call({ Operation: 'Step', Game: game, Action: action }))); }; $('actions').append(b); }
  $('public').textContent = JSON.stringify({ 副露: o.Melds, 弃牌: o.Discards, 亮倒手牌: o.RevealedHands }, null, 2);
  $('timeline').max = game.Events.length; $('timeline').value = historical ? $('timeline').value : game.Events.length;
  $('offset').textContent = `事件 ${$('timeline').value} / ${game.Events.length}`;
  controls();
}
$('new').onclick = () => run(async () => { historical = false; render(await call({ Operation: 'NewGame', Seed: Math.floor(Math.random() * 1_000_000) })); });
$('commit').onclick = () => { if (pending && !historical) run(async () => render(await call({ Operation: 'Step', Game: game, Action: pending }))); };
$('review').onclick = () => { if (game) run(async () => { $('reviews').textContent = JSON.stringify(await call({ Operation: 'Review', Game: game, Player: Number($('player').value) }), null, 2); $('status').textContent = '整局打张分析已完成'; }); };
$('replay').onclick = () => { if (game) run(async () => { historical = true; render(await call({ Operation: 'Replay', Game: game, EventOffset: Number($('timeline').value) })); }); };
$('latest').onclick = () => { if (game) run(async () => { historical = false; render(await call({ Operation: 'Replay', Game: game })); }); };
$('save').onclick = () => { if (!game) return; const u = URL.createObjectURL(new Blob([JSON.stringify(game, null, 2)], { type: 'application/json' })); const a = document.createElement('a'); a.href = u; a.download = `${game.GameId}.json`; a.click(); URL.revokeObjectURL(u); };
$('load').onchange = () => { const file = $('load').files[0]; if (file) run(async () => { const imported = JSON.parse(await file.text()); const view = await call({ Operation: 'Replay', Game: imported }); historical = false; render(view); }); };
controls();
