// ===== 数据存储 =====
const STORAGE_KEYS = {
  LIBRARIES: 'wt_libraries',
  RECORDS: 'wt_records',
  SETTINGS: 'wt_settings',
  LAST_STUDENT: 'wt_last_student'
};

function loadData(key, defaultValue = []) {
  try {
    const data = localStorage.getItem(key);
    return data ? JSON.parse(data) : defaultValue;
  } catch (e) {
    console.error('加载数据失败:', e);
    return defaultValue;
  }
}

function saveData(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (e) {
    console.error('保存数据失败:', e);
    alert('保存失败，请检查浏览器存储空间');
  }
}

// ===== 词库解析 =====
function parseWordList(text) {
  const lines = text.trim().split('\n').filter(l => l.trim());
  const entries = [];
  
  for (let line of lines) {
    line = line.trim();
    if (!line) continue;
    
    // 分隔符：Tab > 分号 > 多个空格
    let parts;
    if (line.includes('\t')) {
      parts = line.split('\t').filter(p => p.trim());
    } else if (line.includes(';')) {
      parts = line.split(';').filter(p => p.trim());
    } else {
      parts = line.split(/\s{2,}/).filter(p => p.trim());
      if (parts.length === 1) {
        parts = line.split(/\s+/).filter(p => p.trim());
      }
    }
    
    if (parts.length < 2) continue;
    
    const word = parts[0].toLowerCase().trim();
    const senses = [];
    
    // 解析词性和释义
    for (let i = 1; i < parts.length; i++) {
      const part = parts[i].trim();
      
      // 匹配词性（支持 v. / v / 动词 / v&n / v.&n.）
      const posMatch = part.match(/^((?:v\.?|n\.?|adj\.?|adv\.?|prep\.?|conj\.?|pron\.?|interj\.?|vt\.?|vi\.?|动词|名词|形容词|副词|介词|连词|代词|感叹词)(?:[&＆](?:v\.?|n\.?|adj\.?|adv\.?))*)/i);
      
      if (posMatch) {
        const pos = posMatch[1].trim();
        const meaning = part.slice(posMatch[0].length).trim();
        
        if (meaning) {
          // 一个词性下的多个释义用逗号/顿号分隔
          const meanings = meaning.split(/[,，、]/).map(m => m.trim()).filter(m => m);
          meanings.forEach(m => {
            senses.push({ pos, meaning: m });
          });
        }
      }
    }
    
    if (senses.length > 0) {
      entries.push({ word, senses });
    }
  }
  
  return entries;
}

// ===== 词库管理 =====
function renderLibraries() {
  const libs = loadData(STORAGE_KEYS.LIBRARIES);
  const tbody = document.querySelector('#libraries-table tbody');
  
  if (libs.length === 0) {
    tbody.innerHTML = '<tr><td colspan="4" style="text-align: center; color: var(--text-muted);">暂无词库</td></tr>';
    return;
  }
  
  tbody.innerHTML = libs.map(lib => `
    <tr>
      <td>${lib.name}</td>
      <td>${lib.count}</td>
      <td>${new Date(lib.createdAt).toLocaleDateString('zh-CN')}</td>
      <td>
        <button onclick="useLibrary('${lib.id}')">使用</button>
        <button onclick="viewLibrary('${lib.id}')">查看</button>
        <button onclick="exportLibrary('${lib.id}', 'txt')">⬇️ TXT</button>
        <button onclick="exportLibrary('${lib.id}', 'csv')">⬇️ CSV</button>
        <button onclick="deleteLibrary('${lib.id}')">删除</button>
      </td>
    </tr>
  `).join('');
}

function addLibrary(name, entries) {
  const libs = loadData(STORAGE_KEYS.LIBRARIES);
  const lib = {
    id: Date.now().toString(36) + Math.random().toString(36).substr(2),
    name,
    entries,
    createdAt: Date.now(),
    count: entries.length
  };
  libs.push(lib);
  saveData(STORAGE_KEYS.LIBRARIES, libs);
  renderLibraries();
  updateTestLibrarySelect();
  return lib;
}

function deleteLibrary(id) {
  if (!confirm('确定删除此词库？')) return;
  const libs = loadData(STORAGE_KEYS.LIBRARIES);
  saveData(STORAGE_KEYS.LIBRARIES, libs.filter(l => l.id !== id));
  renderLibraries();
  updateTestLibrarySelect();
}

