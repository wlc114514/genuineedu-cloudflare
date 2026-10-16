// 诊断：直接对一个 llama-server 跑判分，打印原始 logprob 与概率
// 用法：node tests/judge-probe.mjs <url> [apiKey]
import { createRequire } from 'node:module';
const Core = createRequire(import.meta.url)('../js/core.js');
const [url, key] = process.argv.slice(2);
for (const [m, a] of [['尴尬的', '令人难堪的'], ['统一', '使一致'], ['工资', '火焰'], ['尴尬的', '高兴的']]) {
  const ds = [];
  for (const k of [0, 1]) {
    const r = await fetch(url + '/completion', { method: 'POST', headers: { 'Content-Type': 'application/json', ...(key ? { 'X-Api-Key': key } : {}) },
      body: JSON.stringify({ prompt: Core.jevPrompt(m, a, k), n_predict: 1, temperature: 0, n_probs: 32, cache_prompt: false }) });
    const out = await r.json();
    const top = (out.completion_probabilities?.[0]?.top_logprobs || []).slice(0, 4).map(e => `${e.id}:${e.token}:${e.logprob.toFixed(3)}`).join(' ');
    console.log(`  ${m}|${a} k=${k} content=${JSON.stringify(out.content)} top=${top}`);
    ds.push(Core.jevMargin(out));
  }
  console.log(`${m} | ${a} → p=${ds.includes(null) ? 'null' : Core.jevProbability(ds[0], ds[1]).toFixed(4)}`);
}
