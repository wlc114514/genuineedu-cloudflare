# GenuineEdu Web - 单词拼写测试

纯静态网页版本，支持词库管理、测试、结果查看。

## 功能特性

- 📚 **词库管理**：导入、查看、导出词库
- 🎯 **灵活测试**：支持抽取数量、字母提示、释义匹配等多种配置
- 📋 **结果统计**：正确率、用时、错词详情
- 💾 **本地存储**：数据保存在浏览器 localStorage，不上传

## 部署方式

### Cloudflare Pages

1. 创建 GitHub 仓库并推送代码
2. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
3. Pages → Create a project → Connect to Git
4. 选择仓库，构建设置：
   - **Build command**: 留空
   - **Build output directory**: `/`
   - **Root directory**: `/`
5. Deploy

### 本地预览

```bash
python -m http.server 8080
# 访问 http://localhost:8080
```

## 使用流程

1. **词库页**：粘贴单词表（支持 Tab/空格/分号分隔）→ 解析并导入
2. **测试页**：选择词库 → 设置参数 → 开始测试
3. **答题**：根据释义和字母提示补全单词，填写其余释义
4. **结果页**：查看正确率、用时、错词列表

## 词表格式示例

```
mark	v&n.	标志、标记	n.	目标
blossom	v	开花	n	花朵
accurate	adj.	精确的
```

支持的格式：
- **分隔符**：Tab（Excel 直接复制）、多个空格、分号
- **词性**：v. / n. / adj. / 动词 / 名词 等
- **复合词性**：v&n / v.&n.
- **多个释义**：同一词性下用逗号/顿号分隔

## 技术栈

- 纯 HTML/CSS/JavaScript
- localStorage 本地存储
- 响应式设计，支持移动端

## 数据安全

所有数据保存在浏览器本地，不会上传到服务器。建议定期导出备份。

## License

MIT
