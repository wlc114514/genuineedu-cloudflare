// 从 CC-CEDICT 生成「词义联想」用的词表 data/assoc.txt：每行「中文词 英文关键词…」。
// 两个中文释义的英文关键词有交集，就认为意思相近（尴尬 → awkward embarrass；难堪 → embarrass awkward …）。
// 用法：node tools/build-assoc.mjs <cedict_ts.u8 路径> [--max-df 300]
// CC-CEDICT 采用 CC BY-SA 4.0，生成的 data/assoc.txt 也按此协议发布（见 data/ASSOC-LICENSE.txt）。
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const Core = createRequire(import.meta.url)('../js/core.js');
const src = process.argv[2];
if (!src) { console.error('用法：node tools/build-assoc.mjs <cedict_ts.u8>'); process.exit(1); }
const mdIdx = process.argv.indexOf('--max-df');
const MAX_DF = mdIdx > 0 ? Number(process.argv[mdIdx + 1]) : 300;
const kIdx = process.argv.indexOf('--keep');
const KEEP = kIdx > 0 ? Number(process.argv[kIdx + 1]) : 6;   // 每个词只留前几个关键词：排位靠后的几乎不影响判断（见 core.js 的 assocMatch）

// 不表达词义的义项：异体字、姓氏、量词说明、旧义、方言
const SKIP_GLOSS = /^(variant of|old variant|archaic variant|japanese variant|erhua variant|surname|see |see also|cl:|abbr\. for|used in|\(old\)|\(archaic\)|\(dialect\)|\(cantonese\)|\(tw\)|\(classical\)|\(onom\.\)|pr\.|also pr\.)/i;

const kw = new Map();   // 中文词 → Set<关键词>
for (const line of fs.readFileSync(src, 'utf8').split(/\r?\n/)) {
  if (!line || line[0] === '#') continue;
  const m = /^(\S+) (\S+) \[([^\]]*)\] \/(.*)\/\s*$/.exec(line);
  if (!m) continue;
  const [, , simp, pinyin, glossText] = m;
  if (!/^[一-鿿]{1,4}$/.test(simp)) continue;
  if (/(^|\s)[A-Z]/.test(pinyin)) continue;          // 专有名词：拼音首字母大写
  if (!kw.has(simp)) kw.set(simp, new Set());   // 没有可用关键词的词也留着：分词时要认得它（「成为」不能拆成「成」「为」）
  for (const g of glossText.split('/')) {
    if (!g || SKIP_GLOSS.test(g.trim())) continue;
    for (const k of Core.glossKeywords(g)) kw.get(simp).add(k);
  }
}

// 太常见的关键词（比如 make、person）几乎什么都能连上，去掉
const df = new Map();
for (const set of kw.values()) for (const k of set) df.set(k, (df.get(k) || 0) + 1);
const lines = [];
for (const [w, set] of kw) {
  const keep = [...set].filter(k => df.get(k) <= MAX_DF).slice(0, KEEP);
  lines.push(keep.length ? w + ' ' + keep.join(' ') : w);
}
lines.sort();
fs.mkdirSync(path.join(ROOT, 'data'), { recursive: true });
const out = path.join(ROOT, 'data', 'assoc.txt');
fs.writeFileSync(out, lines.join('\n') + '\n');
console.log(`${lines.length} 个词，${(fs.statSync(out).size / 1024 / 1024).toFixed(2)} MB → ${out}（max-df ${MAX_DF}）`);
