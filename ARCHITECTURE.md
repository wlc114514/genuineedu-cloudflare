# 架构

## 前端

三层，越往下越纯：

| 文件 | 职责 | 能不能无头测 |
|---|---|---|
| `js/app.js` | DOM、事件委托、localStorage、对话框 | 用无头 Chrome（tests/browser.test.mjs） |
| `js/jev.js` | 本地服务客户端：探测、唤起、心跳、告别、判分、密钥轮换 | node（假 fetch） |
| `js/core.js` | 词表解析、出题、拼写/释义判定、`gradeAnswer`、JEV 概率 | node |

要点：

- 所有用户内容经 `escapeHtml` 输出；按钮用 `data-action` 事件委托，不拼 `onclick` 字符串。
- 「随机显示一个词性」模式只考**其余**词性（以前会把题面上的释义也算进去，抄题面就能对）。
- 判一道题：先文字匹配；拼写对但有词性没对上时，把学生写的每一项分别交给模型判「意思是否接近」（≥0.9 算对）。模型不可用 → 静默退回文字匹配。
- 旧数据（`libraries` / `testRecords`）读入时体检：坏条目丢弃，空释义占位清掉，格式保持兼容。
- 没装过服务的访客，页面**不会**去连 127.0.0.1（否则 Chrome 会给每个访客弹「访问本地网络」）。

## 本地判分服务

```
浏览器 ──jev://start──▶ 系统协议处理（Windows: launch.js / macOS: JEV.app / Linux: .desktop）
   │                              │
   │                              ▼
   │                         管家 agent（agent.ps1 / agent.pl），127.0.0.1:8002
   │                              │  选空闲端口、生成一次性密钥、拉起并看护 ▼
   ├── /ping /bye（每个标签页）──▶│        llama-server（127.0.0.1:8001，--api-key，--sleep-idle-seconds 300）
   └── /completion + X-Api-Key ─────────────────────────────▲
```

### 管家 HTTP 接口（127.0.0.1:8002，备用 18002 / 28002）

| 路径 | 作用 |
|---|---|
| `GET /ping?c=<标签页id>` | 心跳并返回状态 |
| `GET /status` | 只返回状态 |
| `POST /bye?c=<id>` | 标签页关闭（`navigator.sendBeacon`） |
| `GET /stop` | 停止 llama-server 并退出 |

状态：`{"app":"jev-agent","version":"2.0.0","state":"starting|ready|error","error":"","llama":{"url":"http://127.0.0.1:8001","key":"…"}}`

错误码：`model_missing`、`llama_missing`、`llama_exit`、`llama_start_failed`、`port_busy`、`startup_timeout`（网页对每个都有中文说明）。

### 生命周期

- 只由 `jev://` 唤起（用户点「开始测试」时），**不开机自启、不常驻**。
- 每个标签页各自心跳（20 秒一次）；某页 90 秒没心跳视为已关；最后一页告别后 10 秒退出；唤起后 120 秒都没有页面连上也退出。
- 刷新页面 = 旧页 bye + 新页 ping，不会误杀；开两个标签页关一个不影响另一个。
- 模型空闲 5 分钟由 llama-server 自己休眠（内存约 1GB → 200MB），下次请求 1~2 秒唤醒。

### 防呆

- 单实例（Windows 命名互斥量 / unix flock），重复唤起不会多开。
- 只结束**自己安装目录里**的 llama-server（按可执行文件路径匹配），绝不按端口杀进程；占着端口的别家程序不受影响，改用备用端口。
- 启动时清理崩溃遗留的 llama-server；`stop` 在管家不在时也能清。
- llama-server 带一次性 API 密钥，只有拿到管家下发密钥的网页能调用；管家按 Origin 白名单（`config.json`）拒绝陌生网站。
- 配置文件损坏 → 用默认值；模型/程序缺失 → 报告具体错误码而不是无声失败。
- 安装器：磁盘空间检查、SHA256 校验（损坏自动重下）、多镜像回退、断点续传（服务器不支持时从头下）、重复运行跳过已完成的步骤、清理旧版托盘脚本。
- Windows：从 PowerShell 7 里启动时继承的 `PSModulePath` 会让 5.1 的内置命令加载失败，脚本开头先复位；本机请求一律不走代理。
- 卸载只删安装器放进去的文件，目录里用户自己的东西保留。
