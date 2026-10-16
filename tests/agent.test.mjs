// 本地管家（agent）端到端测试：真实 llama-server + 真实模型。
// 用法：node tests/agent.test.mjs <windows|perl> <安装目录>
//   windows：安装目录里放 jev/llama/llama-server.exe 和模型，测试会把 jev/windows/agent.ps1 拷进去
//   perl   ：同上，放 jev/llama/llama-server，拷 jev/unix/agent.pl（在 Linux/macOS 上跑）
// 测试用 38xxx 端口，不碰正式安装（8001/8002）。
import { spawn, execFileSync } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const Core = require('../js/core.js');
const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const [impl, instArg] = process.argv.slice(2);
if (!['windows', 'perl'].includes(impl) || !instArg) { console.error('usage: agent.test.mjs <windows|perl> <installDir>'); process.exit(2); }
const INST = path.resolve(instArg);
const IS_WIN = impl === 'windows';
const AGENT_PORTS = [38002, 38012, 38022];
const LLAMA_PORTS = [38001, 38011, 38021];
const ORIGIN = 'https://genuineedu.pages.dev';
const LLAMA_BIN = path.join(INST, 'jev', 'llama', IS_WIN ? 'llama-server.exe' : 'llama-server');
const MODEL = path.join(INST, 'jev', 'Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf');

const sleep = ms => new Promise(r => setTimeout(r, ms));
let passed = 0, failed = 0;
function check(cond, msg) {
  if (cond) { passed++; console.log('  ✓ ' + msg); }
  else { failed++; console.log('  ✗ ' + msg); }
}

if (IS_WIN) for (const f of ['agent.ps1', 'launch.js']) fs.copyFileSync(path.join(ROOT, 'jev/windows', f), path.join(INST, f));
else { fs.copyFileSync(path.join(ROOT, 'jev/unix/agent.pl'), path.join(INST, 'agent.pl')); fs.chmodSync(path.join(INST, 'agent.pl'), 0o755); }

function writeConfig(extra = {}) {
  fs.writeFileSync(path.join(INST, 'config.json'), JSON.stringify({
    agentPorts: AGENT_PORTS, llamaPorts: LLAMA_PORTS,
    allowedOrigins: ['https://genuineedu.pages.dev', 'https://*.genuineedu.pages.dev', 'http://localhost:*'],
    heartbeatTimeout: 6, byeGrace: 3, launchGrace: 8, errorLinger: 4, startupTimeout: 90, sleepIdle: 300, ctxSize: 2048,
    ...extra,
  }));
}

function runAgent(action) {
  const cmd = IS_WIN ? 'powershell.exe' : 'perl';
  const args = IS_WIN
    ? ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', path.join(INST, 'agent.ps1'), action]
    : [path.join(INST, 'agent.pl'), action];
  if (action === 'start') {
    // Windows：和 jev:// 协议完全相同的路径（wscript → launch.js → 隐藏的 powershell）；unix 版自己转入后台
    if (IS_WIN) spawn('wscript.exe', ['//B', '//Nologo', '//E:jscript', path.join(INST, 'launch.js'), 'jev://start/'], { stdio: 'ignore' });
    else spawn(cmd, args, { detached: true, stdio: 'ignore' }).unref();
    return Promise.resolve(0);
  }
  const p = spawn(cmd, args, { stdio: 'ignore', windowsHide: true });
  return new Promise(r => p.on('exit', code => r(code)));
}

async function http(port, p, { origin = ORIGIN, method = 'GET', headers = {}, body } = {}) {
  const h = { ...headers };
  if (origin) h.Origin = origin;
  try {
    const r = await fetch(`http://127.0.0.1:${port}${p}`, { method, headers: h, body, signal: AbortSignal.timeout(3000) });
    const text = await r.text();
    let json = null; try { json = JSON.parse(text); } catch (_) { /* 非 JSON */ }
    return { status: r.status, headers: r.headers, json, text };
  } catch (_) { return null; }
}

async function findAgent() {
  for (const port of AGENT_PORTS) {
    const r = await http(port, '/status', { origin: null });
    if (r && r.json && r.json.app === 'jev-agent') return { port, st: r.json };
  }
  return null;
}

async function waitFor(fn, timeout, step = 300) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const v = await fn();
    if (v) return v;
    await sleep(step);
  }
  return null;
}

function ownLlamaPids() {
  try {
    if (IS_WIN) {
      const out = execFileSync('powershell.exe', ['-NoProfile', '-Command',
        `@(Get-Process llama-server -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq '${LLAMA_BIN.replace(/'/g, "''")}' } | ForEach-Object { $_.Id }) -join ','`], { encoding: 'utf8' });
      return out.trim() ? out.trim().split(',').map(Number) : [];
    }
    const out = execFileSync('pgrep', ['-f', LLAMA_BIN], { encoding: 'utf8' });
    return out.trim().split(/\s+/).filter(Boolean).map(Number);
  } catch (_) { return []; }
}

