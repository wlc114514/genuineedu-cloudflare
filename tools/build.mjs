// 由模板生成静态的 install-jev-windows.bat（网页里点下载时会按当前网址现场生成，这个文件给直链/旧链接用）
// 用法：node tools/build.mjs        检查：node tools/build.mjs --check
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DEFAULT_ORIGIN = 'https://genuineedu.pages.dev';
const tpl = fs.readFileSync(path.join(ROOT, 'jev/windows/install-jev.bat.tpl'), 'utf8');
const out = tpl.replace(/__ORIGIN__/g, DEFAULT_ORIGIN).replace(/\r?\n/g, '\r\n');
const target = path.join(ROOT, 'install-jev-windows.bat');
if (!/^[\x00-\x7f]*$/.test(out)) throw new Error('bat 必须是纯 ASCII（cmd 会按 GBK 解析）');
// macOS 自带 bash 3.2：变量名后面紧跟中文时会把中文的字节读进变量名（"$ASSET）" → unbound variable），必须写 ${ASSET}
for (const f of ['jev/unix/install.sh', 'install-jev-macos.sh']) {
  fs.readFileSync(path.join(ROOT, f), 'utf8').split('\n').forEach((line, i) => {
    if (/\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7f]/.test(line)) {
      console.error(`${f}:${i + 1}: 变量后紧跟非 ASCII 字符，macOS 的 bash 3.2 会读错，请写成 \${VAR}\n  ${line.trim()}`);
      process.exitCode = 1;
    }
  });
}
if (process.argv.includes('--check')) {
  const cur = fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : '';
  if (cur !== out) { console.error('install-jev-windows.bat 与模板不一致，请运行 node tools/build.mjs'); process.exit(1); }
  console.log('install-jev-windows.bat 与模板一致');
} else {
  fs.writeFileSync(target, out);
  console.log('已生成 install-jev-windows.bat');
}

// node tools/build.mjs --dist [目录]：只拷网站需要的文件，给 wrangler pages deploy 直传用
const distIdx = process.argv.indexOf('--dist');
if (distIdx > 0) {
  const dist = path.resolve(process.argv[distIdx + 1] || path.join(ROOT, 'dist'));
  const SITE = ['index.html', 'style.css', '_headers', 'install-jev-windows.bat', 'install-jev-macos.sh', 'js', 'fonts', 'data', 'jev', 'files'];
  fs.rmSync(dist, { recursive: true, force: true });
  for (const item of SITE) fs.cpSync(path.join(ROOT, item), path.join(dist, item), { recursive: true });
  console.log('网站文件已输出到 ' + dist);
}
