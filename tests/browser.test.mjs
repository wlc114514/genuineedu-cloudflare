// 真浏览器端到端（无头 Chrome）：用户流程 + 与真实本地服务联动。
// 用法：node tests/browser.test.mjs [安装目录]   给了安装目录就顺带测智能判分（会占用 8001/8002）
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SHOTS = path.join(ROOT, '.testcache', 'shots');
const PORT = 38090;
const URL0 = `http://localhost:${PORT}/`;
const INST = process.argv[2] ? path.resolve(process.argv[2]) : null;
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const sleep = ms => new Promise(r => setTimeout(r, ms));
let passed = 0, failed = 0;
const check = (c, m) => { c ? passed++ : failed++; console.log(`  ${c ? '✓' : '✗'} ${m}`); };
fs.mkdirSync(SHOTS, { recursive: true });

const WORDS = [
  'mark\tv&n.\t标志、标记\tn.\t目标',
  'unify v. 统一',
  'plus conj. 加 adv. 此外',
  'bill n. 票据 n. 议案',
  'auditorium n. 礼堂',
].join('\n');

async function agentStatus() {
  for (const p of [8002, 18002, 28002]) {
    try { const j = await (await fetch(`http://127.0.0.1:${p}/status`, { signal: AbortSignal.timeout(1500) })).json(); if (j.app === 'jev-agent') return j; } catch (_) { /* next */ }
  }
  return null;
}
async function waitFor(fn, ms, step = 300) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(step); }
  return null;
}

