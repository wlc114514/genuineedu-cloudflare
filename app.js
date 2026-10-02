// 数据结构
let libraries = JSON.parse(localStorage.getItem('libraries') || '{}');
let testRecords = JSON.parse(localStorage.getItem('testRecords') || '[]');
let currentTest = null;

// 系统检测
const OS = (() => {
  const ua = navigator.userAgent;
  const platform = navigator.platform;
  if (platform.startsWith('Win')) return 'windows';
  if (platform.startsWith('Mac')) return 'macos';
  if (platform.startsWith('Linux')) return 'linux';
  // 备用检测
  if (ua.includes('Windows')) return 'windows';
  if (ua.includes('Mac OS')) return 'macos';
  if (ua.includes('Linux')) return 'linux';
  return 'unknown';
})();

const OS_CONFIG = {
  windows: {
    label: 'Windows',
    execName: 'llama-server.exe',
    pathExample: '安装位置：C:\\Users\\<你的用户名>\\AppData\\Local\\Programs\\JEV\\',
    modelPath: '模型文件：...\\Programs\\JEV\\jev\\Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf',
    runCommand: '网页顶部点「启动判分服务」按钮即可；服务地址 http://127.0.0.1:8001'
  },
  macos: {
    label: 'macOS',
    execName: 'llama-server',
    pathExample: '安装位置：~/Library/Application Support/JEV/',
    modelPath: '模型文件：~/Library/Application Support/JEV/jev/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf',
    runCommand: '双击安装目录里的「启动判分服务.command」；服务地址 http://127.0.0.1:8001'
  },
  linux: {
    label: 'Linux',
    execName: 'llama-server',
    pathExample: '安装位置：~/.local/share/JEV/',
    modelPath: '模型文件：~/.local/share/JEV/jev/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf',
    runCommand: '运行 ./jev/llama/llama-server -m jev/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf --host 127.0.0.1 --port 8001 -c 2048 -t 8 --no-webui'
  }
};

// ============= 本地判分服务（JEV，本机 llama-server） =============
const JEV_BASE = 'http://127.0.0.1:8001';
const JEV_TEMPERATURE = 0.8800546821789332;
const JEV_TOKEN_YES = 9542;
const JEV_TOKEN_NO = 874;
const JEV_THRESHOLD = 0.9;
let jevOnline = false;
const jevCache = new Map();

function updateJevBadge() {
  const text = jevOnline ? '本地判分服务：已连接' : '本地判分服务：未启动';
  for (const id of ['jev-badge', 'jev-status-download']) {
    const el = document.getElementById(id);
    if (el) {
      el.textContent = text;
      el.style.color = jevOnline ? 'var(--success, #16a34a)' : 'var(--text-ghost, #6b7280)';
    }
  }
  const btn = document.getElementById('jev-start-btn');
  if (btn) {
    if (jevOnline) {
      btn.style.display = 'none';
    } else {
      btn.style.display = 'inline-block';
      if (!btn.disabled && btn.textContent !== '启动中…') btn.textContent = '启动判分服务';
    }
  }
}

function jevStart() {
  const btn = document.getElementById('jev-start-btn');
  if (btn) { btn.disabled = true; btn.textContent = '启动中…'; }
  // 通过自定义协议 jev:// 唤起本地服务（浏览器首次会询问，选「允许/打开」）
  try {
    const a = document.createElement('a');
    a.href = 'jev://start';
    document.body.appendChild(a);
    a.click();
    a.remove();
  } catch (e) { /* ignore */ }
  let n = 0;
  const timer = setInterval(async () => {
    n++;
    const ok = await jevHealth();
    if (ok || n >= 12) {
      clearInterval(timer);
      if (btn) {
        btn.disabled = false;
        btn.textContent = ok ? '已启动' : '没成功？点我再试';
      }
    }
  }, 2500);
}

async function jevHealth() {
  try {
    const r = await fetch(JEV_BASE + '/health', { signal: AbortSignal.timeout(2000) });
    jevOnline = r.ok && (await r.json()).status === 'ok';
  } catch (e) {
    jevOnline = false;
  }
  updateJevBadge();
  return jevOnline;
}

