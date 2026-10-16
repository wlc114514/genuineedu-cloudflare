# 部署（Cloudflare Pages）

纯静态，不需要构建命令。

## 方式一：连 GitHub 自动部署

Cloudflare Dashboard → Workers & Pages → Create → Pages → Connect to Git → 选本仓库：

- Framework preset：None
- Build command：留空
- Build output directory：`/`

之后每次 push 到 main 自动部署。`_headers` 会让 `/jev/` 下的脚本以 UTF-8 文本返回、不缓存。

## 方式二：wrangler 直传

```bash
npm run dist                                   # 只把网站文件拷到 dist/（不含 node_modules、测试缓存）
npx wrangler pages deploy dist --project-name genuineedu
```

不要直接 `wrangler pages deploy .`：仓库根目录里有 node_modules 和测试用的 500MB 模型缓存。

## 换域名时

安装器会记住「从哪个网站下载的」并把它加进本机服务的白名单，所以换域名后用户在新域名上重新运行一次安装器即可
（不会重复下载模型）。默认白名单：`https://genuineedu.pages.dev`、`https://*.genuineedu.pages.dev`（预览部署）、`localhost`。

静态的 `install-jev-windows.bat` 里写死的是 `https://genuineedu.pages.dev`；网页上点「下载安装器」时会按当前网址现场生成，不受影响。
改了 `jev/windows/install-jev.bat.tpl` 记得运行 `node tools/build.mjs`（`npm test` 会检查两者是否一致）。
