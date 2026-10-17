# GenuineEdu · 单词拼写测试

纯静态网页（Cloudflare Pages），词库和成绩存在浏览器 localStorage。
可选的「智能判分」在用户自己的电脑上运行一个小模型（JEV），把「令人难堪的」这类近义写法判为「尴尬的」的正确答案。

## 用户怎么用

1. **词库**：粘贴单词表（Excel 直接复制 / Tab / 分号 / 空格都行），实时显示识别结果，保存。
2. **测试**：选词库和参数，开始。题面给一个词性的释义，写出单词和其余词性的释义；或者只考拼写。全程键盘 <kbd>Enter</kbd> 操作。
3. **记录**：正确率、用时、错词表；可以一键「重测错词」。

### 智能判分（可选）

右上角「智能判分」→ 按提示装一次：

- **Windows**：下载一个 .bat → 双击。不要管理员权限，不建桌面图标，「设置 → 应用」里可以卸载。
- **macOS / Linux**：终端里粘贴一行命令。

装好之后就不用管了：开始测试时网页通过 `jev://` 链接唤起服务，所有页面关掉约 10 秒后服务自己退出；空闲时模型自动休眠释放内存。不开机自启、不常驻。

### 词义联想（没装智能判分时）

没装智能判分、或者在 iPad / 手机这类装不了的设备上，释义用「词义联想」判：把两个中文释义按 CC-CEDICT 词典翻成英文关键词，
主要义项有交集就算近义（「令人难堪的」↔「尴尬的」都对应 awkward / embarrassed）。词表 `data/assoc.txt` 约 2.5MB，
只在需要判释义时下载。严格模式不联想。效果见 `node tests/assoc-eval.mjs`：在 268 对人工标注的释义上，
近义写法判对 72%（纯文字匹配 3%），错的判成对 4%；误判率超过 5% 时 `npm test` 会失败。

## 目录

```
index.html  style.css            页面
js/core.js                       纯逻辑：词表解析、出题、判分、JEV 概率计算（浏览器 + node 共用）
js/jev.js                        本地服务客户端（状态机，依赖注入，可无头测试）
js/app.js                        页面层：DOM、事件、存储
jev/windows/                     install.ps1 安装器 · agent.ps1 管家 · launch.js 协议处理 · uninstall.ps1
                                 install-jev.bat.tpl：网页按当前网址现场生成 .bat 的模板
jev/unix/                        install.sh 安装器（macOS / Linux）· agent.pl 管家
install-jev-windows.bat          由模板生成的静态版（旧链接 / 直链用），`node tools/build.mjs`
install-jev-macos.sh             旧链接兼容，转到 jev/unix/install.sh
tests/                           单元测试 + 管家 / 安装器 / 浏览器端到端测试
fonts/                           Andika 英文字体（SIL OFL）
data/assoc.txt                   词义联想词表，由 `npm run build:assoc -- <cedict_ts.u8>` 从 CC-CEDICT 生成（CC BY-SA 4.0）
files/                           桌面版背词工具脚本（与网页无关）
```

架构和本地服务协议见 [ARCHITECTURE.md](ARCHITECTURE.md)，部署见 [DEPLOY.md](DEPLOY.md)。

## 测试

```bash
npm test                                           # 单元测试（纯逻辑 + 服务客户端状态机）+ bat 模板同步检查
node tests/agent.test.mjs windows <测试安装目录>    # 管家端到端：真实 llama-server + 模型（34 项）
node tests/agent.test.mjs perl <测试安装目录>       # 同上，在 macOS / Linux 上跑 Perl 版管家
node tests/install-windows.test.mjs                # Windows 安装器端到端：本地模拟镜像、真实协议唤起、卸载
node tests/browser.test.mjs [测试安装目录]          # 无头 Chrome 跑完整用户流程；给了安装目录就连真实服务测智能判分
```

端到端测试用 38xxx 端口和 `jevtest://` 协议名，不会碰正式安装。GitHub Actions（`.github/workflows/jev-check.yml`）
在 macOS（Apple 芯片 + Intel）、Ubuntu、Windows 虚拟机上真实下载、安装、唤起并跑同一套管家测试。

本地预览：`npm run dev` → <http://localhost:8080>（localhost 在管家的白名单里，可以直接连本机服务调试）。
