# Cloudflare Pages 部署指南

## 快速部署步骤

### 1. 推送到 GitHub

```bash
# 在项目目录下
git remote add origin https://github.com/你的用户名/genuineedu-web.git
git branch -M main
git push -u origin main
```

### 2. 连接 Cloudflare Pages

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 左侧菜单：**Workers & Pages** → **Create application** → **Pages** → **Connect to Git**
3. 授权 GitHub 并选择 `genuineedu-web` 仓库
4. 构建设置：
   - **Project name**: `genuineedu-web`（或自定义）
   - **Production branch**: `main`
   - **Framework preset**: `None`
   - **Build command**: 留空
   - **Build output directory**: `/`
5. 点击 **Save and Deploy**

### 3. 等待部署完成

- 首次部署约 1-2 分钟
- 部署成功后获得地址：`https://genuineedu-web.pages.dev`
- 可以绑定自定义域名（Cloudflare Pages 设置中配置）

## 更新部署

每次推送到 `main` 分支，Cloudflare Pages 会自动重新部署：

```bash
git add .
git commit -m "更新功能"
git push
```

## 自定义域名（可选）

1. Cloudflare Pages 项目页 → **Custom domains** → **Set up a custom domain**
2. 输入域名（如 `vocab.example.com`）
3. 按提示添加 DNS 记录（CNAME 指向 `genuineedu-web.pages.dev`）
4. 等待 SSL 证书自动配置完成

## 本地测试

```bash
python -m http.server 8080
# 访问 http://localhost:8080
```

## 费用

- Cloudflare Pages **完全免费**
- 免费额度：
  - 无限请求
  - 每月 500 次构建
  - 20,000 个文件，总大小 25 MB（本项目远低于此限制）

## 故障排查

### 部署失败

- 确认仓库中有 `index.html`、`style.css`、`app.js`
- 构建命令和输出目录留空或设为 `/`

### 页面空白

- 打开浏览器开发者工具（F12）查看 Console 错误
- 确认 localStorage 未被禁用

### 数据丢失

- localStorage 数据在清除浏览器缓存时会丢失
- 定期使用"导出全部"功能备份词库

## 技术支持

- Cloudflare Pages 文档：https://developers.cloudflare.com/pages/
- GitHub 帮助：https://docs.github.com/
