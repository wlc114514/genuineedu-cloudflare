// 本地判分服务客户端：只和本机的 JEV 管家（agent）打交道。
// 管家负责拉起/停止 llama-server，并把它的地址和一次性密钥告诉网页。
// 依赖全部注入（fetch / storage / launch / 定时器），方便在 node 里无头测试。
(function (root, factory) {
  const api = factory(typeof module === 'object' && module.exports ? require('./core.js') : root.Core);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.Jev = api;
})(typeof self !== 'undefined' ? self : this, function (Core) {
  'use strict';

  const AGENT_PORTS = [8002, 18002, 28002];
  const MIN_AGENT_VERSION = '2.0.0';
  const INSTALLED_KEY = 'jev.installed';

  function versionLess(a, b) {
    const pa = String(a || '0').split('.').map(Number), pb = String(b).split('.').map(Number);
    for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
      const x = pa[i] || 0, y = pb[i] || 0;
      if (x !== y) return x < y;
    }
    return false;
  }

  class JevClient {
    constructor(deps) {
      this.fetch = deps.fetch;
      this.storage = deps.storage;
      this.launch = deps.launch || (() => {});
      this.beacon = deps.beacon || (() => {});
      this.sleep = deps.sleep || (ms => new Promise(r => setTimeout(r, ms)));
      this.now = deps.now || (() => Date.now());
      this.ports = deps.ports || AGENT_PORTS;
      this.clientId = deps.clientId || Math.random().toString(36).slice(2, 10);
      this.state = 'unknown';          // unknown | checking | offline | starting | ready | error
      this.info = null;                // 管家返回的 /status
      this.port = null;
      this.launchFailed = false;
      this.cache = new Map();
      this.selfTest = null;            // Promise<boolean>：当前密钥对应的模型自检
      this.checkedKey = null;
      this.badKey = null;
      this.listeners = new Set();
      this._probing = null;
      this._starting = null;
    }

    get installed() {
      try { return this.storage.getItem(INSTALLED_KEY) === '1'; } catch (_) { return false; }
    }
    set installed(v) {
      try { v ? this.storage.setItem(INSTALLED_KEY, '1') : this.storage.removeItem(INSTALLED_KEY); } catch (_) { /* 隐私模式 */ }
    }
    get outdated() { return !!(this.info && versionLess(this.info.version, MIN_AGENT_VERSION)); }

    on(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }
    _set(state) {
      if (this.state === state) return;
      this.state = state;
      for (const fn of this.listeners) { try { fn(state, this); } catch (_) { /* 监听者自己的错 */ } }
    }

    async _request(url, init = {}, timeout = 1500) {
      const ctl = typeof AbortController !== 'undefined' ? new AbortController() : null;
      const t = ctl ? setTimeout(() => ctl.abort(), timeout) : null;
      try {
        return await this.fetch(url, { cache: 'no-store', ...init, signal: ctl ? ctl.signal : undefined });
      } finally { if (t) clearTimeout(t); }
    }

    async _ping(port) {
      const r = await this._request(`http://127.0.0.1:${port}/ping?c=${encodeURIComponent(this.clientId)}`);
      if (!r.ok) return null;
      const st = await r.json();
      return st && st.app === 'jev-agent' ? st : null;
    }

    // 找管家：上次的端口优先；找到就当作「已安装」记下来
    probe() {
      if (this._probing) return this._probing;
      this._probing = (async () => {
        if (this.state === 'unknown') this._set('checking');
        const order = this.port ? [this.port, ...this.ports.filter(p => p !== this.port)] : this.ports;
        for (const port of order) {
          let st = null;
          try { st = await this._ping(port); } catch (_) { st = null; }
          if (st) { this._apply(st, port); return true; }
        }
        this.port = null;
        this.info = null;
        if (this.state !== 'starting') this._set('offline');
        return false;
      })().finally(() => { this._probing = null; });
      return this._probing;
    }

    _apply(st, port) {
      const keyChanged = this.info && this.info.key !== st.key;
      this.port = port;
      this.info = st;
      this.installed = true;
      this.launchFailed = false;
      if (keyChanged) this.cache.clear();
      if (st.state === 'ready' && this.badKey === st.key) {
        this.info = Object.assign({}, st, { state: 'error', error: 'self_test_failed' });
        this._set('error');
        return;
      }
      this._set(st.state === 'ready' ? 'ready' : st.state === 'error' ? 'error' : 'starting');
      if (st.state === 'ready' && this.checkedKey !== st.key) this._selfTest(st.key);
    }

    // 每次服务（重新）启动后先用两组已知答案自检：近义的必须判接近、无关的必须判不接近。
    // 不对（比如 Apple 芯片上 Metal 算错）就不用模型，退回文字匹配，绝不静默误判。
    _selfTest(key) {
      this.checkedKey = key;
      this.selfTest = (async () => {
        let ok;
        try {
          const same = await this._judgeOnce('尴尬的', '令人难堪的');
          const diff = await this._judgeOnce('工资', '火焰');
          ok = same !== null && diff !== null && same >= Core.JEV.THRESHOLD && diff < 0.5;
        } catch (_) {
          this.checkedKey = null;     // 网络抖动：这次不下结论，下次心跳再测
          return false;
        }
        if (!ok && this.info && this.info.key === key) {
          this.badKey = key;
          this.info = Object.assign({}, this.info, { state: 'error', error: 'self_test_failed' });
          this._set('error');
        }
        return ok;
      })();
      return this.selfTest;
    }

    // 拉起服务。必须在用户点击里调用（浏览器只允许用户手势唤起 jev://）
    start(timeout = 45000) {
      if (this.state === 'ready') return Promise.resolve(true);
      if (this._starting) return this._starting;
      this._starting = (async () => {
        const found = await this.probe();
        if (!found) {
          this.launch('jev://start');
          this._set('starting');
        }
        const ok = await this.waitReady(timeout);
        if (!ok && !this.port) { this.launchFailed = true; this._set('offline'); }
        return ok;
      })().finally(() => { this._starting = null; });
      return this._starting;
    }

    async waitReady(timeout) {
      const end = this.now() + timeout;
      while (this.now() < end) {
        if (this.state === 'ready') return true;
        if (this.state === 'error') return false;
        await this.sleep(1000);
        await this.probe();
      }
      return this.state === 'ready';
    }

    async stop() {
      if (this.port) {
        try { await this._request(`http://127.0.0.1:${this.port}/stop?c=${encodeURIComponent(this.clientId)}`, {}, 3000); } catch (_) { /* 已经没了 */ }
      }
      this.port = null;
      this.info = null;
      this._set('offline');
    }

    heartbeat() {
      // 只在本页确实连过管家后才心跳，避免给没装的人反复触发浏览器的本地网络权限询问
      if (this.port || this.state === 'starting') return this.probe();
      return Promise.resolve(false);
    }

    bye() {
      if (this.port) this.beacon(`http://127.0.0.1:${this.port}/bye?c=${encodeURIComponent(this.clientId)}`);
    }

    async _completion(prompt) {
      const { url, key } = this.info.llama;
      const r = await this._request(url + '/completion', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Api-Key': key },
        body: JSON.stringify({ prompt, n_predict: 1, temperature: 0, n_probs: 32, cache_prompt: false }),
      }, 20000);
      if (r.status === 401) throw Object.assign(new Error('key'), { retry: true });
      if (!r.ok) throw Object.assign(new Error('http ' + r.status), { retry: r.status === 503 });
      return r.json();
    }

    async _judgeOnce(meaning, answer) {
      const ds = [];
      for (const k of [0, 1]) {
        const d = Core.jevMargin(await this._completion(Core.jevPrompt(meaning, answer, k)));
        if (d === null) return null;
        ds.push(d);
      }
      return Core.jevProbability(ds[0], ds[1]);
    }

    // 自检通过才用模型。自检没跑完是因为网络/服务重启（不是模型坏了）时，重新问一次管家再测
    async _verified() {
      for (let i = 0; i < 2; i++) {
        if (!this.selfTest || (await this.selfTest)) return this.state === 'ready';
        if (this.state === 'error') return false;
        await this.probe();
        if (this.state !== 'ready') return false;
      }
      return false;
    }

    // 「意思是否接近」的置信度 0~1；服务不可用时返回 null（调用方退回文字匹配）
    async judge(meaning, answer) {
      if (!Core.hasContent(answer)) return 0;
      const key = meaning + '\u0000' + answer;
      if (this.cache.has(key)) return this.cache.get(key);
      if (this.state === 'starting') await this.waitReady(10000);
      if (this.state !== 'ready' || !this.info || !this.info.llama) return null;
      if (!(await this._verified())) return null;
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          const p = await this._judgeOnce(meaning, answer);
          if (p !== null) this.cache.set(key, p);
          return p;
        } catch (e) {
          // 密钥轮换 / 服务重启 / 刚睡醒：重新问一次管家再试
          if (attempt === 0) { await this.probe(); if (this.state !== 'ready') return null; continue; }
          return null;
        }
      }
      return null;
    }
  }

  return { JevClient, AGENT_PORTS, MIN_AGENT_VERSION, versionLess };
});