async function agentGone(timeout) {
  return waitFor(async () => (!(await findAgent()) && ownLlamaPids().length === 0) ? true : null, timeout, 500);
}

async function startReady(label) {
  runAgent('start');
  const a = await waitFor(async () => { const x = await findAgent(); return x && x.st.state === 'ready' ? x : null; }, 90000, 500);
  check(!!a, `${label}：管家启动并报告 ready`);
  return a;
}

async function judge(llama, meaning, answer) {
  const ds = [];
  for (const k of [0, 1]) {
    const r = await fetch(llama.url + '/completion', {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Api-Key': llama.key, Origin: ORIGIN },
      body: JSON.stringify({ prompt: Core.jevPrompt(meaning, answer, k), n_predict: 1, temperature: 0, n_probs: 32, cache_prompt: false }),
    });
    const d = Core.jevMargin(await r.json());
    if (d === null) return null;
    ds.push(d);
  }
  return Core.jevProbability(ds[0], ds[1]);
}

function listen(port) {
  return new Promise((resolve, reject) => {
    const s = net.createServer(c => { c.on('error', () => {}); c.end('HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nno'); });
    s.once('error', reject);
    s.listen(port, '127.0.0.1', () => resolve(s));
  });
}

async function cleanup() {
  await runAgent('stop');
  await agentGone(15000);
}

