#!/bin/bash
# ============================================================
#  JEV 本地判分服务一键安装（macOS）
#  为网页版背词工具提供本地释义判分（llama-server + JEV 模型）
# ============================================================

BASE="${JEV_TEST_DIR:-$HOME/Library/Application Support/JEV}"

echo "======================================================"
echo "        JEV 本地判分服务一键安装（macOS）"
echo "======================================================"
echo ""
echo "  安装位置：$BASE"
echo "  安装内容：llama-server + JEV 判分模型（约 520MB）"
echo ""
echo "  装好后双击「启动判分服务.command」启动，"
echo "  网页版默写时的释义判分会自动使用它。"
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

echo "[1/4] 准备 llama-server（$ARCH，约 8MB）..."
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

echo "[2/4] 下载 JEV 判分模型（约 505MB，请耐心等待）..."
MODEL="$BASE/jev/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
MSZ=$(stat -f%z "$MODEL" 2>/dev/null || echo 0)
if [ "$MSZ" -ge 528000000 ]; then
  echo "  模型已存在，跳过"
else
  ok=0
  for u in \
    "https://hf-mirror.com/chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF/resolve/main/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
  do
    echo "  下载中：镜像会持续输出进度"
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

echo "[3/4] 创建启动脚本..."
cat > "$BASE/启动判分服务.command" <<'EOS'
#!/bin/bash
cd "$(dirname "$0")"
if curl -s -m 2 http://127.0.0.1:8001/health >/dev/null 2>&1; then
  echo "判分服务已在运行。"
  read -r -p "按回车键关闭..." _
  exit 0
fi
nohup ./jev/llama/llama-server -m "jev/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf" --host 127.0.0.1 --port 8001 -c 2048 -t 8 --no-webui >> "jev/server.log" 2>&1 &
sleep 1
echo "判分服务已在后台启动（无窗口，可以关闭此窗口）。"
read -r -p "按回车键关闭..." _
EOS
chmod +x "$BASE/启动判分服务.command"

# 立即在后台启动一次（若尚未运行）
if ! curl -s -m 2 http://127.0.0.1:8001/health >/dev/null 2>&1; then
  ( cd "$BASE" && nohup ./jev/llama/llama-server -m "jev/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf" --host 127.0.0.1 --port 8001 -c 2048 -t 8 --no-webui >> "jev/server.log" 2>&1 & )
fi
echo "  完成"
echo ""

echo "[4/4] 安装完成！"
echo ""
echo "  使用方法："
echo "    判分服务已在后台运行（无窗口）；"
echo "    以后要用时，双击安装目录里的「启动判分服务.command」。"
echo "    打开网页版答题，释义判分会自动使用本地模型。"
echo ""
echo "  服务地址：http://127.0.0.1:8001"
echo ""
read -r -p "按回车键关闭..." _
