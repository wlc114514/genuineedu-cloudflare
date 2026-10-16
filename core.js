(function (global) {
  'use strict';
  const POSITIONS = new Map([
    ['v','v'],['v.','v'],['动词','v'],['n','n'],['n.','n'],['名词','n'],['adj','adj'],['adj.','adj'],['形容词','adj'],['adv','adv'],['adv.','adv'],['副词','adv'],['prep','prep'],['prep.','prep'],['介词','prep'],['conj','conj'],['conj.','conj'],['连词','conj'],['pron','pron'],['pron.','pron'],['代词','pron'],['interj','interj'],['interj.','interj'],['感叹词','interj'],['v&n','v&n'],['v&n.','v&n'],['n&v','v&n'],['n&v.','v&n']
  ]);
  const isPos = v => POSITIONS.has(String(v || '').toLowerCase());
  const normalizePos = v => POSITIONS.get(String(v || '').toLowerCase()) || String(v || '');
  function parseWordList(text) {
    const words=[];
    for (const raw of String(text||'').split(/\r?\n/)) {
      const parts=raw.split(/[\t;]| {2,}/).map(s=>s.trim()).filter(Boolean); if(parts.length<2) continue;
      const senses=[]; let i=1;
      while(i<parts.length){ const pos=isPos(parts[i])?normalizePos(parts[i++]):''; const meanings=[]; while(i<parts.length&&!isPos(parts[i])) meanings.push(parts[i++]); if(meanings.length) senses.push({pos,meanings:meanings.join('；')}); }
      if(parts[0]&&senses.length) words.push({word:parts[0],senses});
    } return words;
  }
  function readJson(storage,key,fallback){try{const v=JSON.parse(storage.getItem(key));return v??fallback;}catch(_){return fallback;}}
  function escapeHtml(v){return String(v??'').replace(/[&<>\'"]/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[ch]));}
  function extractKeywords(t){return String(t||'').split(/[；，、;,\s]+/).map(s=>s.trim()).filter(s=>s.length>=2);}
  function meaningsMatch(word,meanings,config){if(!String(meanings||'').trim())return false;const exp=word.senses.flatMap(s=>s.meanings.split(/[；，、;]/).map(m=>m.trim().toLowerCase()));if(config.match==='loose')return extractKeywords(meanings).some(k=>exp.some(e=>e.includes(k)||k.includes(e)));const actual=String(meanings).replace(/[；，、]/g,';').toLowerCase();return exp.some(e=>actual.includes(e));}
  global.GenuineEduCore={isPos,normalizePos,parseWordList,readJson,escapeHtml,meaningsMatch,extractKeywords};
})(window);
