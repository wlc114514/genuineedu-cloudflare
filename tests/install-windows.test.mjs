// Windows 安装器端到端：本地 HTTP 服务模拟网站与下载镜像，真实安装、真实协议唤起、卸载。
// 用法：node tests/install-windows.test.mjs   （需要 .testcache 里有 llama zip 和模型）
// 用 jevtest:// 协议名测试，不碰正式的 jev:// 注册。
import { spawn, execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const TC = path.join(ROOT, '.testcache');
const SERVE = path.join(TC, 'serve');
const INST = path.join(TC, 'win-install');
const ISO = path.join(TC, 'isolated');
const PORT = 38080;
const ORIGIN = `http://127.0.0.1:${PORT}`;
const MODEL_NAME = 'Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf';
const MODEL_SRC = process.env.JEV_MODEL_SRC || path.join(process.env.LOCALAPPDATA, 'Programs', 'JEV', 'jev', MODEL_NAME);
const sleep = ms => new Promise(r => setTimeout(r, ms));
let passed = 0, failed = 0;
const check = (c, m) => { c ? passed++ : failed++; console.log(`  ${c ? '✓' : '✗'} ${m}`); };

function ps(command) {
  return new Promise(resolve => {
    // 故意保留继承来的 PSModulePath（从 PowerShell 7 里启动时会被污染）：安装器必须自己扛住
    const p = spawn('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', '[Console]::OutputEncoding = [Text.Encoding]::UTF8; ' + command], { stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    p.stdout.on('data', d => { out += d; });
    p.stderr.on('data', d => { out += d; });
    p.on('exit', code => resolve({ code, out }));
  });
}
const q = s => `'${String(s).replace(/'/g, "''")}'`;
function install(extra = '') {
  return ps(`& ${q(path.join(ISO, 'install.ps1'))} -Origin ${q(ORIGIN)} -InstallDir ${q(INST)} -Scheme jevtest `
    + `-LlamaUrls ${q(ORIGIN + '/nope/llama.zip')},${q(ORIGIN + '/files/llama.zip')} `
    + `-ModelUrls ${q(ORIGIN + '/nope/model.gguf')},${q(ORIGIN + '/files/model.gguf')} ${extra}; exit $LASTEXITCODE`);
}
async function agentStatus() {
  for (const p of [8002, 18002, 28002]) {
    try {
      const r = await fetch(`http://127.0.0.1:${p}/status`, { signal: AbortSignal.timeout(1500) });
      const j = await r.json();
      if (j.app === 'jev-agent') return j;
    } catch (_) { /* 下一个 */ }
  }
  return null;
}
async function waitFor(fn, ms) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(500); }
  return null;
}
async function stopAgent() {
  if (fs.existsSync(path.join(INST, 'agent.ps1'))) await ps(`& ${q(path.join(INST, 'agent.ps1'))} stop`);
  await waitFor(async () => !(await agentStatus()), 15000);
}
function reg(key, value) {
  try { return execFileSync('reg', ['query', key, ...(value === undefined ? ['/ve'] : ['/v', value])], { encoding: 'utf8' }); } catch (_) { return ''; }
}
function cleanupRegistry() {
  for (const k of ['HKCU\\Software\\Classes\\jevtest', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\GenuineEduJEV-jevtest']) {
    try { execFileSync('reg', ['delete', k, '/f'], { stdio: 'ignore' }); } catch (_) { /* 本来就没有 */ }
  }
}

async function main() {
  // ---- 准备「网站」和「镜像」
  fs.rmSync(SERVE, { recursive: true, force: true });
  fs.mkdirSync(path.join(SERVE, 'jev', 'windows'), { recursive: true });
  fs.mkdirSync(path.join(SERVE, 'files'), { recursive: true });
  for (const f of fs.readdirSync(path.join(ROOT, 'jev', 'windows'))) fs.copyFileSync(path.join(ROOT, 'jev', 'windows', f), path.join(SERVE, 'jev', 'windows', f));
  fs.copyFileSync(path.join(TC, 'llama-win-cpu-x64.zip'), path.join(SERVE, 'files', 'llama.zip'));
  fs.linkSync(MODEL_SRC, path.join(SERVE, 'files', 'model.gguf'));
  // 安装器单独放一个空目录：必须从「网站」下载 agent.ps1 等组件
  fs.rmSync(ISO, { recursive: true, force: true });
  fs.mkdirSync(ISO);
  fs.copyFileSync(path.join(ROOT, 'jev', 'windows', 'install.ps1'), path.join(ISO, 'install.ps1'));
  // 一个装过旧版的目录：旧托盘脚本 + 下了一半的模型（python http.server 不支持续传，走从头下载的分支）
  fs.rmSync(INST, { recursive: true, force: true });
  fs.mkdirSync(path.join(INST, 'jev'), { recursive: true });
  fs.writeFileSync(path.join(INST, 'jev_tray.ps1'), '# old tray');
  fs.writeFileSync(path.join(INST, 'start_jev_hidden.vbs'), "' old");
  const fd = fs.openSync(path.join(INST, 'jev', MODEL_NAME + '.part'), 'w');
  fs.writeSync(fd, Buffer.alloc(50 * 1024 * 1024, 7));
  fs.closeSync(fd);
  cleanupRegistry();

  const server = spawn('python', ['-m', 'http.server', String(PORT), '--bind', '127.0.0.1', '--directory', SERVE], { stdio: 'ignore' });
  await sleep(1500);
  try {
    console.log('\n[1] 全新安装（旧版残留 + 半截模型 + 第一条镜像是坏的）');
    let t = Date.now();
    let r = await install();
    const ok1 = r.code === 0;
    check(ok1, `安装器成功退出（${((Date.now() - t) / 1000).toFixed(0)} 秒）`);
    if (!ok1) console.log(r.out.slice(-3000));
    check(/线路 1\/2/.test(r.out) && /换下一条/.test(r.out), '第一条镜像失败后自动换线路');
    check(/判分服务已就绪/.test(r.out), '安装结束时服务已启动就绪');
    for (const f of ['agent.ps1', 'launch.js', 'uninstall.ps1', 'config.json', 'jev/llama/llama-server.exe', 'jev/llama/VERSION', `jev/${MODEL_NAME}`]) {
      check(fs.existsSync(path.join(INST, f)), `已安装 ${f}`);
    }
    check(!fs.existsSync(path.join(INST, 'jev', MODEL_NAME + '.part')), '临时 .part 文件已清理');
    check(!fs.existsSync(path.join(INST, 'jev_tray.ps1')) && !fs.existsSync(path.join(INST, 'start_jev_hidden.vbs')), '旧版托盘脚本已清理');
    const cfg = JSON.parse(fs.readFileSync(path.join(INST, 'config.json'), 'utf8'));
    check(cfg.allowedOrigins.includes(ORIGIN) && cfg.allowedOrigins.includes('https://genuineedu.pages.dev'), 'config.json 白名单含安装来源网站');
    check(reg('HKCU\\Software\\Classes\\jevtest\\shell\\open\\command').includes('launch.js'), '协议已注册到 launch.js');
    check(/JEV 本地判分服务|DisplayName/.test(reg('HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\GenuineEduJEV-jevtest', 'DisplayName')), '「设置 → 应用」里有卸载入口');
    const st = await agentStatus();
    check(st && st.state === 'ready', '管家在 8002 报告 ready');

    console.log('\n[2] 通过系统协议唤起（和浏览器点 jev:// 走同一条路）');
    await stopAgent();
    check(!(await agentStatus()), '先停掉服务');
    execFileSync('cmd.exe', ['/c', 'start', '', 'jevtest://start/'], { stdio: 'ignore' });
    const woke = await waitFor(async () => { const s = await agentStatus(); return s && s.state === 'ready' ? s : null; }, 60000);
    check(!!woke, 'jevtest://start 唤起服务并就绪（无窗口）');
    await stopAgent();

    console.log('\n[3] 重复安装：全部跳过下载');
    t = Date.now();
    r = await install('-NoStart');
    check(r.code === 0 && (r.out.match(/已存在且完整，跳过下载|已是最新，跳过/g) || []).length >= 2, `第二次安装跳过下载（${((Date.now() - t) / 1000).toFixed(0)} 秒）`);
    check(!/下载中（线路/.test(r.out), '没有发生任何下载');

    console.log('\n[4] 模型被损坏（大小不变）→ 校验发现并重下');
    const mp = path.join(INST, 'jev', MODEL_NAME);
    const h = fs.openSync(mp, 'r+');
    fs.writeSync(h, Buffer.from([0x42]), 0, 1, 123456789);
    fs.closeSync(h);
    r = await install('-NoStart');
    check(r.code === 0 && /已有文件损坏，重新下载/.test(r.out), '发现损坏并重新下载');

    console.log('\n[5] 所有下载线路都失败 → 清楚的报错');
    fs.unlinkSync(mp);
    r = await ps(`& ${q(path.join(ISO, 'install.ps1'))} -Origin ${q(ORIGIN)} -InstallDir ${q(INST)} -Scheme jevtest -NoStart -ModelUrls ${q(ORIGIN + '/nope/a')},${q(ORIGIN + '/nope/b')}; exit $LASTEXITCODE`);
    check(r.code === 1 && /模型 下载失败/.test(r.out) && /重新运行安装器即可继续/.test(r.out), '退出码 1 + 中文提示可重试');
    r = await install('-NoStart');
    check(r.code === 0, '网络恢复后重跑即可');

    console.log('\n[6] 卸载');
    fs.writeFileSync(path.join(INST, 'my-notes.txt'), '用户自己的文件');
    r = await ps(`& ${q(path.join(INST, 'uninstall.ps1'))}`);
    check(!fs.existsSync(path.join(INST, 'jev')) && !fs.existsSync(path.join(INST, 'agent.ps1')), '安装的文件已删除');
    check(fs.existsSync(path.join(INST, 'my-notes.txt')), '目录里用户自己的文件原样保留');
    check(!reg('HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\GenuineEduJEV-jevtest', 'DisplayName'), '卸载入口已移除');
    check(!reg('HKCU\\Software\\Classes\\jevtest\\shell\\open\\command'), '协议注册已移除');
  } finally {
    await stopAgent().catch(() => {});
    server.kill();
    cleanupRegistry();
  }
  console.log(`\n结果：${passed} 通过，${failed} 失败`);
  process.exit(failed ? 1 : 0);
}
main().catch(e => { console.error(e); cleanupRegistry(); process.exit(1); });