function useLibrary(id) {
  document.getElementById('test-lib').value = id;
  switchTab('test');
}

function viewLibrary(id) {
  const libs = loadData(STORAGE_KEYS.LIBRARIES);
  const lib = libs.find(l => l.id === id);
  if (!lib) return;
  
  const content = lib.entries.map(e => 
    `${e.word}\t${e.senses.map(s => `${s.pos} ${s.meaning}`).join('\t')}`
  ).join('\n');
  
  alert(`词库：${lib.name}\n词数：${lib.count}\n\n${content.slice(0, 500)}${content.length > 500 ? '\n...' : ''}`);
}

function exportLibrary(id, format) {
  const libs = loadData(STORAGE_KEYS.LIBRARIES);
  const lib = libs.find(l => l.id === id);
  if (!lib) return;
  
  let content, filename, type;
  
  if (format === 'txt') {
    content = lib.entries.map(e => 
      `${e.word}\t${e.senses.map(s => `${s.pos} ${s.meaning}`).join('\t')}`
    ).join('\n');
    filename = `${lib.name}.txt`;
    type = 'text/plain';
  } else {
    content = 'word,pos,meaning\n' + lib.entries.flatMap(e =>
      e.senses.map(s => `${e.word},${s.pos},"${s.meaning}"`)
    ).join('\n');
    filename = `${lib.name}.csv`;
    type = 'text/csv';
  }
  
  download(content, filename, type);
}

function exportAllLibraries(format) {
  const libs = loadData(STORAGE_KEYS.LIBRARIES);
  if (libs.length === 0) {
    alert('暂无词库');
    return;
  }
  
  let content, filename, type;
  
  if (format === 'txt') {
    content = libs.map(lib => 
      `# ${lib.name}\n` + lib.entries.map(e => 
        `${e.word}\t${e.senses.map(s => `${s.pos} ${s.meaning}`).join('\t')}`
      ).join('\n')
    ).join('\n\n');
    filename = 'all-libraries.txt';
    type = 'text/plain';
  } else {
    content = 'library,word,pos,meaning\n' + libs.flatMap(lib =>
      lib.entries.flatMap(e =>
        e.senses.map(s => `"${lib.name}",${e.word},${s.pos},"${s.meaning}"`)
      )
    ).join('\n');
    filename = 'all-libraries.csv';
    type = 'text/csv';
  }
  
  download(content, filename, type);
}

function download(content, filename, type) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

// ===== 测试配置 =====
function updateTestLibrarySelect() {
  const libs = loadData(STORAGE_KEYS.LIBRARIES);
  const select = document.getElementById('test-lib');
  
  if (libs.length === 0) {
    select.innerHTML = '<option value="">请先添加词库</option>';
    return;
  }
  
  select.innerHTML = libs.map(lib => 
    `<option value="${lib.id}">${lib.name}（${lib.count} 词）</option>`
  ).join('');
}

function loadSettings() {
  const settings = loadData(STORAGE_KEYS.SETTINGS, {
    pickCount: '50',
    pickAll: false,
    hintMode: 'auto',
    matchMode: 'loose',
    wrongRule: 'any',
    timeLimit: '0',
    senseShow: 'random',
    extEnabled: false,
    student: ''
  });
  
  document.getElementById('test-count').value = settings.pickCount;
  document.getElementById('test-all').checked = settings.pickAll;
  document.getElementById('hint-mode').value = settings.hintMode;
  document.getElementById('match-mode').value = settings.matchMode;
  document.getElementById('wrong-rule').value = settings.wrongRule;
  document.getElementById('time-limit').value = settings.timeLimit;
  document.getElementById('sense-show').value = settings.senseShow;
  document.getElementById('ext-enabled').checked = settings.extEnabled;
  
  const lastStudent = loadData(STORAGE_KEYS.LAST_STUDENT, '');
  document.getElementById('test-student').value = lastStudent;
  document.getElementById('header-student').textContent = lastStudent || '—';
}