function jevPrompt(meaning, ans, k) {
  const opts = ['一致: 意思相同或非常接近', '不一致: 意思不同或无关'];
  const head = 'State:\n标准释义：' + meaning + '\n学生写的释义：' + ans + '\n\n'
    + 'Question [choice]: 学生写的释义与标准释义表达的意思是否一致？\nOptions:\n'
    + opts.map(o => '- ' + o + '\n').join('') + 'Judge each option:\n';
  let tail = opts[k] + ' ->';
  if (k) tail = opts[0] + ' ->\n' + tail;
  return head + tail;
}

// 返回 {p} 或 {err}；p = 「意思接近」置信度 0~1
async function jevJudge(meaning, ans) {
  if (!ans || !/[0-9A-Za-z\u4e00-\u9fff]/.test(ans)) return { p: 0 };
  const key = meaning + '||' + ans;
  if (jevCache.has(key)) return { p: jevCache.get(key) };
  const ds = [];
  for (const k of [0, 1]) {
    const r = await fetch(JEV_BASE + '/completion', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt: jevPrompt(meaning, ans, k),
        n_predict: 1, temperature: 0, n_probs: 32, cache_prompt: false
      }),
      signal: AbortSignal.timeout(20000)
    });
    const out = await r.json();
    const cp = (out.completion_probabilities || [])[0] || {};
    const lp = {};
    for (const e of (cp.top_logprobs || [])) lp[e.id] = e.logprob;
    if (!(JEV_TOKEN_YES in lp) || !(JEV_TOKEN_NO in lp)) return { err: '缺少 yes/no 概率' };
    ds.push(lp[JEV_TOKEN_YES] - lp[JEV_TOKEN_NO]);
  }
  let z = (ds[0] - ds[1]) / JEV_TEMPERATURE;
  z = Math.max(-30, Math.min(30, z));
  const p = 1 / (1 + Math.exp(-z));
  jevCache.set(key, p);
  return { p };
}

// 初始化
document.addEventListener('DOMContentLoaded', () => {
  renderLibraryTable();
  renderTestLibrarySelect();
  renderRecords();
  setupTabs();
  updateOSInfo();
  jevHealth();
  
  document.getElementById('test-all').addEventListener('change', (e) => {
    document.getElementById('test-count').disabled = e.target.checked;
  });
});

// Tab 切换
function setupTabs() {
  document.querySelectorAll('.tabs button').forEach(btn => {
    btn.addEventListener('click', () => {
      const target = btn.dataset.tab;
      
      document.querySelectorAll('.tabs button').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      
      btn.classList.add('active');
      document.getElementById(target).classList.add('active');
      
      if (target === 'test' || target === 'download') jevHealth();
    });
  });
}

// 词库管理
function parseAndImport() {
  const name = document.getElementById('lib-name').value.trim();
  const text = document.getElementById('word-input').value.trim();
  
  if (!name) {
    alert('请输入词库名称');
    return;
  }
  
  if (!text) {
    alert('请粘贴单词表');
    return;
  }
  
  const words = parseWordList(text);
  
  if (words.length === 0) {
    alert('未能解析出任何单词，请检查格式');
    return;
  }
  
  renderPreview(words);
  
  libraries[name] = {
    name,
    words,
    createdAt: new Date().toISOString(),
    count: words.length
  };
  
  localStorage.setItem('libraries', JSON.stringify(libraries));
  
  renderLibraryTable();
  renderTestLibrarySelect();
  
  alert(`成功导入 ${words.length} 个单词到词库 "${name}"`);
  
  document.getElementById('lib-name').value = '';
  document.getElementById('word-input').value = '';
}

