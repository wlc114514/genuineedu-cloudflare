// 网页端服务客户端的状态机：用假的管家 / llama-server 跑，不需要网络
const test = require('node:test');
const assert = require('node:assert/strict');
const { JevClient, versionLess } = require('../js/jev.js');

function memStorage() {
  const m = new Map();
  return { getItem: k => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: k => m.delete(k) };
}

// 假环境：agentPort 上有没有管家、管家状态、llama 回答
function fakeWorld() {
  const w = {
    agentPort: null, state: 'ready', key: 'k1', version: '2.0.0', error: '',
    launches: [], beacons: [], calls: [], llamaStatus: 200, p: { yes: -0.1, no: -3 },
    onLaunch: null,
  };
  w.fetch = async (url, init = {}) => {
    w.calls.push(url);
    const u = new URL(url);
    const port = Number(u.port);
    if (u.pathname === '/ping' || u.pathname === '/status' || u.pathname === '/stop') {
      if (port !== w.agentPort) throw new TypeError('Failed to fetch');
      if (u.pathname === '/stop') { w.agentPort = null; return resp(200, { ok: true }); }
      const body = { app: 'jev-agent', version: w.version, state: w.state, error: w.error };
      if (w.state === 'ready') Object.assign(body, { key: w.key, llama: { url: 'http://127.0.0.1:8001', key: w.key } });
      return resp(200, body);
    }
    if (u.pathname === '/completion') {
      if (init.headers['X-Api-Key'] !== w.key) return resp(401, {});
      if (w.llamaStatus !== 200) return resp(w.llamaStatus, {});
      const k1 = JSON.parse(init.body).prompt.includes('不一致: 意思不同或无关 ->') && JSON.parse(init.body).prompt.split('->').length > 2;
      const yes = k1 ? w.p.no : w.p.yes, no = k1 ? w.p.yes : w.p.no;
      return resp(200, { completion_probabilities: [{ top_logprobs: [{ id: 9542, logprob: yes }, { id: 874, logprob: no }] }] });
    }
    throw new TypeError('Failed to fetch');
  };
  return w;
}
function resp(status, body) { return { ok: status >= 200 && status < 300, status, json: async () => body }; }

function client(w, storage = memStorage()) {
  let now = 0;
  return new JevClient({
    fetch: w.fetch, storage, clientId: 'tab1',
    launch: url => { w.launches.push(url); if (w.onLaunch) w.onLaunch(); },
    beacon: url => w.beacons.push(url),
    now: () => now,
    sleep: async ms => { now += ms; },
  });
}

test('没装过：不主动探测，状态为 unknown；探测后为 offline', async () => {
  const w = fakeWorld();
  const c = client(w);
  assert.equal(c.installed, false);
  assert.equal(c.state, 'unknown');
  assert.equal(await c.heartbeat(), false);
  assert.equal(w.calls.length, 0, '没连过就不发心跳（避免没装的人被浏览器问本地网络权限）');
  assert.equal(await c.probe(), false);
  assert.equal(c.state, 'offline');
});

test('找到管家：记住已安装、拿到地址密钥；备用端口也能找到', async () => {
  const w = fakeWorld();
  w.agentPort = 18002;
  const storage = memStorage();
  const c = client(w, storage);
  assert.equal(await c.probe(), true);
  assert.equal(c.state, 'ready');
  assert.equal(c.port, 18002);
  assert.equal(storage.getItem('jev.installed'), '1');
  assert.ok(w.calls.some(u => u.includes('/ping?c=tab1')), 'ping 带上标签页 id');
});

test('已安装但没运行：start() 唤起 jev:// 并等到就绪', async () => {
  const w = fakeWorld();
  const storage = memStorage();
  storage.setItem('jev.installed', '1');
  const c = client(w, storage);
  let polls = 0;
  w.onLaunch = () => { w.agentPort = 8002; w.state = 'starting'; };
  const origFetch = w.fetch;
  w.fetch = async (url, init) => { if (url.includes('/ping') && w.state === 'starting' && ++polls >= 3) w.state = 'ready'; return origFetch(url, init); };
  c.fetch = w.fetch;
  const states = [];
  c.on(s => states.push(s));
  assert.equal(await c.start(), true);
  assert.deepEqual(w.launches, ['jev://start']);
  assert.equal(c.state, 'ready');
  assert.ok(states.includes('starting'));
});

test('唤起失败（被浏览器拦截 / 已卸载）：超时后 offline + launchFailed', async () => {
  const w = fakeWorld();
  const c = client(w);
  assert.equal(await c.start(5000), false);
  assert.equal(c.state, 'offline');
  assert.equal(c.launchFailed, true);
});

test('并发 start 只唤起一次', async () => {
  const w = fakeWorld();
  w.onLaunch = () => { w.agentPort = 8002; };
  const c = client(w);
  const [a, b] = await Promise.all([c.start(), c.start()]);
  assert.ok(a && b);
  assert.equal(w.launches.length, 1);
});

test('管家报错：state=error，start 立即返回 false', async () => {
  const w = fakeWorld();
  w.agentPort = 8002; w.state = 'error'; w.error = 'model_missing';
  const c = client(w);
  assert.equal(await c.start(), false);
  assert.equal(c.state, 'error');
  assert.equal(c.info.error, 'model_missing');
});

test('判分：概率计算、缓存、空答案', async () => {
  const w = fakeWorld();
  w.agentPort = 8002;
  const c = client(w);
  await c.probe();
  const p = await c.judge('尴尬的', '令人难堪的');
  assert.ok(p > 0.9, 'p=' + p);
  const n = w.calls.length;
  assert.equal(await c.judge('尴尬的', '令人难堪的'), p);
  assert.equal(w.calls.length, n, '第二次走缓存');
  assert.equal(await c.judge('尴尬的', '  ，'), 0);
});

test('密钥轮换（服务重启过）：401 后重新问管家再试一次', async () => {
  const w = fakeWorld();
  w.agentPort = 8002;
  const c = client(w);
  await c.probe();
  w.key = 'k2';   // 服务重启，新密钥
  const p = await c.judge('统一', '使一致');
  assert.ok(p > 0.9);
  assert.equal(c.info.key, 'k2');
});

test('服务中途没了：judge 返回 null，不抛错', async () => {
  const w = fakeWorld();
  w.agentPort = 8002;
  const c = client(w);
  await c.probe();
  w.agentPort = null;
  w.llamaStatus = 500;
  assert.equal(await c.judge('统一', '使一致'), null);
  assert.equal(c.state, 'offline');
});

test('未就绪时 judge 返回 null（调用方退回文字匹配）', async () => {
  const c = client(fakeWorld());
  assert.equal(await c.judge('统一', '使一致'), null);
});

test('stop / bye', async () => {
  const w = fakeWorld();
  w.agentPort = 8002;
  const c = client(w);
  await c.probe();
  c.bye();
  assert.deepEqual(w.beacons, ['http://127.0.0.1:8002/bye?c=tab1']);
  await c.stop();
  assert.equal(c.state, 'offline');
  assert.equal(w.agentPort, null);
  c.bye();
  assert.equal(w.beacons.length, 1, '没连着就不发 bye');
});

test('版本比较', () => {
  assert.ok(versionLess('1.9.9', '2.0.0'));
  assert.ok(!versionLess('2.0.0', '2.0.0'));
  assert.ok(!versionLess('2.1', '2.0.0'));
  assert.ok(versionLess(undefined, '2.0.0'));
});
