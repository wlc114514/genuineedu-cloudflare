// 页面层：DOM、事件、localStorage。逻辑在 core.js，本地服务在 jev.js。
(function () {
  'use strict';
  const { escapeHtml: h } = Core;
  const $ = sel => document.querySelector(sel);
  const $$ = sel => Array.from(document.querySelectorAll(sel));

  // ======================================================== 存储
  const store = {
    get(key, fallback) { try { return Core.readJson(localStorage, key, fallback); } catch (_) { return fallback; } },
    set(key, value) {
      try { localStorage.setItem(key, JSON.stringify(value)); return true; } catch (e) {
        toast(e && e.name === 'QuotaExceededError' ? '浏览器存储空间满了：请导出备份后删掉一些旧记录' : '保存失败：浏览器禁止了本地存储');
        return false;
      }
    },
  };
  let libraries = Core.sanitizeLibraries(store.get('libraries', {}));
  let records = Core.sanitizeRecords(store.get('testRecords', []));
  const saveLibraries = () => store.set('libraries', libraries);
  const saveRecords = () => store.set('testRecords', records);
  const prefs = Object.assign({ student: '', lib: '', count: 20, all: false, display: 'random', hint: 'auto', criteria: 'any', match: 'loose', timeout: '0' }, store.get('prefs', {}));

  // ======================================================== 小工具
  let toastTimer = null;
  function toast(msg, ms = 2600) {
    const el = $('#toast');
    el.textContent = msg;
    el.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { el.hidden = true; }, ms);
  }
  function download(name, text, type = 'text/plain;charset=utf-8') {
    const url = URL.createObjectURL(new Blob([text], { type }));
    const a = document.createElement('a');
    a.href = url;
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 2000);
  }
  async function copyText(text, btn) {
    let ok = false;
    try { await navigator.clipboard.writeText(text); ok = true; } catch (_) {
      const ta = document.createElement('textarea');
      ta.value = text; document.body.appendChild(ta); ta.select();
      try { ok = document.execCommand('copy'); } catch (_) { ok = false; }
      ta.remove();
    }
    if (btn) { const old = btn.textContent; btn.textContent = ok ? '已复制 ✓' : '请手动复制'; setTimeout(() => { btn.textContent = old; }, 1800); }
    return ok;
  }
  const fmtDate = iso => { const d = new Date(iso); return isNaN(d) ? '' : d.toLocaleString('zh-CN', { hour12: false }); };
  const senseHtml = s => (s.pos ? `<span class="pos">${h(s.pos)}.</span>` : '') + h(s.meanings);
  const stamp = () => new Date().toISOString().slice(0, 10);

  // ======================================================== 视图切换
  function showView(name) {
    if (!['library', 'test', 'records'].includes(name)) name = 'library';
    for (const b of $$('.tabs button')) {
      if (b.dataset.view === name) b.setAttribute('aria-current', 'page'); else b.removeAttribute('aria-current');
    }
    for (const p of $$('[data-view-panel]')) p.hidden = p.dataset.viewPanel !== name;
    if (location.hash !== '#' + name) history.replaceState(null, '', '#' + name);
    if (name === 'test') renderSetup();
    if (name === 'records') renderRecords();
  }
  document.addEventListener('click', e => {
    const tab = e.target.closest('[data-view]');
    if (tab && tab.closest('.tabs')) { if (test && !confirmLeaveTest()) return; showView(tab.dataset.view); }
    const link = e.target.closest('[data-view-link]');
    if (link) { e.preventDefault(); if (test && !confirmLeaveTest()) return; showView(link.dataset.viewLink); }
  });
  window.addEventListener('hashchange', () => { if (!test) showView(location.hash.slice(1)); });

  // ======================================================== 词库
  let parsed = { words: [], errors: [] };
  let parseTimer = null;
  function updateParse() {
    parsed = Core.parseWordList($('#lib-text').value);
    const el = $('#parse-status');
    const n = parsed.words.length, bad = parsed.errors.length;
    if (!$('#lib-text').value.trim()) el.innerHTML = '';
    else {
      el.innerHTML = (n ? `<span class="ok">已识别 ${n} 个单词</span>` : '<span class="warn">还没识别出单词</span>')
        + (bad ? `<span class="warn">，${bad} 行没看懂</span><details><summary>查看</summary><ol>${parsed.errors.slice(0, 30).map(e => `<li value="${e.line}">${h(e.text)} <span class="muted">— ${h(e.reason)}</span></li>`).join('')}</ol></details>` : '');
    }
    $('#lib-save').disabled = !n;
  }
  $('#lib-text').addEventListener('input', () => { clearTimeout(parseTimer); parseTimer = setTimeout(updateParse, 150); });

  $('#lib-save').addEventListener('click', () => {
    updateParse();
    let name = $('#lib-name').value.trim();
    if (!parsed.words.length) return;
    if (!name) name = `词库 ${stamp()}`;
    if (libraries[name] && !confirm(`已有同名词库「${name}」（${libraries[name].count} 词），要覆盖吗？`)) return;
    // 同一个词出现多次：合并释义
    const map = new Map();
    for (const w of parsed.words) {
      const k = w.word.toLowerCase();
      if (map.has(k)) map.get(k).senses.push(...w.senses);
      else map.set(k, { word: w.word, senses: w.senses.slice() });
    }
    const words = [...map.values()];
    libraries[name] = { name, words, createdAt: new Date().toISOString(), count: words.length };
    if (!saveLibraries()) { delete libraries[name]; return; }
    $('#lib-name').value = '';
    $('#lib-text').value = '';
    updateParse();
    prefs.lib = name;
    renderLibraries();
    showPreview(name);
    toast(`已保存「${name}」，共 ${words.length} 个单词`);
  });

  function renderLibraries() {
    const libs = Object.values(libraries).sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
    $('#lib-list').innerHTML = libs.length ? libs.map(l => `
      <li>
        <div class="lib-info">
          <div class="lib-name">${h(l.name)}</div>
          <div class="lib-meta">${l.count} 词 · ${h(fmtDate(l.createdAt))}</div>
        </div>
        <button type="button" class="btn small primary" data-action="test-lib" data-name="${h(l.name)}">测试</button>
        <button type="button" class="btn small ghost" data-action="preview-lib" data-name="${h(l.name)}">查看</button>
        <button type="button" class="btn small ghost danger" data-action="delete-lib" data-name="${h(l.name)}">删除</button>
      </li>`).join('') : '<li class="empty">还没有词库。在左边粘贴单词表就能创建。</li>';
  }

  function showPreview(name) {
    const lib = libraries[name];
    const el = $('#lib-preview');
    if (!lib) { el.hidden = true; return; }
    el.hidden = false;
    el.innerHTML = `<div class="card-head"><h2>${h(lib.name)}</h2><button type="button" class="btn small ghost" data-action="close-preview">收起</button></div>
      <div class="word-grid">${lib.words.slice(0, 300).map(w => `<div><b>${h(w.word)}</b>${w.senses.map(s => `<div class="sense-line">${senseHtml(s)}</div>`).join('')}</div>`).join('')}</div>
      ${lib.words.length > 300 ? `<p class="muted small">…还有 ${lib.words.length - 300} 个</p>` : ''}`;
    el.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  function exportTxt() {
    const libs = Object.values(libraries);
    if (!libs.length) return toast('没有可导出的词库');
    // 导出格式就是导入格式，可以直接粘回来
    const text = libs.map(l => `# ${l.name}\n` + l.words.map(w => [w.word, ...w.senses.flatMap(s => [s.pos ? s.pos + '.' : '', s.meanings])].filter(Boolean).join('\t')).join('\n')).join('\n\n');
    download(`词库_${stamp()}.txt`, text);
  }
  function exportCsv() {
    const libs = Object.values(libraries);
    if (!libs.length) return toast('没有可导出的词库');
    const rows = [['词库', '单词', '词性', '释义']];
    for (const l of libs) for (const w of l.words) for (const s of w.senses) rows.push([l.name, w.word, s.pos, s.meanings]);
    download(`词库_${stamp()}.csv`, '﻿' + rows.map(r => r.map(Core.csvCell).join(',')).join('\r\n'), 'text/csv;charset=utf-8');
  }

  // ======================================================== 测试设置
  function renderSetup() {
    const names = Object.keys(libraries);
    const sel = $('#t-lib');
    sel.innerHTML = names.length ? names.map(n => `<option value="${h(n)}">${h(n)}（${libraries[n].count} 词）</option>`).join('') : '<option value="">还没有词库</option>';
    if (prefs.lib && libraries[prefs.lib]) sel.value = prefs.lib;
    $('#t-student').value = $('#t-student').value || prefs.student;
    $('#t-count').value = prefs.count;
    $('#t-all').checked = prefs.all;
    $('#t-count').disabled = prefs.all;
    for (const k of ['display', 'hint', 'criteria', 'match', 'timeout']) $('#t-' + k).value = prefs[k];
    syncSetup();
    $('#t-start').disabled = !names.length;
    renderJev();
  }
  function syncSetup() {
    const allShown = $('#t-display').value === 'all';
    $('#t-criteria').disabled = allShown;
    $('#t-match').disabled = allShown || $('#t-criteria').value === 'spelling';
  }
  $('#t-all').addEventListener('change', e => { $('#t-count').disabled = e.target.checked; });
  $('#t-display').addEventListener('change', syncSetup);
  $('#t-criteria').addEventListener('change', syncSetup);

  $('#test-setup').addEventListener('submit', e => {
    e.preventDefault();
    const lib = libraries[$('#t-lib').value];
    const student = $('#t-student').value.trim();
    if (!lib) return toast('先在「词库」里建一个词库');
    if (!student) { $('#t-student').focus(); return toast('请填写学生姓名'); }
    const config = {
      display: $('#t-display').value,
      hint: $('#t-hint').value,
      criteria: $('#t-display').value === 'all' ? 'spelling' : $('#t-criteria').value,
      match: $('#t-match').value,
      timeout: Core.clampInt($('#t-timeout').value, 0, 600, 0),
    };
    const count = Core.clampInt($('#t-count').value, 1, 1000, 20);
    Object.assign(prefs, { student, lib: lib.name, count, all: $('#t-all').checked, display: config.display, hint: config.hint, criteria: $('#t-criteria').value, match: config.match, timeout: String(config.timeout) });
    store.set('prefs', prefs);
    // 用户刚点了按钮：这是浏览器允许唤起 jev:// 的时机。已安装就顺手把服务叫起来，答到需要判释义时多半已经就绪。
    if (config.criteria === 'any' && jev.installed && jev.state !== 'ready') jev.start().then(renderJev);
    startTest(lib, student, config, count, $('#t-all').checked);
  });

  // ======================================================== 答题
  let test = null;
  let timer = null;
  function confirmLeaveTest() {
    if (!confirm('测试还没做完，要放弃吗？（不会保存成绩）')) return false;
    endTest(false);
    return true;
  }

  function startTest(lib, student, config, count, all) {
    const questions = Core.buildQuestions(lib.words, { all, count, display: config.display });
    test = { lib: lib.name, student, config, questions, idx: 0, answers: [], startedAt: Date.now(), phase: 'ask' };
    $('#test-setup').hidden = true;
    $('#runner').hidden = false;
    renderQuestion();
  }

  function stopTimer() { if (timer) { clearInterval(timer); timer = null; } $('#r-timer').hidden = true; }

  function renderQuestion() {
    const q = test.questions[test.idx];
    const { config } = test;
    test.phase = 'ask';
    const total = test.questions.length;
    $('#r-count').textContent = `${test.idx + 1} / ${total}`;
    $('#r-bar').style.width = (test.idx / total * 100) + '%';
    const needMeaning = config.criteria === 'any' && q.ask.length > 0;
    const hint = Core.generateHint(q.word, config.hint);
    $('#r-card').innerHTML = `
      <div class="prompt">${q.shown.map(s => `<div class="prompt-sense">${senseHtml(s)}</div>`).join('')}</div>
      <div class="hint-letters ${hint ? '' : 'blank'}">${hint ? h(hint) : '凭释义写出单词'}</div>
      <label class="field"><span>拼写</span>
        <input type="text" class="spell-input" id="a-spell" autocomplete="off" autocapitalize="off" autocorrect="off" spellcheck="false"></label>
      ${needMeaning ? `<label class="field"><span>写出其余词性的释义 <span class="ask-hint">（还有 ${q.ask.map(s => s.pos ? h(s.pos) + '.' : '1 个').join('、')}；多个用逗号或分号隔开）</span></span>
        <input type="text" id="a-mean" autocomplete="off"></label>` : ''}
      <div class="q-actions">
        <span class="kbd-hint"><kbd>Enter</kbd> ${needMeaning ? '下一格 / 提交' : '提交'}</span>
        <button type="button" class="btn primary" id="a-submit">提交</button>
      </div>`;
    const spell = $('#a-spell');
    spell.focus();
    spell.addEventListener('keydown', e => {
      if (e.key !== 'Enter' || e.isComposing) return;
      e.preventDefault();
      if (needMeaning && !$('#a-mean').value.trim()) $('#a-mean').focus(); else submit();
    });
    if (needMeaning) $('#a-mean').addEventListener('keydown', e => { if (e.key === 'Enter' && !e.isComposing) { e.preventDefault(); submit(); } });
    $('#a-submit').addEventListener('click', () => submit());
    stopTimer();
    if (config.timeout > 0) {
      let left = config.timeout;
      const el = $('#r-timer');
      el.hidden = false;
      const tick = () => { el.textContent = `${left}s`; el.classList.toggle('urgent', left <= 3); };
      tick();
      timer = setInterval(() => { left--; tick(); if (left <= 0) { stopTimer(); submit(true); } }, 1000);
    }
  }

  async function submit(timedOut = false) {
    if (!test || test.phase !== 'ask') return;
    test.phase = 'grading';
    stopTimer();
    const q = test.questions[test.idx];
    const input = { spelling: $('#a-spell').value, meanings: $('#a-mean') ? $('#a-mean').value : '' };
    for (const el of $$('#r-card input')) el.disabled = true;
    const btn = $('#a-submit');
    btn.disabled = true;
    // 服务在跑（或正在起来）才问模型；没装就纯文字匹配，不等待
    const useJev = jev.state === 'ready' || jev.state === 'starting';
    let slow = useJev ? setTimeout(() => { btn.innerHTML = '<span class="spinner"></span> 智能判分中…'; }, 250) : null;
    const res = await Core.gradeAnswer(q, input, test.config, useJev ? (m, a) => jev.judge(m, a) : null);
    clearTimeout(slow);
    if (!test) return;   // 判分期间被放弃
    test.answers.push({
      word: q.word, senses: q.senses, shown: q.shown, ask: q.ask,
      spelling: input.spelling.trim(), meanings: input.meanings.trim(),
      spellOk: res.spellOk, correct: res.correct, timedOut,
      senseResults: res.senses.map(s => ({ pos: s.sense.pos, meanings: s.sense.meanings, ok: s.ok, via: s.via, p: s.p })),
    });
    renderFeedback(q, input, res, timedOut);
  }

  function renderFeedback(q, input, res, timedOut) {
    test.phase = 'feedback';
    // 提交用的那次 Enter 还没松开，焦点就到了「下一题」按钮上，会被浏览器当成一次点击：留一点间隔
    test.feedbackAt = performance.now();
    const jevHit = res.senses.filter(s => s.via === 'jev');
    const missedMeaning = res.senses.some(s => !s.ok);
    $('#r-card').innerHTML = `
      <div class="verdict ${res.correct ? 'ok' : 'bad'}">${res.correct ? '✓ 正确' : '✗ 错误'}${timedOut ? '<span class="muted small">（超时自动提交）</span>' : ''}</div>
      <p class="answer-word">${h(q.word)}</p>
      <ul class="check-list">
        <li class="${res.spellOk ? 'ok' : 'bad'}"><span class="mark">${res.spellOk ? '✓' : '✗'}</span><span>拼写${res.spellOk ? '' : `：你写的是 <b>${h(input.spelling.trim() || '（空）')}</b>`}</span></li>
        ${q.shown.map(s => `<li class="info"><span class="mark"></span><span>${senseHtml(s)} <span class="muted small">（题面）</span></span></li>`).join('')}
        ${q.ask.map((s, i) => {
          const r = res.senses[i];
          if (!r) return `<li class="info"><span class="mark"></span><span>${senseHtml(s)}</span></li>`;
          return `<li class="${r.ok ? 'ok' : 'bad'}"><span class="mark">${r.ok ? '✓' : '✗'}</span><span>${senseHtml(s)}</span></li>`;
        }).join('')}
      </ul>
      ${res.senses.length ? `<p class="your">你写的释义：<b>${h(input.meanings.trim() || '（空）')}</b></p>` : ''}
      ${jevHit.map(s => `<p class="jev-note">智能判分：「${h(s.piece)}」和「${h(s.sense.meanings)}」意思接近（${(s.p * 100).toFixed(0)}%），算对。</p>`).join('')}
      <div class="q-actions">
        <span class="kbd-hint"><kbd>Enter</kbd> 下一题</span>
        <button type="button" class="btn primary" id="a-next">${test.idx + 1 >= test.questions.length ? '查看成绩' : '下一题'}</button>
      </div>
      ${missedMeaning && res.spellOk && !jev.installed && !nudged ? '<p class="nudge">意思写对了却被判错？<button type="button" class="link" data-action="open-jev">开启智能判分</button>，能识别近义的写法。</p>' : ''}`;
    if (missedMeaning && res.spellOk && !jev.installed) nudged = true;
    const next = $('#a-next');
    next.addEventListener('click', nextQuestion);
    next.focus();
  }
  let nudged = false;

  function nextQuestion() {
    if (!test || test.phase !== 'feedback' || performance.now() - test.feedbackAt < 400) return;
    test.idx++;
    if (test.idx >= test.questions.length) endTest(true); else renderQuestion();
  }
  document.addEventListener('keydown', e => {
    if (e.key === 'Enter' && test && test.phase === 'feedback' && !e.isComposing && !(e.target instanceof HTMLButtonElement)) { e.preventDefault(); nextQuestion(); }
  });
  $('#r-quit').addEventListener('click', () => {
    if (!test) return;
    if (test.answers.length && confirm(`已答 ${test.answers.length} 题，要保存这部分成绩吗？\n「确定」保存并结束，「取消」继续答题`)) return endTest(true);
    if (!test.answers.length && confirm('要放弃这次测试吗？')) endTest(false);
  });

  function endTest(save) {
    stopTimer();
    const t = test;
    test = null;
    $('#runner').hidden = true;
    $('#test-setup').hidden = false;
    if (!save || !t || !t.answers.length) return;
    const correct = t.answers.filter(a => a.correct).length;
    const record = {
      id: Date.now(),
      libName: t.lib,
      student: t.student,
      total: t.answers.length,
      planned: t.questions.length,
      correct,
      accuracy: (correct / t.answers.length * 100).toFixed(1),
      duration: Math.round((Date.now() - t.startedAt) / 1000),
      wrongWords: t.answers.filter(a => !a.correct),
      config: t.config,
      timestamp: new Date().toISOString(),
    };
    records.unshift(record);
    if (!saveRecords()) records.shift();
    showView('records');
  }

  // ======================================================== 记录
  function renderRecords() {
    const sel = $('#rec-student');
    const cur = sel.value;
    const students = [...new Set(records.map(r => r.student).filter(Boolean))];
    sel.innerHTML = '<option value="">全部</option>' + students.map(s => `<option value="${h(s)}">${h(s)}</option>`).join('');
    if (students.includes(cur)) sel.value = cur;
    const list = records.filter(r => !sel.value || r.student === sel.value);
    $('#rec-list').innerHTML = list.length ? list.map((r, i) => `
      <article class="record">
        <div class="record-top">
          <div class="score">${h(r.accuracy)}<small>%</small></div>
          <div class="stats">
            <div class="stat"><b>${Number(r.correct)}</b><span>答对</span></div>
            <div class="stat"><b>${Number(r.total) - Number(r.correct)}</b><span>答错</span></div>
            <div class="stat"><b>${Core.formatDuration(r.duration)}</b><span>用时</span></div>
          </div>
          <div class="record-meta"><b>${h(r.student)}</b>${h(r.libName)} · ${h(fmtDate(r.timestamp))}${r.planned && r.planned > r.total ? ` · 中途结束（${r.total}/${r.planned}）` : ''}</div>
        </div>
        ${r.wrongWords && r.wrongWords.length ? `
          <details ${i === 0 ? 'open' : ''}>
            <summary>错词 ${r.wrongWords.length} 个</summary>
            <div class="table-scroll"><table>
              <thead><tr><th>单词</th><th>正确释义</th><th>你的拼写</th><th>你的释义</th></tr></thead>
              <tbody>${r.wrongWords.map(w => `<tr>
                <td class="w">${h(w.word)}</td>
                <td>${(w.senses || []).map(s => `<div>${senseHtml(s)}</div>`).join('')}</td>
                <td>${w.spellOk === false || (w.spellOk === undefined && w.spelling.toLowerCase() !== String(w.word).toLowerCase()) ? `<span class="bad">${h(w.spelling || '—')}</span>` : h(w.spelling || '—')}</td>
                <td>${h(w.meanings || '—')}</td></tr>`).join('')}</tbody>
            </table></div>
          </details>` : '<p class="all-right">全部正确！</p>'}
        <div class="record-foot">
          ${r.wrongWords && r.wrongWords.length ? `<button type="button" class="btn small ghost" data-action="retest" data-id="${Number(r.id)}">重测错词</button>` : ''}
          <button type="button" class="btn small ghost danger" data-action="delete-record" data-id="${Number(r.id)}">删除</button>
        </div>
      </article>`).join('') : '<div class="card empty">还没有测试记录。</div>';
  }
  $('#rec-student').addEventListener('change', renderRecords);

  function retest(id) {
    const r = records.find(x => x.id === id);
    if (!r) return;
    const name = `错词重测 · ${r.libName}`.slice(0, 60);
    const words = r.wrongWords.map(w => ({ word: w.word, senses: w.senses })).filter(w => w.senses && w.senses.length);
    libraries[name] = { name, words, createdAt: new Date().toISOString(), count: words.length };
    saveLibraries();
    renderLibraries();
    prefs.lib = name;
    prefs.student = r.student;
    prefs.all = true;
    showView('test');
    toast(`已把 ${words.length} 个错词放进词库「${name}」`);
  }

  // ======================================================== 全局按钮
  document.addEventListener('click', e => {
    const b = e.target.closest('[data-action]');
    if (!b) return;
    const { action, name } = b.dataset;
    const id = Number(b.dataset.id);
    switch (action) {
      case 'export-txt': return exportTxt();
      case 'export-csv': return exportCsv();
      case 'preview-lib': return showPreview(name);
      case 'close-preview': $('#lib-preview').hidden = true; return;
      case 'test-lib': prefs.lib = name; return showView('test');
      case 'delete-lib':
        if (!libraries[name] || !confirm(`删除词库「${name}」？测试记录会保留。`)) return;
        delete libraries[name];
        saveLibraries();
        renderLibraries();
        if (!$('#lib-preview').hidden) $('#lib-preview').hidden = true;
        return;
      case 'delete-record':
        if (!confirm('删除这条记录？')) return;
        records = records.filter(r => r.id !== id);
        saveRecords();
        return renderRecords();
      case 'retest': return retest(id);
      case 'open-jev': return openJev();
      case 'jev-start': return jevStartClicked();
      case 'jev-stop': return jev.stop().then(renderJev);
      case 'jev-download': return downloadInstaller();
      case 'jev-copy': copyText(b.dataset.text, b); return beginInstallWatch();
      case 'jev-check': return beginInstallWatch(true);
    }
  });

  // ======================================================== 智能判分（本地服务）
  const jev = new Jev.JevClient({
    fetch: (url, init) => fetch(url, init),
    storage: localStorage,
    launch(url) {
      // 用户手势里点一个 jev:// 链接；没装时浏览器什么也不做
      const a = document.createElement('a');
      a.href = url;
      a.rel = 'noopener';
      document.body.appendChild(a);
      a.click();
      a.remove();
    },
    beacon(url) { try { navigator.sendBeacon(url, ''); } catch (_) { /* 页面正在关 */ } },
  });
  jev.on(() => renderJev());

  const ua = navigator.userAgent;
  const platform = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '';
  const OS = /Android|iPhone|iPad|iPod/i.test(ua) || (navigator.maxTouchPoints > 1 && /Mac/.test(platform)) ? 'mobile'
    : /Win/i.test(platform) ? 'windows' : /Mac/i.test(platform) ? 'macos' : /Linux|X11/i.test(platform) ? 'linux' : 'other';
  const ORIGIN = location.origin && location.origin.startsWith('http') ? location.origin : 'https://genuineedu.pages.dev';
  const UNIX_CMD = `curl -fsSL ${ORIGIN}/jev/unix/install.sh | JEV_ORIGIN=${ORIGIN} bash`;
  const WIN_CMD = `powershell -ep bypass -c "iwr -useb ${ORIGIN}/jev/windows/install.ps1 -OutFile $env:TEMP\\jev.ps1; & $env:TEMP\\jev.ps1 -Origin ${ORIGIN}"`;

  const ERRORS = {
    model_missing: ['模型文件不见了', '可能被清理软件删掉了，重新运行一次安装器即可。'],
    llama_missing: ['推理程序不见了', '可能被杀毒软件隔离了。恢复或加入信任后，重新运行安装器。'],
    llama_exit: ['推理程序启动后崩溃了', '重新运行安装器通常能修好；还不行请把安装目录里的 jev/server.log 发给维护者。'],
    llama_start_failed: ['推理程序无法启动', '可能被杀毒软件拦截，加入信任后再试。'],
    port_busy: ['本机端口被占满了', '8001 / 18001 / 28001 都被别的程序占用。关掉它们后再点启动。'],
    startup_timeout: ['启动太慢，超时了', '电脑可能比较忙，稍等再点一次启动。'],
    self_test_failed: ['判分模型在这台电脑上输出异常', '已自动改用文字匹配，不会误判。重新运行一次安装器通常能修好；还不行请联系维护者。'],
  };

  let watchTimer = null;
  let watchUntil = 0;
  let installClicked = false;
  function beginInstallWatch(now) {
    installClicked = true;
    watchUntil = Date.now() + 20 * 60 * 1000;
    if (!watchTimer) watchTimer = setInterval(async () => {
      if (!$('#jev-dialog').open || Date.now() > watchUntil || jev.state === 'ready') { clearInterval(watchTimer); watchTimer = null; return; }
      await jev.probe();
    }, 3000);
    if (now) jev.probe().then(found => { if (!found) toast('还没检测到：安装完成后会自动连上'); });
    renderJev();
  }

  function downloadInstaller() {
    fetch('jev/windows/install-jev.bat.tpl', { cache: 'no-store' })
      .then(r => { if (!r.ok) throw new Error(r.status); return r.text(); })
      .then(tpl => {
        const bat = tpl.replace(/__ORIGIN__/g, ORIGIN).replace(/\r?\n/g, '\r\n');
        download('JEV智能判分安装器.bat', bat, 'application/octet-stream');
      })
      .catch(() => { location.href = 'install-jev-windows.bat'; });
    beginInstallWatch();
  }

  async function jevStartClicked() {
    const ok = await jev.start();
    if (!ok && jev.launchFailed) toast('没有唤起服务：看看浏览器是不是拦截了，或者重新安装一次');
    renderJev();
  }

  function openJev() {
    const d = $('#jev-dialog');
    if (!d.open) { if (d.showModal) d.showModal(); else d.setAttribute('open', ''); }
    renderJev();
    // 已安装过的人打开面板时顺手探一下（没装过的不探，免得浏览器先弹「访问本地网络」）
    if (jev.installed && jev.state !== 'ready' && jev.state !== 'starting') jev.probe();
  }
  $('#jev-chip').addEventListener('click', openJev);

  function chipText() {
    switch (jev.state) {
      case 'ready': return '已开启';
      case 'starting': return '启动中';
      case 'checking': return '检测中';
      case 'error': return '出错了';
      default: return jev.installed ? '待命' : '未开启';
    }
  }

  function renderJev() {
    const chip = $('#jev-chip');
    chip.dataset.state = jev.state === 'offline' && jev.installed ? 'idle' : jev.state;
    $('#jev-chip-state').textContent = chipText();
    chip.title = jev.state === 'ready' ? '本地判分服务正在运行' : '点击查看智能判分';

    const note = $('#t-jev-note');
    if (note) {
      note.textContent = jev.state === 'ready' ? '智能判分已开启：近义的释义也能判对。'
        : jev.installed ? '智能判分会在开始测试时自动启动。'
        : '释义按文字匹配判分。可在右上角开启智能判分。';
    }

    const body = $('#jev-body');
    if (!body || !$('#jev-dialog').open) return;
    body.innerHTML = jevPanel();
  }

  function banner(kind, title, sub) {
    return `<div class="state-banner ${kind}"><span class="big-dot"></span><div><p><b>${title}</b></p>${sub ? `<p>${sub}</p>` : ''}</div></div>`;
  }

  function jevPanel() {
    const intro = '<p class="muted">学生写「令人难堪的」，词表是「尴尬的」——文字匹配会判错，智能判分能看出意思一样。它是一个在你电脑上运行的小模型，答案不会上传。</p>';
    if (jev.state === 'ready') {
      const v = jev.info && jev.info.version ? `版本 ${h(jev.info.version)}` : '';
      return banner('ok', '智能判分已开启', '答题时拼写对、释义没对上，会自动请它判断意思是否接近。')
        + `<p class="muted small">它只在网页打开时运行；关掉所有页面后约 10 秒自动停止，不占内存。空闲时自动休眠。${v}</p>`
        + (jev.outdated ? '<p class="small">有新版本：重新运行一次安装器即可升级。</p>' : '')
        + '<div class="row-actions"><button type="button" class="btn ghost small" data-action="jev-stop">现在停止</button></div>'
        + uninstallHint();
    }
    if (jev.state === 'starting') {
      return banner('wait', '正在启动…', '第一次加载模型需要几秒钟。')
        + '<p class="fine">浏览器如果问「要打开 JEV 吗」，勾选「始终允许」再点打开，以后就不会再问了。</p>';
    }
    if (jev.state === 'checking') return banner('wait', '正在检测本机服务…');
    if (jev.state === 'error') {
      const [t, s] = ERRORS[jev.info && jev.info.error] || ['服务出错了', '重新运行一次安装器通常能修好。'];
      return banner('bad', t, s)
        + `<div class="row-actions"><button type="button" class="btn primary" data-action="jev-start">重试</button>${OS === 'windows' ? '<button type="button" class="btn" data-action="jev-download">重新下载安装器</button>' : ''}</div>`;
    }
    if (jev.installed) {
      return intro
        + (jev.launchFailed
          ? banner('bad', '没能唤起服务', '可能是浏览器拦下了「打开 JEV」的请求，或服务已被卸载。')
          : banner('', '已安装，等待使用', '开始测试时会自动启动，你不用管它。'))
        + '<div class="row-actions"><button type="button" class="btn primary" data-action="jev-start">现在启动</button></div>'
        + `<details class="fine"><summary>启动不了？</summary><ul>
            <li>浏览器问「要打开 JEV 吗」：勾选「始终允许」后点打开。</li>
            <li>浏览器问「允许访问本地网络 / 设备」：点允许（服务只在本机 127.0.0.1）。</li>
            <li>还是不行：重新安装一次（不会重复下载模型）。</li></ul>
            ${installSteps(true)}</details>`;
    }
    if (OS === 'mobile' || OS === 'other') {
      return intro + banner('', '需要在电脑上使用', '智能判分要在 Windows / macOS / Linux 电脑上安装；在这台设备上会使用文字匹配，照常可以答题。');
    }
    return intro + installSteps(false)
      + (installClicked ? `<p class="small muted"><span class="spinner"></span> 等待安装完成，装好后这里会自动变成「已开启」。 <button type="button" class="link" data-action="jev-check">我已经装好了</button></p>` : '');
  }

  function installSteps(compact) {
    if (OS === 'windows') {
      return `<ol class="steps">
        <li><b>下载安装器</b><p>一个很小的 .bat 文件。</p>
          <button type="button" class="btn ${compact ? '' : 'primary'}" data-action="jev-download">下载安装器</button></li>
        <li><b>双击运行</b><p>会自动下载约 520MB 并装好，不需要管理员权限，桌面不会多图标。<br>如果出现「Windows 已保护你的电脑」：点「更多信息 → 仍要运行」。</p></li>
        <li><b>回到这里</b><p>装好后本页会自动连上。以后打开网页自动启动、关掉自动停止。</p></li>
      </ol>
      <details class="fine"><summary>安装器被拦截了？换一种方式</summary>
        <p>按 <kbd>Win</kbd> + <kbd>R</kbd>，粘贴下面这行，回车：</p>
        <div class="cmd"><code>${h(WIN_CMD)}</code><button type="button" class="btn small" data-action="jev-copy" data-text="${h(WIN_CMD)}">复制</button></div>
        <p>卸载：设置 → 应用 → 「JEV 本地判分服务」。</p>
      </details>`;
    }
    const term = OS === 'macos' ? '打开「终端」（启动台里搜索“终端”）' : '打开终端';
    return `<ol class="steps">
      <li><b>${term}</b></li>
      <li><b>粘贴这一行，回车</b><p>会自动下载约 520MB 并装好，不需要管理员密码。</p>
        <div class="cmd"><code>${h(UNIX_CMD)}</code><button type="button" class="btn small ${compact ? '' : 'primary'}" data-action="jev-copy" data-text="${h(UNIX_CMD)}">复制</button></div></li>
      <li><b>回到这里</b><p>装好后本页会自动连上。以后打开网页自动启动、关掉自动停止。</p></li>
    </ol>`;
  }
  function uninstallHint() {
    const how = OS === 'windows' ? '设置 → 应用 → 「JEV 本地判分服务」'
      : OS === 'macos' ? '终端运行 <code>bash ~/Library/Application\\ Support/JEV/uninstall.sh</code>'
      : '终端运行 <code>bash ~/.local/share/JEV/uninstall.sh</code>';
    return `<details class="fine"><summary>怎么卸载</summary><p>${how}</p></details>`;
  }

  // 心跳：只有本页连上过管家才发；切回页面时立刻补一次
  setInterval(() => jev.heartbeat(), 20000);
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') jev.heartbeat(); });
  window.addEventListener('pagehide', () => jev.bye());
  window.addEventListener('beforeunload', e => { if (test && test.answers.length) { e.preventDefault(); e.returnValue = ''; } });

  // ======================================================== 启动
  renderLibraries();
  updateParse();
  showView(location.hash.slice(1) || (Object.keys(libraries).length ? 'test' : 'library'));
  renderJev();
  if (jev.installed) jev.probe();   // 装过的人：静默确认服务在不在
})();