async function main() {
  const server = spawn('python', ['-m', 'http.server', String(PORT), '--bind', '127.0.0.1', '--directory', ROOT], { stdio: 'ignore' });
  await sleep(1200);
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--no-first-run', '--lang=zh-CN'] });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 860 });
    const errors = [];
    const localCalls = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error' && !/127\.0\.0\.1:(8002|18002|28002)|ERR_CONNECTION_REFUSED/.test(m.text())) errors.push(m.text()); });
    page.on('request', r => { if (/127\.0\.0\.1:\d+/.test(r.url())) localCalls.push(r.url()); });
    page.on('dialog', d => d.accept());

    console.log('\n[1] 第一次打开');
    await page.goto(URL0, { waitUntil: 'networkidle0' });
    await page.evaluate(() => localStorage.clear());
    await page.reload({ waitUntil: 'networkidle0' });
    check(await page.$eval('#view-library', el => !el.hidden), '没有词库时默认进入「词库」页');
    check((await page.$eval('#jev-chip-state', el => el.textContent)) === '未开启', '右上角显示「智能判分 未开启」');
    await sleep(1500);
    check(localCalls.length === 0, '没装过的访客不会去探测本机端口（不触发浏览器的本地网络权限询问）');
    await page.screenshot({ path: path.join(SHOTS, '1-empty.png') });

    console.log('\n[2] 导入词库（含恶意词库名）');
    await page.type('#lib-name', '<img src=x onerror="window.__xss=1">');
    await page.$eval('#lib-text', (el, v) => { el.value = v; el.dispatchEvent(new Event('input')); }, WORDS + '\n中文行\n');
    await sleep(300);
    const status = await page.$eval('#parse-status', el => el.textContent);
    check(/已识别 5 个单词/.test(status) && /1 行没看懂/.test(status), '实时显示解析结果：' + status.replace(/\s+/g, ' ').slice(0, 40));
    await page.click('#lib-save');
    await sleep(300);
    const libName = await page.$eval('.lib-name', el => el.textContent);
    check(libName.includes('<img'), '词库名按原文显示');
    check(await page.evaluate(() => window.__xss === undefined && !document.querySelector('.lib-list img')), '没有执行注入的脚本（XSS 已转义）');
    await page.screenshot({ path: path.join(SHOTS, '2-library.png'), fullPage: true });

    console.log('\n[3] 完整做一次测试（键盘操作）');
    await page.click('[data-action="test-lib"]');
    await page.waitForSelector('#view-test:not([hidden])');
    await page.type('#t-student', '汪同学');
    await page.click('#t-all');
    await page.$eval('input[name="t-display"][value="random"]', el => el.click());
    await page.screenshot({ path: path.join(SHOTS, '3-setup.png') });
    await page.click('#t-start');
    const lib = await page.evaluate(() => Object.values(JSON.parse(localStorage.libraries))[0].words);
    let wrongDone = false;
    for (let i = 0; i < 5; i++) {
      await page.waitForSelector('#a-spell');
      const shown = await page.$$eval('.prompt-sense', els => els.map(e => e.textContent.replace(/^\S+\.\s*/, '').trim()));
      const w = lib.find(x => x.senses.some(s => shown.includes(s.meanings)));
      const shownIdx = w.senses.findIndex(s => shown.includes(s.meanings));
      const ask = w.senses.filter((_, j) => j !== shownIdx);
      const hint = await page.$eval('.hint-letters', el => el.textContent);
      if (i === 0) check(hint.replace(/_/g, '') === w.word.slice(0, Math.floor(w.word.length / 2)), `拼写提示露出前一半：${hint}`);
      const wrong = !wrongDone && ask.length > 0;
      await page.type('#a-spell', wrong ? w.word : w.word.toUpperCase());
      await page.keyboard.press('Enter');
      if (ask.length) {
        const meaningInput = await page.$('#a-mean');
        check(!!meaningInput, `「${w.word}」题面给一个词性，要写其余 ${ask.length} 个`);
        await page.type('#a-mean', wrong ? ask.slice(1).map(s => s.meanings).join('，') || '瞎写' : ask.map(s => s.meanings).join('，'));
        await page.keyboard.press('Enter');
      }
      try { await page.waitForSelector('.verdict', { timeout: 10000 }); } catch (e) {
        console.log('    卡住时的页面：', (await page.$eval('#r-card', el => el.innerText)).replace(/\s+/g, ' ').slice(0, 300), '| 焦点：', await page.evaluate(() => document.activeElement.id), '| 错误：', errors);
        throw e;
      }
      const verdict = await page.$eval('.verdict', el => el.textContent);
      check(wrong ? /错误/.test(verdict) : /正确/.test(verdict), `第 ${i + 1} 题「${w.word}」${wrong ? '少写一个释义 → 错误' : '→ 正确'}`);
      if (wrong) { wrongDone = true; await page.screenshot({ path: path.join(SHOTS, '4-feedback-wrong.png') }); }
      if (i === 0) { await page.keyboard.press('Enter'); check(!!(await page.$('.verdict')), '刚提交时多按的 Enter 不会跳过反馈'); }
      await sleep(450);
      await page.keyboard.press('Enter');
    }
    await page.waitForSelector('#view-records:not([hidden])');
    const score = await page.$eval('.record .score', el => el.textContent);
    check(score.startsWith('80'), `交卷后跳到记录页：正确率 ${score}`);
    check((await page.$$eval('.record tbody tr', r => r.length)) === 1, '错词表里有 1 个词');
    await page.screenshot({ path: path.join(SHOTS, '5-records.png'), fullPage: true });

    console.log('\n[4] 只考拼写 + 限时');
    await page.click('.tabs [data-view="test"]');
    await page.$eval('input[name="t-display"][value="all"]', el => el.click());
    await page.$eval('input[name="t-timeout"][value="5"]', el => el.click());
    await page.$eval('#t-all', el => { if (el.checked) el.click(); });
    await page.$eval('#t-count', el => { el.value = '1'; });
    await page.click('#t-start');
    await page.waitForSelector('#a-spell');
    check(!(await page.$('#a-mean')), '只考拼写时没有释义输入框');
    await page.waitForSelector('.verdict', { timeout: 9000 });
    check(/超时自动提交/.test(await page.$eval('#r-card', el => el.textContent)), '5 秒到点自动提交');
    await sleep(450);
    await page.keyboard.press('Enter');
    await page.waitForSelector('#view-records:not([hidden])');

    console.log('\n[5] 旧版本数据兼容');
    await page.evaluate(() => {
      localStorage.setItem('libraries', JSON.stringify({ 旧词库: { name: '旧词库', count: 2, createdAt: '2026-08-29T00:00:00Z', words: [
        { word: 'renew', senses: [{ pos: '', meanings: '' }, { pos: 'v', meanings: '更新' }] }, { word: 'serve', senses: [{ pos: 'v', meanings: '服务' }] }] } }));
      localStorage.setItem('testRecords', JSON.stringify([{ id: 1, libName: '旧词库', student: 'Adam', total: 2, correct: 1, accuracy: '50.0', duration: 75,
        wrongWords: [{ word: 'serve', senses: [{ pos: 'v', meanings: '服务' }], spelling: 'srve', meanings: '' }], timestamp: '2026-08-29T00:00:00Z' }, null, 'junk']));
    });
    await page.reload({ waitUntil: 'networkidle0' });
    await page.click('.tabs [data-view="library"]');
    check((await page.$eval('.lib-meta', el => el.textContent)).startsWith('2 词'), '旧词库正常显示，空释义占位被清掉');
    await page.click('.tabs [data-view="records"]');
    check((await page.$$('.record')).length === 1, '旧成绩记录正常显示，坏条目被忽略');

    console.log('\n[6] 手机宽度 / 浅色模式');
    await page.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true });
    await page.click('.tabs [data-view="test"]');
    await page.screenshot({ path: path.join(SHOTS, '6-mobile.png'), fullPage: true });
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
    check(!overflow, '手机宽度没有横向滚动条');
    await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: 'light' }]);
    await page.setViewport({ width: 1280, height: 860 });
    await page.click('#jev-chip');
    await sleep(300);
    await page.screenshot({ path: path.join(SHOTS, '7-light-jev-dialog.png') });
    check(/下载安装器|粘贴这一行/.test(await page.$eval('#jev-body', el => el.textContent)), '智能判分面板给出一键安装步骤');
    await page.keyboard.press('Escape');
    await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: 'dark' }]);

    if (INST) {
      console.log('\n[7] 和真实本地服务联动');
      fs.writeFileSync(path.join(INST, 'config.json'), JSON.stringify({ byeGrace: 3, heartbeatTimeout: 30 }));
      spawn('wscript.exe', ['//B', '//Nologo', '//E:jscript', path.join(INST, 'launch.js'), 'start'], { stdio: 'ignore' });
      check(!!(await waitFor(async () => (await agentStatus())?.state === 'ready', 60000)), '服务已启动（模拟浏览器唤起后的状态）');
      const p2 = await browser.newPage();
      await p2.setViewport({ width: 1280, height: 860 });
      p2.on('pageerror', e => errors.push(e.message));
      p2.on('dialog', d => d.accept());
      await p2.goto(URL0, { waitUntil: 'networkidle0' });
      await p2.evaluate(() => {
        localStorage.setItem('jev.installed', '1');
        localStorage.setItem('libraries', JSON.stringify({ 近义: { name: '近义', count: 1, createdAt: '2026-10-16T00:00:00Z', words: [
          { word: 'unify', senses: [{ pos: 'v', meanings: '统一' }, { pos: 'adj', meanings: '尴尬的' }] }] } }));
      });
      await p2.reload({ waitUntil: 'networkidle0' });
      const chip = await waitFor(async () => { const t = await p2.$eval('#jev-chip-state', el => el.textContent); return t === '已开启' ? t : null; }, 15000);
      check(!!chip, '装过的用户打开网页：自动连上，显示「已开启」');
      await p2.click('.tabs [data-view="test"]');
      await p2.$eval('#t-student', el => { el.value = 'Adam'; });
      await p2.$eval('input[name="t-display"][value="random"]', el => el.click());
      await p2.$eval('#t-all', el => { if (!el.checked) el.click(); });
      await p2.click('#t-start');
      await p2.waitForSelector('#a-mean');
      const shown = await p2.$eval('.prompt-sense', el => el.textContent);
      await p2.type('#a-spell', 'unify');
      await p2.type('#a-mean', shown.includes('统一') ? '令人难堪的' : '使一致');
      await p2.keyboard.press('Enter');
      await p2.waitForSelector('.verdict', { timeout: 30000 });
      const card = await p2.$eval('#r-card', el => el.textContent);
      check(/正确/.test(card) && /智能判分/.test(card), '近义写法被智能判分判对：' + (card.match(/智能判分：[^，]+/) || [''])[0]);
      await p2.screenshot({ path: path.join(SHOTS, '8-jev-correct.png') });
      await sleep(450);
      await p2.keyboard.press('Enter');
      await p2.close({ runBeforeUnload: false });
      check(!!(await waitFor(async () => !(await agentStatus()), 20000, 500)), '关掉网页后服务自动停止');
    }

    check(errors.length === 0, '页面没有任何 JS 报错' + (errors.length ? '：' + errors.join(' | ') : ''));
  } finally {
    await browser.close();
    server.kill();
  }
  console.log(`\n结果：${passed} 通过，${failed} 失败；截图在 ${SHOTS}`);
  process.exit(failed ? 1 : 0);
}
main().catch(e => { console.error(e); process.exit(1); });
