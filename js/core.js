// 纯逻辑层：不碰 DOM / 网络 / localStorage，浏览器和 node 测试共用。
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.Core = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // ---------------- 词性 ----------------
  const POS_ALIASES = {
    v: ['v', 'vt', 'vi', '动词'],
    n: ['n', '名词'],
    adj: ['adj', '形容词'],
    adv: ['adv', '副词'],
    prep: ['prep', '介词'],
    conj: ['conj', '连词'],
    pron: ['pron', '代词'],
    num: ['num', '数词'],
    art: ['art', '冠词'],
    interj: ['interj', 'int', '感叹词'],
  };
  const POS_MAP = new Map();
  for (const [canon, list] of Object.entries(POS_ALIASES)) for (const a of list) POS_MAP.set(a, canon);

  // 「v.」「V」「v.&n.」「n&v」「动词」都能识别；复合词性归一为按出现顺序的 a&b
  function normalizePos(raw) {
    const s = String(raw ?? '').trim().toLowerCase();
    if (!s) return null;
    const parts = s.split(/[&/、]/).map(p => p.replace(/\.+$/, '').trim()).filter(Boolean);
    if (!parts.length) return null;
    const out = [];
    for (const p of parts) {
      const c = POS_MAP.get(p);
      if (!c) return null;
      if (!out.includes(c)) out.push(c);
    }
    return out.join('&');
  }
  const isPos = raw => normalizePos(raw) !== null;

  // 一个单元格可能是「v. 统一」这种词性+释义粘在一起的写法
  function splitLeadingPos(cell) {
    const m = /^([A-Za-z]{1,6}\.?(?:\s*[&/]\s*[A-Za-z]{1,6}\.?)*)\s*(.*)$/.exec(cell);
    if (m && m[2] && /[.&/]/.test(m[1]) && isPos(m[1].replace(/\s+/g, ''))) {
      return [m[1].replace(/\s+/g, ''), m[2].trim()];
    }
    return null;
  }

  // ---------------- 词表解析 ----------------
  // 每行：单词 + (词性 + 释义)+ ；分隔：Tab / 分号 / 两个以上空格；
  // 也接受「单词 v. 释义 n. 释义」这种单空格写法（词性带点）。
  function parseWordList(text) {
    const words = [];
    const errors = [];
    const lines = String(text ?? '').split(/\r?\n/);
    lines.forEach((raw, lineNo) => {
      const line = raw.replace(/ |　/g, ' ').trim();
      if (!line) return;
      let cells = line.split(/\t|;| {2,}/).map(s => s.trim()).filter(Boolean);
      // 单空格写法：第一个词性之前的都算单词（支持 give up v. 放弃）
      if (cells.length < 2) {
        const toks = line.split(/\s+/);
        let i = toks.findIndex((t, idx) => idx > 0 && (isPos(t) || splitLeadingPos(t)));
        if (i === -1) i = 1;
        cells = [toks.slice(0, i).join(' '), toks.slice(i).join(' ')].filter(Boolean);
      }
      if (cells.length < 2) { errors.push({ line: lineNo + 1, text: raw, reason: '缺少释义' }); return; }
      const word = cells[0];
      if (!/[A-Za-z]/.test(word)) { errors.push({ line: lineNo + 1, text: raw, reason: '第一列不是英文单词' }); return; }
      // 单元格里可能混着「v. 统一 n. 目标」或粘连的「v.（使）弯曲」：按空格拆开、认出词性，
      // 相邻的非词性片段再拼回去（保留「[daily routine 日常事务]」这类带空格的释义）
      const tokens = [];
      for (const cell of cells.slice(1)) {
        let text = [];
        const push = () => { if (text.length) tokens.push(text.join(' ')); text = []; };
        for (const sub of cell.split(/\s+/)) {
          const lead = isPos(sub) ? [sub, ''] : splitLeadingPos(sub);
          if (lead) { push(); tokens.push(lead[0]); if (lead[1]) text.push(lead[1]); }
          else text.push(sub);
        }
        push();
      }
      const senses = [];
      let pos = '';
      let buf = [];
      const flush = () => {
        const meanings = buf.join('；').trim();
        if (meanings) senses.push({ pos, meanings });
        buf = [];
      };
      for (const t of tokens) {
        const p = normalizePos(t);
        if (p) { flush(); pos = p; } else if (t) buf.push(t);
      }
      flush();
      if (!senses.length) { errors.push({ line: lineNo + 1, text: raw, reason: '没有可用的释义' }); return; }
      words.push({ word, senses });
    });
    return { words, errors };
  }

  // ---------------- 释义匹配 ----------------
  const MEANING_SEP = /[；;，,、/]+/;
  // 「n. (东西的）清单」「[daily routine 日常事务]」这类括号注释不参与匹配
  function cleanMeaning(s) {
    return String(s ?? '')
      .replace(/[（(][^）)]*[）)]/g, '')
      .replace(/[[【][^\]】]*[\]】]/g, '')
      .replace(/[\s.。…]+/g, '')
      .toLowerCase();
  }
  function splitMeanings(s) {
    return String(s ?? '').split(MEANING_SEP).map(cleanMeaning).filter(Boolean);
  }
  function hasContent(s) { return /[0-9A-Za-z一-鿿]/.test(String(s ?? '')); }

  // 宽松：任一方包含另一方（≥2 个字才算数，避免「的」之类误中）
  // 严格：学生写的某一项与标准释义某一项完全一致
  function senseMatched(sense, answerParts, mode) {
    const expected = splitMeanings(sense.meanings);
    if (!expected.length) return true;
    return answerParts.some(a => expected.some(e => {
      if (mode === 'strict') return a === e;
      if (a === e) return true;
      const short = a.length <= e.length ? a : e;
      return short.length >= 2 && (e.includes(a) || a.includes(e));
    }));
  }

  // 返回每个「需要写的词性」是否答出
  function gradeMeanings(senses, answer, mode) {
    const parts = splitMeanings(answer);
    return senses.map(s => ({ sense: s, ok: senseMatched(s, parts, mode) }));
  }

  // ---------------- 出题 ----------------
  function shuffle(arr, rand = Math.random) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(rand() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  function clampInt(v, min, max, fallback) {
    const n = Math.floor(Number(v));
    if (!Number.isFinite(n)) return fallback;
    return Math.min(max, Math.max(min, n));
  }

  // display: 'random' → 随机亮出一个词性，学生写其余词性；'all' → 全部亮出，只考拼写
  function buildQuestions(words, opts, rand = Math.random) {
    const picked = shuffle(words, rand);
    const n = opts.all ? picked.length : clampInt(opts.count, 1, picked.length, picked.length);
    return picked.slice(0, n).map(w => {
      if (opts.display === 'all') return { word: w.word, senses: w.senses, shown: w.senses, ask: [] };
      const k = Math.floor(rand() * w.senses.length);
      return { word: w.word, senses: w.senses, shown: [w.senses[k]], ask: w.senses.filter((_, i) => i !== k) };
    });
  }

  function generateHint(word, strategy) {
    const w = String(word);
    if (strategy === 'none') return '';
    const chars = [...w];
    let show;
    if (strategy === 'first') show = 1;
    else show = Math.floor(chars.filter(c => /[A-Za-z]/.test(c)).length / 2);
    let shown = 0;
    return chars.map(c => {
      if (!/[A-Za-z]/.test(c)) return c;          // 空格、连字符、撇号原样给出
      if (shown < show) { shown++; return c; }
      return '_';
    }).join('');
  }

  function normalizeSpelling(s) {
    return String(s ?? '').trim().toLowerCase().replace(/[‘’`´]/g, "'").replace(/\s+/g, ' ');
  }
  const spellingCorrect = (input, word) => normalizeSpelling(input) === normalizeSpelling(word) && normalizeSpelling(word) !== '';

  // ---------------- 本地判分模型（JEV） ----------------
  const JEV = Object.freeze({
    TEMPERATURE: 0.8800546821789332,
    TOKEN_YES: 9542,
    TOKEN_NO: 874,
    THRESHOLD: 0.9,
  });
  function jevPrompt(meaning, answer, k) {
    const opts = ['一致: 意思相同或非常接近', '不一致: 意思不同或无关'];
    const head = 'State:\n标准释义：' + meaning + '\n学生写的释义：' + answer + '\n\n'
      + 'Question [choice]: 学生写的释义与标准释义表达的意思是否一致？\nOptions:\n'
      + opts.map(o => '- ' + o + '\n').join('') + 'Judge each option:\n';
    let tail = opts[k] + ' ->';
    if (k) tail = opts[0] + ' ->\n' + tail;
    return head + tail;
  }
  // 从 llama-server /completion 的返回里取 yes-no 的对数概率差
  function jevMargin(completion) {
    const cp = (completion && completion.completion_probabilities || [])[0] || {};
    const lp = {};
    for (const e of (cp.top_logprobs || [])) lp[e.id] = e.logprob;
    if (!(JEV.TOKEN_YES in lp) || !(JEV.TOKEN_NO in lp)) return null;
    return lp[JEV.TOKEN_YES] - lp[JEV.TOKEN_NO];
  }
  function jevProbability(d0, d1) {
    const z = Math.max(-30, Math.min(30, (d0 - d1) / JEV.TEMPERATURE));
    return 1 / (1 + Math.exp(-z));
  }

  // ---------------- 词义联想（不装模型时用） ----------------
  // 词表来自 CC-CEDICT：中文词 → 英文释义里的关键词。两个中文释义的关键词有交集，就算意思相近。
  const GLOSS_STOP = new Set(('to a an the of be is are was one one\'s oneself sb sth someone something somebody and or in on at for with by from '
    + 'as into up out off about over very etc also used use make made cause get become have has give take put do thing person people way kind type '
    + 'sort state quality act particular certain more most much many not no non lit fig esp usu abbr var old word character term form bound place '
    + 'time this that its his her their who which what all any some other each than too can may will would should being been it them they you '
    + 'he she we us our your my me i such so just only like even still yet there here when where how why else less own same').split(' '));
  function stem(w) {
    if (w.length <= 4) return w;
    w = w.replace(/(?:ness|ment|ments|fully|ful|ly)$/, '') || w;
    if (/ies$/.test(w)) w = w.slice(0, -3) + 'y';
    else if (/ied$/.test(w)) w = w.slice(0, -3) + 'y';
    else if (/ing$/.test(w) && w.length > 5) w = w.slice(0, -3);
    else if (/ed$/.test(w) && w.length > 4) w = w.slice(0, -2);
    else if (/[^s]s$/.test(w)) w = w.slice(0, -1);
    if (/([b-df-hj-np-tv-z])\1$/.test(w) && !/(ss|ll)$/.test(w)) w = w.slice(0, -1);   // running → runn → run
    return w.replace(/e$/, '').replace(/i$/, 'y');                                      // unified → unifi → unify；embarrass
  }
  function glossKeywords(gloss) {
    const g = String(gloss).toLowerCase().replace(/\([^)]*\)/g, ' ');
    const out = new Set();
    for (const t of g.split(/[^a-z']+/)) {
      if (t.length < 3 || GLOSS_STOP.has(t)) continue;
      const s = stem(t.replace(/'s$/, ''));
      if (s.length >= 3 && !GLOSS_STOP.has(s)) out.add(s);
    }
    return [...out];
  }
  function parseAssoc(text) {
    const map = new Map();
    for (const line of String(text).split(/\r?\n/)) {
      if (!line) continue;
      const i = line.indexOf(' ');
      if (i < 0) map.set(line, []); else map.set(line.slice(0, i), line.slice(i + 1).split(' '));
    }
    return map;
  }
  // 只起语法作用的字词：「令人难堪的」「使一致」「有名的」里真正表义的是后面那部分
  const FUNCTION_SEGS = new Set(['的', '地', '得', '了', '着', '过', '使', '令', '令人', '让', '被', '把', '将', '之', '于', '很', '非常', '十分', '有', '一', '个', '种', '些', '某', '所', '是', '在', '者']);
  // 正向最大匹配分词，取实词的关键词。单字义项太杂（「成」有十几个意思），
  // 只有整条释义里没有多字词时（「饿的」「买」）才用单字
  function assocKeywords(dict, text) {
    const s = cleanMeaning(text).replace(/[^一-鿿]/g, '');
    const segs = [];
    for (let i = 0; i < s.length;) {
      let len = Math.min(4, s.length - i);
      while (len > 1 && !dict.has(s.slice(i, i + len))) len--;
      const seg = s.slice(i, i + len);
      if (!FUNCTION_SEGS.has(seg)) segs.push(seg);
      i += len;
    }
    const multi = segs.filter(x => x.length > 1);
    const out = new Set();
    for (const seg of multi.length ? multi : segs) for (const k of dict.get(seg) || []) out.add(k);
    return out;
  }
  // CC-CEDICT 的义项大致按常用程度排序：只共用一个靠后的义项（主要 main/principal/major 与 重要 important/significant/major）
  // 不算数。共用关键词在两边的排位 i、j（从 1 起）给分 1/√(i·j)，最高分够 MIN_RANK_SCORE，或者共用两个以上，才算意思相近。
  // 阈值在 tests/fixtures/assoc-eval.json 上调定，见 tests/assoc-eval.mjs
  const ASSOC = Object.freeze({ MIN_RANK_SCORE: 0.6, MIN_SHARED: 2 });
  // 返回 {ok, shared}；dict 为空时返回 null（词表没加载，退回文字匹配）
  function assocMatch(dict, expected, answer, opts = ASSOC) {
    if (!dict || !dict.size) return null;
    const a = [...assocKeywords(dict, expected)], b = [...assocKeywords(dict, answer)];
    const shared = [];
    let best = 0;
    a.forEach((k, i) => {
      const j = b.indexOf(k);
      if (j < 0) return;
      shared.push(k);
      best = Math.max(best, 1 / Math.sqrt((i + 1) * (j + 1)));
    });
    return { ok: shared.length >= opts.MIN_SHARED || best >= opts.MIN_RANK_SCORE, shared };
  }

  // ---------------- 判一道题 ----------------
  // judge(标准释义, 学生写的一项) → Promise<p|null>；null 表示模型不可用
  // assoc(标准释义, 学生写的一项) → {ok, shared}|null：词义联想，模型不可用时代替它；null 表示词表没加载，只用文字匹配
  async function gradeAnswer(q, input, config, judge, assoc) {
    const spellOk = spellingCorrect(input.spelling, q.word);
    const needMeaning = config.criteria === 'any' && q.ask.length > 0;
    const senses = needMeaning
      ? gradeMeanings(q.ask, input.meanings, config.match).map(r => ({ sense: r.sense, ok: r.ok, via: r.ok ? 'text' : null }))
      : [];
    const pieces = String(input.meanings).split(MEANING_SEP).map(s => s.trim()).filter(hasContent).slice(0, 6);
    let modelAnswered = false;
    // 拼写对了但有释义没对上：让本地模型判断「意思是否接近」
    if (judge && spellOk && senses.some(s => !s.ok) && pieces.length) {
      outer:
      for (const s of senses) {
        if (s.ok) continue;
        for (const piece of pieces) {
          let p = null;
          try { p = await judge(s.sense.meanings, piece); } catch (_) { p = null; }
          if (p === null) break outer;
          modelAnswered = true;
          if (p >= JEV.THRESHOLD) { Object.assign(s, { ok: true, via: 'jev', p, piece }); break; }
        }
      }
    }
    // 模型没装或没响应：用词义联想。模型给过结论就以模型为准；严格模式只认原文
    if (assoc && !modelAnswered && config.match !== 'strict') {
      for (const s of senses) {
        if (s.ok) continue;
        for (const piece of pieces) {
          const r = assoc(s.sense.meanings, piece);
          if (r && r.ok) { Object.assign(s, { ok: true, via: 'assoc', piece, shared: r.shared }); break; }
        }
      }
    }
    return { spellOk, senses, correct: spellOk && senses.every(s => s.ok) };
  }

  // ---------------- 杂项 ----------------
  function escapeHtml(v) {
    return String(v ?? '').replace(/[&<>'"]/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[ch]));
  }
  function readJson(storage, key, fallback) {
    try {
      const v = JSON.parse(storage.getItem(key));
      return v ?? fallback;
    } catch (_) { return fallback; }
  }
  function csvCell(v) {
    const s = String(v ?? '');
    return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  }
  function formatDuration(sec) {
    sec = Math.max(0, Math.round(sec || 0));
    return Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0');
  }
  function formatSenses(senses) {
    return senses.map(s => (s.pos ? s.pos + '. ' : '') + s.meanings);
  }

  // 旧版本把词库存成 {name: {name, words, createdAt, count}}，这里做一次体检，坏条目直接丢弃
  function sanitizeLibraries(obj) {
    const out = {};
    if (!obj || typeof obj !== 'object') return out;
    for (const [key, lib] of Object.entries(obj)) {
      if (!lib || !Array.isArray(lib.words)) continue;
      const words = lib.words.filter(w => w && typeof w.word === 'string' && Array.isArray(w.senses))
        .map(w => ({ word: w.word, senses: w.senses.filter(s => s && hasContent(s.meanings)).map(s => ({ pos: String(s.pos || ''), meanings: String(s.meanings) })) }))
        .filter(w => w.senses.length);
      if (!words.length) continue;
      const name = String(lib.name || key);
      out[name] = { name, words, createdAt: lib.createdAt || new Date(0).toISOString(), count: words.length };
    }
    return out;
  }
  function sanitizeRecords(arr) {
    return Array.isArray(arr) ? arr.filter(r => r && typeof r === 'object' && Number.isFinite(r.total)) : [];
  }

  return {
    normalizePos, isPos, parseWordList,
    cleanMeaning, splitMeanings, hasContent, gradeMeanings,
    shuffle, clampInt, buildQuestions, generateHint, normalizeSpelling, spellingCorrect,
    JEV, jevPrompt, jevMargin, jevProbability, gradeAnswer,
    ASSOC, glossKeywords, parseAssoc, assocKeywords, assocMatch,
    escapeHtml, readJson, csvCell, formatDuration, formatSenses,
    sanitizeLibraries, sanitizeRecords,
  };
});