function parseWordList(text) {
  const lines = text.split('\n').filter(l => l.trim());
  const words = [];
  
  for (const line of lines) {
    const parts = line.split(/[\t;]|[ ]{2,}/).map(p => p.trim()).filter(p => p);
    
    if (parts.length < 3) continue;
    
    const word = parts[0];
    const senses = [];
    
    let i = 1;
    while (i < parts.length) {
      const pos = normalizePos(parts[i]);
      const meanings = [];
      
      i++;
      while (i < parts.length && !isPos(parts[i])) {
        meanings.push(parts[i]);
        i++;
      }
      
      if (meanings.length > 0) {
        senses.push({ pos, meanings: meanings.join('；') });
      }
    }
    
    if (senses.length > 0) {
      words.push({ word, senses });
    }
  }
  
  return words;
}

function isPos(str) {
  return /^(v\.?|n\.?|adj\.?|adv\.?|prep\.?|conj\.?|pron\.?|interj\.?|动词|名词|形容词|副词|介词|连词|代词|感叹词|v&n\.?|n&v\.?)$/i.test(str);
}

function normalizePos(pos) {
  const map = {
    'v': 'v', 'v.': 'v', '动词': 'v',
    'n': 'n', 'n.': 'n', '名词': 'n',
    'adj': 'adj', 'adj.': 'adj', '形容词': 'adj',
    'adv': 'adv', 'adv.': 'adv', '副词': 'adv',
    'prep': 'prep', 'prep.': 'prep', '介词': 'prep',
    'conj': 'conj', 'conj.': 'conj', '连词': 'conj',
    'pron': 'pron', 'pron.': 'pron', '代词': 'pron',
    'interj': 'interj', 'interj.': 'interj', '感叹词': 'interj',
    'v&n': 'v&n', 'v&n.': 'v&n', 'n&v': 'v&n', 'n&v.': 'v&n'
  };
  
  return map[pos.toLowerCase()] || pos;
}

function renderPreview(words) {
  const preview = document.getElementById('preview');
  const content = document.getElementById('preview-content');
  
  let html = '';
  for (const w of words.slice(0, 50)) {
    html += `<div style="margin-bottom:0.75rem;">`;
    html += `<span class="preview-word">${w.word}</span>`;
    for (const s of w.senses) {
      html += `<div class="preview-sense">${s.pos}. ${s.meanings}</div>`;
    }
    html += `</div>`;
  }
  
  if (words.length > 50) {
    html += `<div style="color:var(--text-ghost)">... 还有 ${words.length - 50} 个单词</div>`;
  }
  
  content.innerHTML = html;
  preview.style.display = 'block';
}

function renderLibraryTable() {
  const tbody = document.querySelector('#lib-table tbody');
  const libs = Object.values(libraries).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  
  if (libs.length === 0) {
    tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;color:var(--text-ghost)">暂无词库</td></tr>';
    return;
  }
  
  tbody.innerHTML = libs.map(lib => `
    <tr>
      <td>${lib.name}</td>
      <td>${lib.count}</td>
      <td>${new Date(lib.createdAt).toLocaleString('zh-CN')}</td>
      <td>
        <button onclick="deleteLibrary('${lib.name}')">删除</button>
      </td>
    </tr>
  `).join('');
}

function renderTestLibrarySelect() {
  const select = document.getElementById('test-library');
  const libs = Object.keys(libraries);
  
  if (libs.length === 0) {
    select.innerHTML = '<option value="">暂无词库</option>';
    return;
  }
  
  select.innerHTML = libs.map(name => `<option value="${name}">${name}</option>`).join('');
}

function deleteLibrary(name) {
  if (!confirm(`确定删除词库 "${name}"？`)) return;
  
  delete libraries[name];
  localStorage.setItem('libraries', JSON.stringify(libraries));
  
  renderLibraryTable();
  renderTestLibrarySelect();
}

function exportAllTxt() {
  let content = '';
  
  for (const lib of Object.values(libraries)) {
    content += `=== ${lib.name} ===\n\n`;
    for (const w of lib.words) {
      content += `${w.word}\n`;
      for (const s of w.senses) {
        content += `  ${s.pos}. ${s.meanings}\n`;
      }
      content += '\n';
    }
    content += '\n';
  }
  
  downloadFile(`词库导出_${Date.now()}.txt`, content);
}