function saveSettings() {
  const settings = {
    pickCount: document.getElementById('test-count').value,
    pickAll: document.getElementById('test-all').checked,
    hintMode: document.getElementById('hint-mode').value,
    matchMode: document.getElementById('match-mode').value,
    wrongRule: document.getElementById('wrong-rule').value,
    timeLimit: document.getElementById('time-limit').value,
    senseShow: document.getElementById('sense-show').value,
    extEnabled: document.getElementById('ext-enabled').checked,
    student: document.getElementById('test-student').value
  };
  saveData(STORAGE_KEYS.SETTINGS, settings);
  
  const student = document.getElementById('test-student').value;
  if (student) {
    saveData(STORAGE_KEYS.LAST_STUDENT, student);
    document.getElementById('header-student').textContent = student;
  }
}

// ===== 测试逻辑 =====
let currentTest = null;

function startTest() {
  saveSettings();
  
  const libId = document.getElementById('test-lib').value;
  const student = document.getElementById('test-student').value.trim();
  
  if (!libId) {
    alert('请选择词库');
    return;
  }
  
  if (!student) {
    alert('请输入学生姓名');
    return;
  }
  
  const libs = loadData(STORAGE_KEYS.LIBRARIES);
  const lib = libs.find(l => l.id === libId);
  if (!lib) {
    alert('词库不存在');
    return;
  }
  
  const settings = loadData(STORAGE_KEYS.SETTINGS);
  let items = [...lib.entries];
  
  // 打乱顺序
  items = items.sort(() => Math.random() - 0.5);
  
  // 抽取数量
  if (!settings.pickAll) {
    const count = parseInt(settings.pickCount);
    items = items.slice(0, count);
  }
  
  // 准备测试项
  currentTest = {
    student,
    libName: lib.name,
    libId: lib.id,
    settings,
    items: items.map(entry => ({
      word: entry.word,
      entrySenses: entry.senses,
      asked: settings.senseShow === 'random' 
        ? entry.senses[Math.floor(Math.random() * entry.senses.length)]
        : null,
      hint: generateHint(entry.word, settings.hintMode),
      answer: null,
      result: null
    })),
    currentIndex: 0,
    startTime: Date.now(),
    duration: 0
  };
  
  showTestUI();
  renderQuestion();
}

function generateHint(word, mode) {
  if (mode === 'none') return '';
  if (mode === 'first') return word[0] + '_'.repeat(word.length - 1);
  
  // auto: 展示不超过一半
  const showCount = Math.floor(word.length / 2);
  return word.slice(0, showCount) + '_'.repeat(word.length - showCount);
}

function showTestUI() {
  document.getElementById('test-tab').classList.remove('active');
  document.getElementById('testing-tab').classList.add('active');
}

function renderQuestion() {
  if (!currentTest) return;
  
  const item = currentTest.items[currentTest.currentIndex];
  const { asked, hint, entrySenses } = item;
  
  document.getElementById('test-progress').textContent = 
    `${currentTest.currentIndex + 1} / ${currentTest.items.length}`;
  
  if (asked) {
    document.getElementById('q-pos').textContent = asked.pos;
    document.getElementById('q-meaning').textContent = asked.meaning;
    document.getElementById('other-senses-input').style.display = 'block';
  } else {
    // 全部显示模式
    const allSenses = entrySenses.map(s => `${s.pos} ${s.meaning}`).join('  ');
    document.getElementById('q-pos').textContent = '';
    document.getElementById('q-meaning').textContent = allSenses;
    document.getElementById('other-senses-input').style.display = 'none';
  }
  
  document.getElementById('q-hint').textContent = hint || '（无提示）';
  document.getElementById('answer-spelling').value = '';
  document.getElementById('answer-other').value = '';
  document.getElementById('answer-spelling').focus();
  
  document.getElementById('feedback').style.display = 'none';
  document.querySelector('.question-card').style.display = 'block';
  
  // 扩展词（暂不实现）
  document.getElementById('ext-input').style.display = 'none';
  
  // 计时器
  if (currentTest.settings.timeLimit !== '0') {
    // TODO: 实现倒计时
  }
}

