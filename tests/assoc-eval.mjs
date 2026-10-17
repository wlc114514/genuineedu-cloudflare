// 词义联想评测：和纯文字匹配比，算召回率（近义写法判对的比例）和误判率（错的判成对的比例）。
// 用法：node tests/assoc-eval.mjs [--grid] [--errors]
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const Core = createRequire(import.meta.url)('../js/core.js');
const dict = Core.parseAssoc(fs.readFileSync(path.join(ROOT, 'data', 'assoc.txt'), 'utf8'));
const { pairs } = JSON.parse(fs.readFileSync(path.join(ROOT, 'tests', 'fixtures', 'assoc-eval.json'), 'utf8'));

const literal = (e, a) => Core.gradeMeanings([{ pos: '', meanings: e }], a, 'loose')[0].ok;
function evaluate(judge) {
  let tp = 0, fn = 0, fp = 0, tn = 0;
  const errors = [];
  for (const [e, a, want] of pairs) {
    const got = judge(e, a);
    if (want && got) tp++; else if (want) { fn++; errors.push(['漏判', e, a]); }
    else if (got) { fp++; errors.push(['误判', e, a]); } else tn++;
  }
  return { recall: tp / (tp + fn), fpr: fp / (fp + tn), tp, fn, fp, tn, errors };
}
const fmt = r => `召回 ${(r.recall * 100).toFixed(1)}%（${r.tp}/${r.tp + r.fn}）  误判 ${(r.fpr * 100).toFixed(1)}%（${r.fp}/${r.fp + r.tn}）`;

console.log(`评测集：${pairs.filter(p => p[2]).length} 个正例，${pairs.filter(p => !p[2]).length} 个反例；词表 ${dict.size} 词`);
console.log('纯文字匹配      ' + fmt(evaluate(literal)));
const assoc = opts => (e, a) => literal(e, a) || Core.assocMatch(dict, e, a, opts).ok;
const best = evaluate(assoc(Core.ASSOC));
console.log('文字 + 词义联想 ' + fmt(best) + `   （MIN_RANK_SCORE ${Core.ASSOC.MIN_RANK_SCORE}，MIN_SHARED ${Core.ASSOC.MIN_SHARED}）`);

// 调阈值时只看偶数条，奇数条留出来检验，避免只是把评测集背下来
if (process.argv.includes('--grid')) {
  const all = pairs.splice(0);
  const tune = all.filter((_, i) => i % 2 === 0), hold = all.filter((_, i) => i % 2 === 1);
  for (const MIN_RANK_SCORE of [0.35, 0.5, 0.6, 0.71, 1.01]) for (const MIN_SHARED of [2, 99]) {
    const opts = { MIN_RANK_SCORE, MIN_SHARED };
    pairs.push(...tune); const t = evaluate(assoc(opts)); pairs.splice(0);
    pairs.push(...hold); const ho = evaluate(assoc(opts)); pairs.splice(0);
    console.log(`  分数≥${MIN_RANK_SCORE} 共用≥${MIN_SHARED}：调参集 ${fmt(t)} | 留出集 ${fmt(ho)}`);
  }
  pairs.push(...all);
}
if (process.argv.includes('--errors')) {
  for (const [kind, e, a] of best.errors) {
    const r = Core.assocMatch(dict, e, a);
    console.log(`  ${kind} ${e} / ${a}  共同关键词：${r.shared.join(' ') || '无'}  | ${[...Core.assocKeywords(dict, e)].join(' ')} || ${[...Core.assocKeywords(dict, a)].join(' ')}`);
  }
}
// 作为检查用：误判率超过 5% 就算不合格
if (best.fpr > 0.05) { console.error('误判率超过 5%，不应启用词义联想'); process.exitCode = 1; }
