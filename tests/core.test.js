// node --test tests/
const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../js/core.js');

test('词表解析：各种分隔写法', () => {
  const { words, errors } = C.parseWordList([
    'mark\tv&n.\t标志、标记\tn.\t目标',
    'blossom  v  开花  n  花朵',
    'unify v. 统一',
    'plus conj. 加 adv. 此外',
    'routine n. 常规 [daily routine 日常事务]',
    'bend v.（使）弯曲',
    'draft v.&n. 征兵',
    'give up v. 放弃',
    'apple 苹果',
    'unify2 动词 统一',
    'accurate;adj.;精确的',
    '',
    '中文 abc',
    'onlyword',
  ].join('\r\n'));
  const by = Object.fromEntries(words.map(w => [w.word, w.senses]));
  assert.deepEqual(by.mark, [{ pos: 'v&n', meanings: '标志、标记' }, { pos: 'n', meanings: '目标' }]);
  assert.deepEqual(by.blossom, [{ pos: 'v', meanings: '开花' }, { pos: 'n', meanings: '花朵' }]);
  assert.deepEqual(by.plus, [{ pos: 'conj', meanings: '加' }, { pos: 'adv', meanings: '此外' }]);
  assert.equal(by.routine[0].meanings, '常规 [daily routine 日常事务]');
  assert.deepEqual(by.bend, [{ pos: 'v', meanings: '（使）弯曲' }]);
  assert.equal(by.draft[0].pos, 'v&n');
  assert.deepEqual(by['give up'], [{ pos: 'v', meanings: '放弃' }]);
  assert.deepEqual(by.apple, [{ pos: '', meanings: '苹果' }]);
  assert.equal(by.unify2[0].pos, 'v');
  assert.deepEqual(by.accurate, [{ pos: 'adj', meanings: '精确的' }]);
  assert.deepEqual(errors.map(e => e.line), [13, 14]);
});

test('词性归一', () => {
  assert.equal(C.normalizePos('V.'), 'v');
  assert.equal(C.normalizePos('vt.'), 'v');
  assert.equal(C.normalizePos('n&v'), 'n&v');
  assert.equal(C.normalizePos('adj.&n.'), 'adj&n');
  assert.equal(C.normalizePos('形容词'), 'adj');
  assert.equal(C.normalizePos('e.g.'), null);
  assert.equal(C.normalizePos('a'), null);   // 不把冠词 a 当成形容词
});

test('释义匹配：宽松 / 严格 / 括号注释', () => {
  const senses = [{ pos: 'n', meanings: '票据；议案' }, { pos: 'n', meanings: '(东西的）清单、财产目录' }];
  let r = C.gradeMeanings(senses, '议案，清单', 'loose');
  assert.deepEqual(r.map(x => x.ok), [true, true]);
  r = C.gradeMeanings(senses, '票', 'loose');
  assert.deepEqual(r.map(x => x.ok), [false, false], '单字不算命中');
  r = C.gradeMeanings(senses, '财产目录表', 'loose');
  assert.equal(r[1].ok, true, '宽松：包含即可');
  r = C.gradeMeanings(senses, '财产目录表', 'strict');
  assert.equal(r[1].ok, false, '严格：必须一致');
  r = C.gradeMeanings(senses, '清单', 'strict');
  assert.equal(r[1].ok, true, '括号注释不参与比较');
  r = C.gradeMeanings([{ pos: 'v', meanings: '娱乐、考虑（一个想法或建议）' }], '考虑', 'strict');
  assert.equal(r[0].ok, true);
});

test('出题：随机词性模式只考「其余」词性（不能抄题面）', () => {
  const words = [{ word: 'bill', senses: [{ pos: 'n', meanings: '票据' }, { pos: 'n', meanings: '议案' }, { pos: 'v', meanings: '开账单' }] }];
  const qs = C.buildQuestions(words, { all: true, display: 'random' }, () => 0);
  assert.equal(qs[0].shown.length, 1);
  assert.equal(qs[0].ask.length, 2);
  assert.ok(!qs[0].ask.includes(qs[0].shown[0]));
  const all = C.buildQuestions(words, { all: true, display: 'all' });
  assert.equal(all[0].ask.length, 0);
  assert.equal(all[0].shown.length, 3);
});

test('出题：数量裁剪与非法输入', () => {
  const words = Array.from({ length: 30 }, (_, i) => ({ word: 'w' + i, senses: [{ pos: 'n', meanings: 'x' + i }] }));
  assert.equal(C.buildQuestions(words, { count: 10, display: 'all' }).length, 10);
  assert.equal(C.buildQuestions(words, { count: 999, display: 'all' }).length, 30);
  assert.equal(C.buildQuestions(words, { count: 'abc', display: 'all' }).length, 30);
  assert.equal(C.buildQuestions(words, { count: -5, display: 'all' }).length, 1);
  assert.equal(new Set(C.buildQuestions(words, { all: true, display: 'all' }).map(q => q.word)).size, 30, '不重复');
});