function exportAllCsv() {
  let csv = '\uFEFF';
  csv += '词库,单词,词性,释义\n';
  
  for (const lib of Object.values(libraries)) {
    for (const w of lib.words) {
      for (const s of w.senses) {
        csv += `"${lib.name}","${w.word}","${s.pos}","${s.meanings}"\n`;
      }
    }
  }
  
  downloadFile(`词库导出_${Date.now()}.csv`, csv);
}

function downloadFile(filename, content) {
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

// 测试逻辑
function startTest() {
  const libName = document.getElementById('test-library').value;
  const student = document.getElementById('test-student').value.trim();
  const useAll = document.getElementById('test-all').checked;
  const count = parseInt(document.getElementById('test-count').value);
  const hint = document.getElementById('test-hint').value;
  const match = document.getElementById('test-match').value;
  const criteria = document.getElementById('test-criteria').value;
  const timeout = parseInt(document.getElementById('test-timeout').value);
  const display = document.getElementById('test-display').value;
  const inflection = document.getElementById('test-inflection').checked;
  
  if (!libName || !libraries[libName]) {
    alert('请选择词库');
    return;
  }
  
  if (!student) {
    alert('请输入学生姓名');
    return;
  }
  
  const lib = libraries[libName];
  let words = [...lib.words];
  
  words = shuffle(words);
  
  if (!useAll && count < words.length) {
    words = words.slice(0, count);
  }
  
  currentTest = {
    libName,
    student,
    words,
    config: { hint, match, criteria, timeout, display, inflection },
    current: 0,
    answers: [],
    startTime: Date.now()
  };
  
  document.getElementById('header-student').textContent = student;
  
  document.querySelector('.test-config').style.display = 'none';
  document.getElementById('test-ui').style.display = 'block';
  
  renderQuestion();
}

function shuffle(arr) {
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

function renderQuestion() {
  const { words, current, config } = currentTest;
  const word = words[current];
  
  const sense = config.display === 'random' 
    ? word.senses[Math.floor(Math.random() * word.senses.length)]
    : null;
  currentTest.askedSense = sense;
  
  const hint = generateHint(word.word, config.hint);
  
  const ui = document.getElementById('test-ui');
  
  ui.innerHTML = `
    <div class="test-header">
      <div class="progress">${current + 1} / ${words.length}</div>
      <div class="timer" id="timer">—</div>
    </div>
    
    <div class="question-card">
      ${config.display === 'random' ? `
        <div class="asked-sense">
          <div class="pos">${sense.pos}</div>
          <div class="meaning">${sense.meanings}</div>
        </div>
      ` : `
        <div class="asked-sense">
          ${word.senses.map(s => `
            <div class="pos">${s.pos}</div>
            <div class="meaning">${s.meanings}</div>
          `).join('')}
        </div>
      `}
      
      <div class="hint-letters">${hint}</div>
      
      <label>
        <span>拼写</span>
        <input type="text" id="answer-spelling" autofocus>
      </label>
      
      <label>
        <span>释义（多个释义用分号、逗号或顿号分隔）</span>
        <textarea id="answer-meanings" rows="3"></textarea>
      </label>
      
      <div class="actions">
        <button class="primary" onclick="submitAnswer()">提交答案</button>
      </div>
    </div>
  `;
  
  if (config.timeout > 0) {
    startTimer(config.timeout);
  }
  
  document.getElementById('answer-spelling').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      document.getElementById('answer-meanings').focus();
    }
  });
}

function generateHint(word, strategy) {
  if (strategy === 'none') return '___';
  if (strategy === 'first') return word[0] + '___';
  
  const showCount = Math.floor(word.length / 2);
  let result = '';
  for (let i = 0; i < word.length; i++) {
    result += i < showCount ? word[i] : '_';
  }
  return result;
}

