import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { evaluate } from './kernel.mjs';
const files = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/app.js', ['app.js', 'text/javascript; charset=utf-8']],
  ['/style.css', ['style.css', 'text/css; charset=utf-8']],
  ['/data/training-example.json', ['data/training-example.json', 'application/json; charset=utf-8']],
  ['/game', ['game.html', 'text/html; charset=utf-8']],
  ['/game.js', ['game.js', 'text/javascript; charset=utf-8']],
]);
const server = createServer(async (req, res) => {
  if (new URL(req.url, 'http://localhost').pathname === '/api') {
    const origin = req.headers.origin;
    const port = server.address().port;
    if (req.method !== 'POST' || (origin && ![`http://127.0.0.1:${port}`, `http://localhost:${port}`].includes(origin)) || !req.headers['content-type']?.startsWith('application/json')) { res.writeHead(403); res.end(); return; }
    try {
      let body = '';
      for await (const chunk of req) { body += chunk; if (body.length > 2_000_000) throw new Error('RequestTooLarge'); }
      const request = JSON.parse(body);
      if (!request || typeof request !== 'object' || !['NewGame','Step','Analyze','Replay','Review'].includes(request.Operation)) throw new Error('InvalidRequest');
      const output = await evaluate(request);
      res.writeHead(output.Error ? 422 : 200, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(output));
    } catch (error) { res.writeHead(400, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ Error: error.message })); }
    return;
  }
  const file = files.get(new URL(req.url, 'http://localhost').pathname);
  if (req.method !== 'GET' || !file) { res.writeHead(404); res.end(); return; }
  try {
    const body = await readFile(fileURLToPath(new URL(file[0], import.meta.url)));
    res.writeHead(200, { 'Content-Type': file[1], 'Cache-Control': 'no-store' }); res.end(body);
  } catch { res.writeHead(503); res.end('Run the WL export script first.'); }
});
server.listen(Number(process.env.MAHJONG_PORT ?? 5173), '127.0.0.1', () => console.log(`Local: http://127.0.0.1:${server.address().port}`));