function submitAnswer() {
  if (!currentTest) return;
  
  const item = currentTest.items[currentTest.currentIndex];
  const spelling = document.getElementById('answer-spelling').value.trim().toLowerCase();
  const other = document.getElementById('answer-other').value.trim();
  
  // 判定拼写
  const spellingOk = spelling === item.word;
  
  // 判定其余释义
  let sensesOk = [];
  if (item.asked && other) {
    const otherSenses = parseOtherSenses(other);
    const remainingSenses = item.entrySenses.filter(s => 
      s.pos !== item.asked.pos || s.meaning !== item.asked.meaning
    );
    
    sensesOk = checkSenses(otherSenses, remainingSenses, currentTest.settings.matchMode);
  }
  
  // 判定是否错词
  let wrong = false;
  if (currentTest.settings.wrongRule === 'any') {
    wrong = !spellingOk || (item.asked && sensesOk.some(s => !s.ok));
  } else {
    wrong = !spellingOk;
  }
  
  item.answer = { spelling, other };
  item.result = { spellingOk, sensesOk, wrong };
  
  showFeedback();
}

function parseOtherSenses(text) {
  const lines = text.split(/[\n,，]/).map(l => l.trim()).filter(l => l);
  const senses = [];
  
  for (let line of lines) {
    const match = line.match(/^([\w&.]+)\s+(.+)$/);
    if (match) {
      senses.push({ pos: match[1], meaning: match[2] });
    }
  }
  
  return senses;
}

function checkSenses(userSenses, correctSenses, mode) {
  return correctSenses.map(correct => {
    const found = userSenses.find(u => 
      u.pos === correct.pos && (
        mode === 'loose' 
          ? u.meaning.includes(correct.meaning) || correct.meaning.includes(u.meaning)
          : u.meaning === correct.meaning
      )
    );
    return { ...correct, ok: !!found };
  });
}

function showFeedback() {
  const item = currentTest.items[currentTest.currentIndex];
  const { result, word, entrySenses } = item;
  
  document.querySelector('.question-card').style.display = 'none';
  document.getElementById('feedback').style.display = 'block';
  
  const resultDiv = document.querySelector('.feedback .result');
  resultDiv.textContent = result.wrong ? '✗ 错误' : '✓ 正确';
  resultDiv.className = result.wrong ? 'result wrong' : 'result correct';
  
  const correctDiv = document.querySelector('.feedback .correct-answer');
  correctDiv.innerHTML = `
    <strong>正确答案：</strong><br>
    <strong>拼写：</strong>${word} ${result.spellingOk ? '✓' : '✗'}<br>
    <strong>释义：</strong>${entrySenses.map(s => `${s.pos} ${s.meaning}`).join('; ')}
  `;
}

function nextQuestion() {
  currentTest.currentIndex++;
  
  if (currentTest.currentIndex >= currentTest.items.length) {
    finishTest();
  } else {
    renderQuestion();
  }
}

function finishTest() {
  currentTest.duration = Math.floor((Date.now() - currentTest.startTime) / 1000);
  
  const records = loadData(STORAGE_KEYS.RECORDS);
  records.unshift({
    ...currentTest,
    date: Date.now()
  });
  saveData(STORAGE_KEYS.RECORDS, records);
  
  currentTest = null;
  
  switchTab('results');
  renderRecords();
}

// ===== 结果展示 =====
function renderRecords() {
  const records = loadData(STORAGE_KEYS.RECORDS);
  const container = document.getElementById('records-list');
  const noRecords = document.getElementById('no-records');
  
  if (records.length === 0) {
    noRecords.style.display = 'block';
    container.innerHTML = '';
    return;
  }
  
  noRecords.style.display = 'none';
  container.innerHTML = records.map((record, idx) => {
    const correct = record.items.filter(i => !i.result.wrong).length;
    const total = record.items.length;
    const accuracy = Math.round((correct / total) * 100);
    
    return `
      <div class="record-card">
        <div class="record-header">
          <div class="stat">
            <span class="stat-value">${correct}/${total}</span>
            <span class="stat-label">全对单词</span>
          </div>
          <div class="stat">
            <span class="stat-value">${accuracy}%</span>
            <span class="stat-label">正确率</span>
          </div>
          <div class="stat">
            <span class="stat-value">${record.duration}s</span>
            <span class="stat-label">用时</span>
          </div>
        </div>
        
        <div class="record-meta">
          学生：${record.student} ｜ 词库：${record.libName} ｜ 
          ${new Date(record.date).toLocaleString('zh-CN')} ｜ 
          错词 ${total - correct} 个
        </div>
        
        <table class="result-table">
          <thead>
            <tr>
              <th>#</th>
              <th>单词</th>
              <th>提示</th>
              <th>拼写</th>
              <th>其余释义</th>
              <th>结果</th>
            </tr>
          </thead>
          <tbody>
            ${record.items.map((item, i) => `
              <tr class="${item.result.wrong ? 'wrong-word' : ''}">
                <td>${i + 1}</td>
                <td>${item.word}</td>
                <td>${item.hint || '—'}</td>
                <td>
                  ${item.answer.spelling} 
                  <span class="${item.result.spellingOk ? 'check-mark' : 'cross-mark'}">
                    ${item.result.spellingOk ? '✓' : '✗'}
                  </span>
                </td>
                <td>${item.answer.other || '—'}</td>
                <td>${item.result.wrong ? '错词' : '对'}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;
  }).join('');
}