// ======================================================================
async function main() {
  console.log(`agent 测试（${impl}）：${INST}`);
  check(fs.existsSync(LLAMA_BIN) && fs.existsSync(MODEL), '测试安装目录里有 llama-server 和模型');
  writeConfig();
  await cleanup();

  console.log('\n[1] 启动、跨域与密钥');
  let a = await startReady('首次启动');
  if (!a) throw new Error('agent never became ready');
  check(a.port === AGENT_PORTS[0], `管家用首选端口 ${AGENT_PORTS[0]}`);
  const st = (await http(a.port, '/ping?c=tabA')).json;
  check(st.llama && /^http:\/\/127\.0\.0\.1:38001$/.test(st.llama.url), 'llama 地址在首选端口：' + (st.llama && st.llama.url));
  check(typeof st.key === 'string' && st.key.length >= 16, '下发一次性密钥');
  const evil = await http(a.port, '/ping?c=evil', { origin: 'https://evil.example' });
  check(evil && evil.status === 403 && !evil.headers.get('access-control-allow-origin'), '陌生网站的请求被 403 拒绝且无 CORS 头');
  const ok = await http(a.port, '/status');
  check(ok.headers.get('access-control-allow-origin') === ORIGIN, '白名单网站拿到 CORS 头');
  const prev = await http(a.port, '/ping', { method: 'OPTIONS', headers: { 'Access-Control-Request-Method': 'GET', 'Access-Control-Request-Private-Network': 'true' } });
  check(prev.status === 204 && prev.headers.get('access-control-allow-private-network') === 'true', 'CORS 预检返回 204 + Private-Network 许可');
  const sub = await http(a.port, '/status', { origin: 'https://preview-123.genuineedu.pages.dev' });
  check(sub.status === 200, '预览域名（*.genuineedu.pages.dev）也放行');
  const look = await http(a.port, '/status', { origin: 'https://genuineedu.pages.dev.evil.example' });
  check(look.status === 403, '形似域名 genuineedu.pages.dev.evil.example 被拒绝');
  const nokey = await fetch(st.llama.url + '/completion', { method: 'POST', body: '{"prompt":"hi","n_predict":1}' });
  check(nokey.status === 401, 'llama-server 不带密钥直接调用 → 401');
  const p1 = await judge(st.llama, '尴尬的', '令人难堪的');
  const p2 = await judge(st.llama, '工资', '火焰');
  check(p1 !== null && p1 >= 0.9, `近义判为接近 p=${p1 && p1.toFixed(3)}`);
  check(p2 !== null && p2 < 0.5, `无关判为不接近 p=${p2 && p2.toFixed(3)}`);

  console.log('\n[2] 重复启动不会多开');
  await runAgent('start');
  await sleep(2500);
  check(ownLlamaPids().length === 1, '第二次 start 后仍只有 1 个 llama-server');
  check((await findAgent()).st.key === st.key, '原管家继续服务（密钥未变）');

  console.log('\n[3] 多标签页：关一个不影响另一个');
  await http(a.port, '/ping?c=tabB');
  await http(a.port, '/bye?c=tabA', { method: 'POST', body: 'x' });
  await sleep(4500);   // > byeGrace
  check(!!(await findAgent()), 'tabA 关闭后 tabB 还在 → 服务继续');
  await http(a.port, '/bye?c=tabB', { method: 'POST', body: 'x' });
  check(!!(await agentGone(12000)), '最后一个标签页关闭 → 管家与 llama-server 一起退出');

  console.log('\n[4] 刷新页面（bye 后马上 ping）不误杀');
  a = await startReady('再次启动');
  await http(a.port, '/ping?c=tab1');
  await http(a.port, '/bye?c=tab1', { method: 'POST', body: 'x' });
  await sleep(500);
  await http(a.port, '/ping?c=tab2');
  await sleep(4500);
  check(!!(await findAgent()), '刷新后的新页面接上 → 服务继续');

  console.log('\n[5] 心跳超时（浏览器崩溃 / 休眠，没来得及 bye）');
  check(!!(await agentGone(16000)), '6 秒无心跳 → 自动退出');

  console.log('\n[6] 启动后从没有网页连上');
  runAgent('start');
  await waitFor(findAgent, 30000);
  check(!!(await agentGone(25000)), 'launchGrace 内没有网页 ping → 自动退出');

  console.log('\n[7] /stop');
  a = await startReady('启动');
  await http(a.port, '/ping?c=t');
  await http(a.port, '/stop?c=t');
  check(!!(await agentGone(10000)), '/stop 后管家与 llama-server 退出');

  console.log('\n[8] 端口被别的程序占用');
  const s1 = await listen(AGENT_PORTS[0]);
  const s2 = await listen(LLAMA_PORTS[0]);
  a = await startReady('端口冲突下启动');
  if (a) {
    check(a.port === AGENT_PORTS[1], `管家改用备用端口 ${AGENT_PORTS[1]}`);
    check(a.st.llama && a.st.llama.url.endsWith(':' + LLAMA_PORTS[1]), 'llama 改用备用端口 ' + (a.st.llama && a.st.llama.url));
    await http(a.port, '/stop');
    await agentGone(10000);
  }
  const still = await fetch(`http://127.0.0.1:${LLAMA_PORTS[0]}/`).then(r => r.text()).catch(() => null);
  check(still === 'no', '占用端口的别家程序没被误杀');
  s1.close(); s2.close();

  console.log('\n[9] 清理残留的 llama-server（只清自己的）');
  const orphan = spawn(LLAMA_BIN, ['-m', path.basename(MODEL), '--host', '127.0.0.1', '--port', String(LLAMA_PORTS[2]), '--no-webui'],
    { cwd: path.dirname(MODEL), detached: true, stdio: 'ignore', windowsHide: true });
  orphan.unref();
  await sleep(1500);
  check(ownLlamaPids().includes(orphan.pid) || !IS_WIN, '制造一个残留 llama-server');
  a = await startReady('有残留时启动');
  const pids = ownLlamaPids();
  check(!pids.includes(orphan.pid) && pids.length === 1, '残留进程被清掉，只剩管家自己的 1 个');
  await cleanup();

  console.log('\n[10] stop 命令在管家不在时也能清残留');
  const orphan2 = spawn(LLAMA_BIN, ['-m', path.basename(MODEL), '--host', '127.0.0.1', '--port', String(LLAMA_PORTS[2]), '--no-webui'],
    { cwd: path.dirname(MODEL), detached: true, stdio: 'ignore', windowsHide: true });
  orphan2.unref();
  await sleep(1500);
  await runAgent('stop');
  await sleep(1000);
  check(ownLlamaPids().length === 0, 'stop 清掉无主的 llama-server');

  console.log('\n[11] 模型缺失 → 报告错误而不是无声失败');
  const moved = MODEL + '.bak';
  fs.renameSync(MODEL, moved);
  try {
    runAgent('start');
    const e = await waitFor(async () => { const x = await findAgent(); return x && x.st.state === 'error' ? x : null; }, 30000);
    check(e && e.st.error === 'model_missing', '状态 error / model_missing');
    check(!!(await agentGone(20000)), '报告一段时间后自动退出');
  } finally { fs.renameSync(moved, MODEL); }

  console.log('\n[12] 配置文件损坏 → 用默认值照常工作');
  fs.writeFileSync(path.join(INST, 'config.json'), '{ broken');
  runAgent('start');
  const d = await waitFor(async () => (await http(8002, '/status', { origin: null })) || null, 30000);
  check(d && d.json && d.json.app === 'jev-agent', '坏配置下回落到默认端口 8002 启动');
  await runAgent('stop');
  await waitFor(async () => !(await http(8002, '/status', { origin: null })), 15000);
  writeConfig();

  console.log(`\n结果：${passed} 通过，${failed} 失败`);
  process.exit(failed ? 1 : 0);
}

main().catch(async e => { console.error(e); await cleanup(); process.exit(1); });
