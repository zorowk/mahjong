const $ = id => document.getElementById(id);
let data, selected;
const shantenText = n => n === 0 ? '听牌' : n === -1 ? '已和牌' : `${n} 向听`;
function reset() {
  selected = undefined; $('submit').disabled = true; $('result').hidden = true;
  $('selection').textContent = '点击一张牌，选择你的打张';
  for (const b of $('hand').children) { b.classList.remove('selected'); b.setAttribute('aria-pressed', 'false'); }
}
try {
  const response = await fetch('/data/training-example.json');
  if (!response.ok) throw new Error('请先运行 WL 牌例导出脚本。');
  data = await response.json();
  for (const tile of data.Hand) {
    const b = document.createElement('button'); b.className = 'tile'; b.type = 'button';
    b.textContent = tile; b.setAttribute('aria-label', `选择打${tile}`); b.setAttribute('aria-pressed', 'false');
    b.onclick = () => {
      reset(); selected = tile;
      for (const other of $('hand').children) if (other.textContent === tile) { other.classList.add('selected'); other.setAttribute('aria-pressed', 'true'); }
      $('selection').textContent = `已选择：打${tile}`; $('submit').disabled = false;
    }; $('hand').append(b);
  }
  $('version').textContent = `${data.RuleSetVersion} · ${data.AnalysisRevision} · 决策前事件 #${data.EventOffset}`;
  reset();
} catch (error) { $('error').textContent = error.message; $('error').hidden = false; $('selection').textContent = '牌例加载失败'; }
$('reset').onclick = reset;
$('submit').onclick = () => {
  const choice = data.Choices.find(c => c.Tile === selected), a = choice.Analysis;
  $('explanation').textContent = choice.Explanation;
  const feature = a.ActionEvaluations.find(e => e.Action.Tile === selected).Features;
  $('metrics').replaceChildren();
  for (const [label, value] of [['你的打张', selected], ['向听', shantenText(feature.Shanten)], ['有效进张', `${feature.Ukeire} 张`], ['并列最优', a.BestActions.map(b => b.Tile).join(' / ')]]) {
    const card = document.createElement('div'), title = document.createElement('small'), number = document.createElement('strong');
    title.textContent = label; number.textContent = value; card.append(title, number); $('metrics').append(card);
  }
  $('candidates').replaceChildren();
  for (const e of a.ActionEvaluations) {
    const row = document.createElement('tr'); if (e.Action.Tile === selected) row.className = 'chosen';
    for (const value of [e.Action.Tile, shantenText(e.Features.Shanten), `${e.Features.Ukeire} 张`, e.Features.EffectiveTiles.map(t => `${t.Tile} ×${t.Count}`).join('，') || '无']) {
      const cell = document.createElement('td'); cell.textContent = value; row.append(cell);
    } $('candidates').append(row);
  }
  $('evidence').textContent = JSON.stringify(choice.Evidence, null, 2); $('result').hidden = false;
};
