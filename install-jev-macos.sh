#!/bin/bash
# ============================================================
#  JEV 背词环境一键安装（macOS）
#  安装内容：llama-server + JEV 模型 + 背词工具脚本 + 启动器
# ============================================================

BASE="${JEV_TEST_DIR:-$HOME/Desktop/背词工具}"
FILES_BASE="${JEV_FILES_BASE:-https://genuineedu.pages.dev/files}"

echo "======================================================"
echo "          JEV 背词环境一键安装（macOS）"
echo "======================================================"
echo ""
echo "  安装位置：$BASE"
echo "  安装内容：llama-server、JEV 模型、背词工具脚本与启动器"
echo "  下载总量：约 520MB，具体用时取决于网速"
echo ""
echo "  下载中断不要紧，重新运行即可断点续传。"
echo "======================================================"
echo ""

mkdir -p "$BASE/jev/llama" || { echo "无法创建目录：$BASE"; exit 1; }

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  LLAMA_TAR="llama-b8944-bin-macos-arm64.tar.gz"
else
  LLAMA_TAR="llama-b8944-bin-macos-x64.tar.gz"
fi

LLAMA_DIR="$BASE/jev/llama"
TMP_TAR="${TMPDIR:-/tmp}/llama-b8944.tar.gz"

echo "[1/6] 准备 llama-server（$ARCH，约 8MB）..."
if [ -x "$LLAMA_DIR/llama-server" ]; then
  echo "  已存在，跳过"
else
  ok=0
  for u in \
    "https://gh-proxy.com/https://github.com/ggml-org/llama.cpp/releases/download/b8944/$LLAMA_TAR" \
    "https://ghproxy.net/https://github.com/ggml-org/llama.cpp/releases/download/b8944/$LLAMA_TAR" \
    "https://github.com/ggml-org/llama.cpp/releases/download/b8944/$LLAMA_TAR"
  do
    echo "  下载中：$u"
    if curl -L --fail --connect-timeout 20 -# -C - -o "$TMP_TAR" "$u"; then ok=1; break; fi
    echo "  当前源失败，尝试下一个..."
  done
  if [ "$ok" != "1" ]; then
    echo "  [错误] llama-server 下载失败。手动方案："
    echo "  1. 访问 https://github.com/ggml-org/llama.cpp/releases/tag/b8944"
    echo "  2. 下载 $LLAMA_TAR 并解压"
    echo "  3. 把解压目录里的 llama-server 及所有文件放到：$LLAMA_DIR"
    exit 1
  fi
  echo "  解压中..."
  tar -xzf "$TMP_TAR" -C "$LLAMA_DIR" --strip-components=1 && chmod +x "$LLAMA_DIR/llama-server"
  xattr -dr com.apple.quarantine "$LLAMA_DIR" 2>/dev/null
  rm -f "$TMP_TAR"
  if [ ! -x "$LLAMA_DIR/llama-server" ]; then
    echo "  [错误] 解压失败，请手动处理（见上方手动方案）。"
    exit 1
  fi
fi
echo ""

echo "[2/6] 下载 JEV 判分模型（约 505MB，请耐心等待）..."
MODEL="$BASE/jev/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
MSZ=$(stat -f%z "$MODEL" 2>/dev/null || echo 0)
if [ "$MSZ" -ge 528000000 ]; then
  echo "  模型已存在，跳过"
else
  ok=0
  for u in \
    "https://hf-mirror.com/chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF/resolve/main/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
  do
    echo "  下载中：能连上的镜像会持续输出进度"
    if curl -L --fail --connect-timeout 20 -# -C - -o "$MODEL" "$u"; then ok=1; break; fi
    echo "  镜像失败，5 秒后重试一次..."
    sleep 5
    if curl -L --fail --retry 5 --retry-delay 3 --connect-timeout 20 -# -C - -o "$MODEL" "$u"; then ok=1; break; fi
  done
  if [ "$ok" != "1" ]; then
    echo "  [错误] 模型下载失败。重新运行本脚本可断点续传。手动方案："
    echo "  1. 访问 https://hf-mirror.com/chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF"
    echo "  2. 下载 Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
    echo "  3. 放到：$MODEL"
    exit 1
  fi
  MSZ=$(stat -f%z "$MODEL")
  if [ "$MSZ" -lt 528000000 ]; then
    echo "  [错误] 模型不完整，请重新运行本脚本续传。"
    exit 1
  fi
fi
echo ""

echo "[3/6] 检查 Python 环境..."
if command -v python3 >/dev/null 2>&1; then
  echo "  已安装 $(python3 --version 2>&1)"
else
  echo "  [提示] 未找到 python3：请安装 Python 3，或运行 xcode-select --install"
  echo "         下载地址：https://www.python.org/downloads/"
fi
echo ""

echo "[4/6] 安装 Python 依赖（requests）..."
python3 -m pip install --user requests -q 2>/dev/null \
  || python3 -m pip install --user --break-system-packages requests -q 2>/dev/null \
  || echo "  [提示] requests 安装失败，可稍后手动安装：python3 -m pip install requests"
echo ""

echo "[5/6] 下载背词工具脚本..."
for f in dictation.py dictation_forms.py dictation_judge.json download_jev_from_mirror.py start_jev_server.py; do
  if curl -L --fail --connect-timeout 20 -s --retry 2 -o "$BASE/$f" "$FILES_BASE/$f"; then
    echo "  完成：$f"
  else
    echo "  [警告] $f 下载失败，可重新运行本脚本"
  fi
done
curl -L --fail --connect-timeout 20 -s --retry 2 -o "$BASE/jev/readout_config.json" "$FILES_BASE/readout_config.json" 2>/dev/null
curl -L --fail --connect-timeout 20 -s --retry 2 -o "$BASE/jev/jev_style_decision_gguf.py" "$FILES_BASE/jev_style_decision_gguf.py" 2>/dev/null
echo ""

echo "[6/6] 创建启动脚本..."
cat > "$BASE/启动判分服务.command" <<'EOS'
#!/bin/bash
cd "$(dirname "$0")"
echo ""
echo "JEV 判分服务启动中，服务地址 http://127.0.0.1:8001"
echo "请保持本窗口打开；按 Ctrl+C 停止服务。"
echo ""
python3 start_jev_server.py
echo ""
read -r -p "服务已停止。按回车键关闭..." _
EOS
chmod +x "$BASE/启动判分服务.command"

cat > "$BASE/单词默写.command" <<'EOS'
#!/bin/bash
cd "$(dirname "$0")"
python3 dictation.py
EOS
chmod +x "$BASE/单词默写.command"

cat > "$BASE/变形默写.command" <<'EOS'
#!/bin/bash
cd "$(dirname "$0")"
python3 dictation_forms.py
EOS
chmod +x "$BASE/变形默写.command"
echo "  完成"
echo ""

echo "======================================================"
echo "    安装完成！"
echo "======================================================"
echo ""
echo "  安装位置：$BASE"
echo ""
echo "  使用方法："
echo "    1. 在「访达」中打开 $BASE"
echo "    2. 双击「启动判分服务.command」启动判分服务（保持窗口打开）"
echo "    3. 双击「单词默写.command」开始默写；「变形默写.command」做变形默写"
echo ""
echo "  服务地址：http://127.0.0.1:8001"
echo "======================================================"
echo ""
read -r -p "按回车键关闭..." _