// ===== 标签切换 =====
function switchTab(tab) {
  document.querySelectorAll('.tabs button').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
  
  document.querySelectorAll('.tab-content').forEach(section => {
    section.classList.remove('active');
  });
  
  const tabMap = {
    library: 'library-tab',
    test: 'test-tab',
    testing: 'testing-tab',
    results: 'results-tab'
  };
  
  document.getElementById(tabMap[tab]).classList.add('active');
}

// ===== 初始化 =====
document.addEventListener('DOMContentLoaded', () => {
  // 标签切换
  document.querySelectorAll('.tabs button').forEach(btn => {
    btn.addEventListener('click', () => {
      const tab = btn.dataset.tab;
      switchTab(tab);
      
      if (tab === 'results') {
        renderRecords();
      }
    });
  });
  
  // 解析词库
  document.getElementById('parse-btn').addEventListener('click', () => {
    const text = document.getElementById('lib-input').value.trim();
    const name = document.getElementById('lib-name').value.trim();
    
    if (!text) {
      alert('请粘贴单词表');
      return;
    }
    
    if (!name) {
      alert('请输入词库名称');
      return;
    }
    
    const entries = parseWordList(text);
    
    if (entries.length === 0) {
      alert('未解析到有效单词，请检查格式');
      return;
    }
    
    // 显示预览
    const preview = document.getElementById('parse-preview');
    const content = document.getElementById('preview-content');
    content.innerHTML = entries.map(e => 
      `<div class="preview-entry">
        <span class="preview-word">${e.word}</span>
        ${e.senses.map(s => `<span class="preview-sense">${s.pos} ${s.meaning}</span>`).join('')}
      </div>`
    ).join('');
    preview.style.display = 'block';
    
    // 添加到词库
    addLibrary(name, entries);
    
    alert(`成功导入 ${entries.length} 个单词`);
    document.getElementById('lib-input').value = '';
    document.getElementById('lib-name').value = '';
  });
  
  // 导出全部
  document.getElementById('export-all-txt').addEventListener('click', () => exportAllLibraries('txt'));
  document.getElementById('export-all-csv').addEventListener('click', () => exportAllLibraries('csv'));
  
  // 测试
  document.getElementById('test-all').addEventListener('change', (e) => {
    document.getElementById('test-count').disabled = e.target.checked;
    
    if (e.target.checked) {
      const libId = document.getElementById('test-lib').value;
      if (libId) {
        const libs = loadData(STORAGE_KEYS.LIBRARIES);
        const lib = libs.find(l => l.id === libId);
        if (lib) {
          document.getElementById('test-count').value = lib.count;
        }
      }
    }
  });
  
  document.getElementById('test-lib').addEventListener('change', (e) => {
    if (document.getElementById('test-all').checked) {
      const libs = loadData(STORAGE_KEYS.LIBRARIES);
      const lib = libs.find(l => l.id === e.target.value);
      if (lib) {
        document.getElementById('test-count').value = lib.count;
      }
    }
  });
  
  document.getElementById('start-test-btn').addEventListener('click', startTest);
  document.getElementById('submit-answer-btn').addEventListener('click', submitAnswer);
  document.getElementById('next-btn').addEventListener('click', nextQuestion);
  
  // 回车提交
  document.getElementById('answer-spelling').addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && !currentTest.settings.senseShow === 'random') {
      submitAnswer();
    }
  });
  
  // 初始化
  renderLibraries();
  updateTestLibrarySelect();
  loadSettings();
});