let timerInterval = null;
function startTimer(seconds) {
  let remaining = seconds;
  const timerEl = document.getElementById('timer');
  
  timerEl.textContent = `${remaining}s`;
  
  timerInterval = setInterval(() => {
    remaining--;
    timerEl.textContent = `${remaining}s`;
    
    if (remaining <= 0) {
      clearInterval(timerInterval);
      submitAnswer(true);
    }
  }, 1000);
}

async function submitAnswer(isTimeout = false) {
  if (timerInterval) {
    clearInterval(timerInterval);
    timerInterval = null;
  }
  
  const { words, current, config } = currentTest;
  const word = words[current];
  
  const spelling = document.getElementById('answer-spelling').value.trim().toLowerCase();
  const meanings = document.getElementById('answer-meanings').value.trim();
  
  const spellingCorrect = spelling === word.word.toLowerCase();
  let meaningsCorrect = meaningsMatch(word, meanings, config);
  let judgeP = null;
  
  // 字面判不出 + 拼写正确 → 交给本地 JEV 模型判断「意思是否接近」
  if (config.criteria === 'any' && spellingCorrect && !meaningsCorrect && !isBlankText(meanings)) {
    if (!jevOnline) await jevHealth();
    if (jevOnline) {
      setSubmitBusy(true, '模型判分中…');
      try {
        const judgeTarget = currentTest.askedSense
          ? currentTest.askedSense.meanings
          : word.senses.map(s => s.meanings).join('；');
        const res = await jevJudge(judgeTarget, meanings);
        if (!res.err && res.p != null) {
          judgeP = res.p;
          if (res.p >= JEV_THRESHOLD) meaningsCorrect = true;
        }
      } catch (e) { /* 服务异常 → 静默退回字面判分 */ }
      setSubmitBusy(false);
    }
  }
  
  const correct = config.criteria === 'any'
    ? (spellingCorrect && meaningsCorrect)
    : spellingCorrect;
  
  currentTest.answers.push({
    word: word.word,
    senses: word.senses,
    spelling,
    meanings,
    correct,
    isTimeout,
    judgeP
  });
  
  renderFeedback(word, spelling, meanings, correct, isTimeout, judgeP);
}

function meaningsMatch(word, meanings, config) {
  if (!meanings) return false;
  if (config.match === 'loose') {
    const userKeywords = extractKeywords(meanings);
    const correctKeywords = word.senses.flatMap(s => extractKeywords(s.meanings));
    return userKeywords.some(uk => correctKeywords.includes(uk));
  }
  const normalized = meanings.replace(/[；，、]/g, ';').toLowerCase();
  const correctMeanings = word.senses.flatMap(s => s.meanings.split(/[；，、;]/).map(m => m.trim().toLowerCase()));
  return correctMeanings.some(cm => normalized.includes(cm));
}

function isBlankText(s) {
  return !/[0-9A-Za-z\u4e00-\u9fff]/.test(s || '');
}

function setSubmitBusy(busy, label) {
  const btn = document.querySelector('#test-ui .actions button.primary');
  if (!btn) return;
  if (busy) {
    btn.disabled = true;
    btn.dataset.oldLabel = btn.textContent;
    btn.textContent = label || '判分中…';
  } else {
    btn.disabled = false;
    if (btn.dataset.oldLabel) btn.textContent = btn.dataset.oldLabel;
  }
}

function extractKeywords(text) {
  return text.split(/[；，、;,、\s]/)
    .map(w => w.trim())
    .filter(w => w.length >= 2);
}