test('拼写提示', () => {
  assert.equal(C.generateHint('receptionist', 'auto'), 'recept______');
  assert.equal(C.generateHint('give up', 'auto'), 'giv_ __');
  assert.equal(C.generateHint("o'clock", 'first'), "o'_____");
  assert.equal(C.generateHint('apple', 'none'), '');
});

test('拼写判定：大小写、空格、弯引号', () => {
  assert.ok(C.spellingCorrect('  Apple ', 'apple'));
  assert.ok(C.spellingCorrect('give  up', 'give up'));
  assert.ok(C.spellingCorrect('o’clock', "o'clock"));
  assert.ok(!C.spellingCorrect('', ''));
  assert.ok(!C.spellingCorrect('aple', 'apple'));
});

test('判一道题：文字先判，判不出再问模型', async () => {
  const q = { word: 'awkward', ask: [{ pos: 'adj', meanings: '尴尬的' }], shown: [], senses: [] };
  const cfg = { criteria: 'any', match: 'loose' };
  const calls = [];
  const judge = async (m, a) => { calls.push([m, a]); return a === '令人难堪的' ? 0.97 : 0.02; };

  let r = await C.gradeAnswer(q, { spelling: 'awkward', meanings: '尴尬的' }, cfg, judge);
  assert.ok(r.correct); assert.equal(calls.length, 0, '文字能判就不调模型');

  r = await C.gradeAnswer(q, { spelling: 'awkward', meanings: '高兴的，令人难堪的' }, cfg, judge);
  assert.ok(r.correct); assert.equal(r.senses[0].via, 'jev'); assert.equal(r.senses[0].piece, '令人难堪的');

  calls.length = 0;
  r = await C.gradeAnswer(q, { spelling: 'awkwrd', meanings: '令人难堪的' }, cfg, judge);
  assert.ok(!r.correct); assert.equal(calls.length, 0, '拼写错就不必问模型');

  r = await C.gradeAnswer(q, { spelling: 'awkward', meanings: '令人难堪的' }, cfg, async () => null);
  assert.ok(!r.correct, '模型不可用 → 退回文字匹配');

  r = await C.gradeAnswer(q, { spelling: 'awkward', meanings: '令人难堪的' }, cfg, async () => { throw new Error('boom'); });
  assert.ok(!r.correct, '模型报错也不会让判分崩掉');

  r = await C.gradeAnswer(q, { spelling: 'awkward', meanings: '' }, { criteria: 'spelling', match: 'loose' }, judge);
  assert.ok(r.correct, '只看拼写');
});

test('JEV 概率计算与返回解析', () => {
  const out = { completion_probabilities: [{ top_logprobs: [{ id: 9542, logprob: -0.1 }, { id: 874, logprob: -3 }] }] };
  assert.ok(Math.abs(C.jevMargin(out) - 2.9) < 1e-9);
  assert.equal(C.jevMargin({}), null);
  assert.equal(C.jevMargin({ completion_probabilities: [{ top_logprobs: [{ id: 9542, logprob: -1 }] }] }), null);
  assert.ok(C.jevProbability(5, -5) > 0.99);
  assert.ok(C.jevProbability(-5, 5) < 0.01);
  assert.equal(C.jevProbability(1e9, -1e9), 1 / (1 + Math.exp(-30)), '极端值被截断，不会 NaN');
  assert.ok(C.jevPrompt('尴尬的', '令人难堪的', 1).endsWith('一致: 意思相同或非常接近 ->\n不一致: 意思不同或无关 ->'));
});

test('防 XSS 与 CSV 转义', () => {
  assert.equal(C.escapeHtml('<img src=x onerror="a">\''), '&lt;img src=x onerror=&quot;a&quot;&gt;&#39;');
  assert.equal(C.csvCell('a,"b"'), '"a,""b"""');
  assert.equal(C.csvCell('plain'), 'plain');
});

test('旧数据体检：坏条目丢弃、空释义清掉', () => {
  const libs = C.sanitizeLibraries({
    good: { name: 'good', words: [{ word: 'a1', senses: [{ pos: '', meanings: '' }, { pos: 'n', meanings: '一' }] }], createdAt: '2026-01-01' },
    empty: { name: 'empty', words: [{ word: 'x', senses: [{ pos: '', meanings: ' ' }] }] },
    broken: 'nope',
    nowords: { name: 'nowords' },
  });
  assert.deepEqual(Object.keys(libs), ['good']);
  assert.deepEqual(libs.good.words[0].senses, [{ pos: 'n', meanings: '一' }]);
  assert.equal(libs.good.count, 1);
  assert.deepEqual(C.sanitizeLibraries(null), {});
  assert.deepEqual(C.sanitizeRecords([{ total: 3 }, null, 'x', { total: 'a' }]), [{ total: 3 }]);
  const storage = { getItem: () => '{bad json' };
  assert.deepEqual(C.readJson(storage, 'k', { d: 1 }), { d: 1 });
});
