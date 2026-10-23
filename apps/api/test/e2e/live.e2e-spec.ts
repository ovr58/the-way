/**
 * Процесс как у проверяющего (план, «Замороженные проверки», сквозные): собранный
 * `node dist/main.js` с `PORT`, ожидание `GET /health` → `{ok: true}`, вход `POST /auth/verify`
 * кодом 111111 → токен. Требует `npm run build --workspace=api` до прогона.
 */
import { type ChildProcess, spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

const API_DIR = join(__dirname, '..', '..');
const MAIN = join(API_DIR, 'dist', 'main.js');
const PORT = process.env.PORT ?? '3001';
const BASE = `http://127.0.0.1:${PORT}`;
const START_TIMEOUT_MS = 30_000;

function randomPhone(): string {
  return `+7991${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
}

let child: ChildProcess | undefined;
let output = '';

async function waitForHealth(): Promise<unknown> {
  const deadline = Date.now() + START_TIMEOUT_MS;
  while (Date.now() < deadline) {
    if (child?.exitCode !== null && child?.exitCode !== undefined) {
      throw new Error(`API завершился с кодом ${child.exitCode}:\n${output.slice(-2000)}`);
    }
    try {
      const res = await fetch(`${BASE}/health`, { signal: AbortSignal.timeout(2000) });
      if (res.status === 200) return res.json();
    } catch {
      // ещё не слушает порт
    }
    await new Promise((r) => setTimeout(r, 300));
  }
  throw new Error(`API не ответил на /health за ${START_TIMEOUT_MS} мс:\n${output.slice(-2000)}`);
}

beforeAll(() => {
  if (!existsSync(MAIN)) throw new Error(`Нет ${MAIN}: сначала npm run build --workspace=api`);
  child = spawn(process.execPath, [MAIN], { cwd: API_DIR, env: { ...process.env, PORT }, stdio: ['ignore', 'pipe', 'pipe'] });
  child.stdout?.on('data', (chunk: Buffer) => (output += chunk.toString()));
  child.stderr?.on('data', (chunk: Buffer) => (output += chunk.toString()));
});

afterAll(async () => {
  if (child && child.exitCode === null) {
    const exited = new Promise((r) => child?.once('exit', r));
    child.kill();
    await exited;
  }
});

it('собранный API отвечает /health и пускает кодом 111111', async () => {
  expect(await waitForHealth()).toEqual({ ok: true });
  const res = await fetch(`${BASE}/auth/verify`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ phone: randomPhone(), code: '111111' }),
    signal: AbortSignal.timeout(5000),
  });
  expect(res.status).toBe(200);
  const body = (await res.json()) as { token?: string };
  expect(typeof body.token).toBe('string');
});