function renderFeedback(word, spelling, meanings, correct, isTimeout, judgeP = null) {
  const ui = document.getElementById('test-ui');
  
  ui.innerHTML = `
    <div class="feedback">
      <div class="result ${correct ? 'correct' : 'wrong'}">
        ${correct ? '✓ 正确' : '✗ 错误'}
      </div>
      
      ${isTimeout ? '<p style="color:var(--warning);margin-bottom:1.5rem;">超时自动提交</p>' : ''}
      ${judgeP != null ? `<p style="color:var(--paper-dim);margin-bottom:1rem;">本地模型判分：接近度 ${judgeP.toFixed(2)}（${judgeP >= JEV_THRESHOLD ? '判为接近' : '低于 0.90'}）</p>` : ''}
      
      <div class="answer-box">
        <strong>正确答案：</strong><br>
        <strong>${word.word}</strong><br>
        ${word.senses.map(s => `${s.pos}. ${s.meanings}`).join('<br>')}
      </div>
      
      <div class="answer-box">
        <strong>你的答案：</strong><br>
        拼写：${spelling || '（未填写）'}<br>
        释义：${meanings || '（未填写）'}
      </div>
      
      <div class="actions">
        <button class="primary" onclick="nextQuestion()">下一题</button>
      </div>
    </div>
  `;
}

function nextQuestion() {
  currentTest.current++;
  
  if (currentTest.current >= currentTest.words.length) {
    finishTest();
  } else {
    renderQuestion();
  }
}

function finishTest() {
  const { libName, student, words, answers, startTime, config } = currentTest;
  
  const endTime = Date.now();
  const duration = Math.floor((endTime - startTime) / 1000);
  
  const correctCount = answers.filter(a => a.correct).length;
  const accuracy = ((correctCount / answers.length) * 100).toFixed(1);
  
  const wrongWords = answers.filter(a => !a.correct);
  
  const record = {
    id: Date.now(),
    libName,
    student,
    total: answers.length,
    correct: correctCount,
    accuracy,
    duration,
    wrongWords,
    config,
    timestamp: new Date().toISOString()
  };
  
  testRecords.unshift(record);
  localStorage.setItem('testRecords', JSON.stringify(testRecords));
  
  document.querySelector('.tabs button[data-tab="results"]').click();
  renderRecords();
  
  document.getElementById('test-ui').style.display = 'none';
  document.querySelector('.test-config').style.display = 'grid';
  
  currentTest = null;
}

