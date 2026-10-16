# GenuineEdu Web 重构说明

## 结构

- `index.html`：页面结构与资源入口
- `core.js`：前端纯函数核心（词表解析、释义匹配、安全存储读取、HTML 转义）
- `app.js`：页面状态、交互、测试流程和 JEV 客户端
- `files/jev_config.py`：JEV 后端统一配置（模型、端口、启动命令）
- `files/start_jev_server.py`：跨平台启动器
- `files/jev_style_decision_gguf.py`：JEV 概率判分实现
- `files/test_jev_config.py`、`tests_core.test.js`：核心回归测试

## 本地开发

```bash
npm test
python -m http.server 8080
```

网页数据仍保存在浏览器 `localStorage`，不会上传；JEV 只监听 `127.0.0.1:8001`。模型服务不可用时，前端继续使用文字匹配。
