import { spawn } from 'node:child_process';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
let active = 0;
export async function evaluate(request) {
  if (active >= 2) throw new Error('KernelBusy');
  active++;
  let directory;
  try {
    directory = await mkdtemp(join(tmpdir(), 'mahjong-request-'));
    const path = join(directory, 'request.json');
    await writeFile(path, JSON.stringify(request), { mode: 0o600 });
    const script = fileURLToPath(new URL('../src/Api.wls', import.meta.url));
    const executable = process.env.WOLFRAMSCRIPT || '/Applications/Wolfram.app/Contents/MacOS/wolframscript';
    return await new Promise((resolve, reject) => {
      const child = spawn(executable, ['-code', `Get[${JSON.stringify(script)}];Exit[0]`], { env: { ...process.env, MAHJONG_REQUEST_PATH: path }, shell: false });
      let stdout = '', stderr = '';
      const timer = setTimeout(() => { child.kill('SIGTERM'); reject(new Error('KernelTimeout')); }, 30000);
      child.on('error', error => { clearTimeout(timer); reject(error); });
      child.stdout.on('data', data => { stdout += data.toString(); if (stdout.length > 4_000_000) child.kill('SIGTERM'); });
      child.stderr.on('data', data => { stderr += data.toString(); });
      child.on('close', code => {
        clearTimeout(timer);
        if (code !== 0) { reject(new Error(`KernelFailed: ${(stderr || stdout).slice(0, 300)}`)); return; }
        try { resolve(JSON.parse(stdout.trim())); } catch { reject(new Error('KernelInvalidOutput')); }
      });
    });
  } finally { if (directory) await rm(directory, { recursive: true, force: true }); active--; }
}