// 结果页
function renderRecords() {
  const container = document.getElementById('records-list');
  
  if (testRecords.length === 0) {
    container.innerHTML = '<p style="text-align:center;color:var(--text-ghost);padding:2rem;">暂无测试记录</p>';
    return;
  }
  
  container.innerHTML = `<div class="records-scroll">${testRecords.map(record => `
    <div class="record-card">
      <div class="record-stats">
        <div class="stat">
          <span class="stat-value">${record.accuracy}%</span>
          <span class="stat-label">正确率</span>
        </div>
        <div class="stat">
          <span class="stat-value">${record.correct}</span>
          <span class="stat-label">答对</span>
        </div>
        <div class="stat">
          <span class="stat-value">${record.total - record.correct}</span>
          <span class="stat-label">答错</span>
        </div>
        <div class="stat">
          <span class="stat-value">${Math.floor(record.duration / 60)}:${(record.duration % 60).toString().padStart(2, '0')}</span>
          <span class="stat-label">用时</span>
        </div>
      </div>
      
      <div class="record-meta">
        <strong>${record.student}</strong> · ${record.libName} · ${new Date(record.timestamp).toLocaleString('zh-CN')}
      </div>
      
      ${record.wrongWords.length > 0 ? `
        <h3>错词详情</h3>
        <table>
          <thead>
            <tr>
              <th>单词</th>
              <th>正确答案</th>
              <th>你的拼写</th>
              <th>你的释义</th>
            </tr>
          </thead>
          <tbody>
            ${record.wrongWords.map(w => `
              <tr class="wrong-word">
                <td><strong>${w.word}</strong></td>
                <td>${w.senses.map(s => `${s.pos}. ${s.meanings}`).join('<br>')}</td>
                <td>${w.spelling || '—'}</td>
                <td>${w.meanings || '—'}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      ` : '<p style="color:var(--success);text-align:center;padding:1.5rem;">全部正确！</p>'}
      
      <div class="actions">
        <button onclick="deleteRecord(${record.id})">删除记录</button>
      </div>
    </div>
  `).join('')}</div>`;
}

function deleteRecord(id) {
  if (!confirm('确定删除此记录？')) return;
  
  testRecords = testRecords.filter(r => r.id !== id);
  localStorage.setItem('testRecords', JSON.stringify(testRecords));
  
  renderRecords();
}

// JEV 模型下载
function updateOSInfo() {
  const config = OS_CONFIG[OS] || OS_CONFIG.windows;
  
  // 更新检测到的系统
  const osSpan = document.getElementById('detected-os');
  if (osSpan) {
    osSpan.textContent = config.label;
  }
  
  // 更新安装脚本后缀
  const extEl = document.getElementById('installer-ext');
  if (extEl) {
    extEl.textContent = OS === 'macos' ? '(.sh)' : '(.bat)';
  }
  
  // 更新按钮文本
  const btn = document.getElementById('download-llama-btn');
  if (btn) {
    btn.textContent = `下载 ${config.execName}`;
  }
  
  // 更新文件路径示例
  const pathsEl = document.getElementById('file-paths');
  if (pathsEl) {
    pathsEl.innerHTML = `${config.pathExample}<br>${config.modelPath}`;
  }
  
  // 更新启动命令
  const cmdEl = document.getElementById('run-command');
  if (cmdEl) {
    cmdEl.textContent = config.runCommand;
  }
}

async function downloadLlamaCpp() {
  const status = document.getElementById('llama-status');
  const GH = 'https://gh-proxy.com/https://github.com/ggml-org/llama.cpp/releases/download/b8944/';
  
  if (OS === 'macos') {
    const file = 'llama-b8944-bin-macos-arm64.tar.gz';
    const a = document.createElement('a');
    a.href = GH + file;
    a.download = file;
    a.click();
    status.innerHTML = `✅ 下载已开始（约 8MB）。Apple Silicon 版：${file}；Intel 芯片请改用 <a href="${GH}llama-b8944-bin-macos-x64.tar.gz">x64 版</a>。<br>解压后把所有文件放到 ~/Library/Application Support/JEV/jev/llama/`;
  } else {
    const file = 'llama-b8944-bin-win-cpu-x64.zip';
    const a = document.createElement('a');
    a.href = GH + file;
    a.download = file;
    a.click();
    status.innerHTML = `✅ 下载已开始（约 16MB）。解压后把解压出的所有文件放到 %LOCALAPPDATA%\\Programs\\JEV\\jev\\llama\\`;
  }
}

async function downloadJevModel() {
  const status = document.getElementById('jev-status');
  
  // HuggingFace 国内镜像直链（已实测可用）
  const modelUrl = 'https://hf-mirror.com/chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF/resolve/main/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf';
  
  status.textContent = '准备下载约 529MB 的模型文件...';
  
  // 触发浏览器下载
  const a = document.createElement('a');
  a.href = modelUrl;
  a.download = 'Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf';
  a.click();
  
  const pathHint = OS === 'macos'
    ? '~/Library/Application Support/JEV/jev/ 目录'
    : '%LOCALAPPDATA%\\Programs\\JEV\\jev\\ 目录';
  
  status.textContent = `✅ 下载已开始：Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf（约 529MB，放到 ${pathHint}）`;
}

function downloadInstaller() {
  const status = document.getElementById('installer-status');
  const isMac = OS === 'macos';
  const installerFile = isMac ? 'install-jev-macos.sh' : 'install-jev-windows.bat';
  
  status.textContent = '准备下载一键安装脚本...';
  
  // 触发浏览器下载
  const a = document.createElement('a');
  a.href = installerFile;
  a.download = installerFile;
  a.click();
  
  if (isMac) {
    status.innerHTML = `✅ 下载已开始：${installerFile}<br>下载后打开「终端」执行：<code>bash ~/Downloads/${installerFile}</code>；装好后双击「启动判分服务.command」保持窗口打开。`;
  } else {
    status.innerHTML = `✅ 下载已开始：${installerFile}<br>下载后双击运行（浏览器若提示"不常下载的文件"，请选择保留）；装好后双击桌面「JEV本地判分服务」保持窗口打开。`;
  }
}
