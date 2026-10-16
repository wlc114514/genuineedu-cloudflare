#!/bin/bash
# JEV 本地判分服务 · macOS / Linux 安装器
#   curl -fsSL https://genuineedu.pages.dev/jev/unix/install.sh | bash
# 重复运行是安全的：已下载的文件校验通过就跳过，下载中断会续传。
# 可选环境变量：JEV_ORIGIN（网站地址）、JEV_INSTALL_DIR、JEV_NO_START=1、JEV_NO_REGISTER=1、
#               JEV_LLAMA_URL / JEV_MODEL_URL（自定义下载地址，空格分隔多个）
set -u

ORIGIN="${JEV_ORIGIN:-https://genuineedu.pages.dev}"
ORIGIN="${ORIGIN%/}"
SOURCE="${JEV_SOURCE:-$ORIGIN/jev/unix}"
LLAMA_TAG=b8944
MODEL=Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf
MODEL_SHA=0a19bc29bacc33e0d871146c8612b24dd14c2ed2e61cedeb7a928b0852628bac
MODEL_SIZE=529296864

if [ -t 1 ]; then C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_WARN=$'\033[33m'; C_STEP=$'\033[36m'; C_DIM=$'\033[2m'; C_END=$'\033[0m'
else C_OK=; C_ERR=; C_WARN=; C_STEP=; C_DIM=; C_END=; fi
say()  { printf '  %s\n' "$*"; }
ok()   { printf '  %s%s%s\n' "$C_OK" "$*" "$C_END"; }
warn() { printf '  %s%s%s\n' "$C_WARN" "$*" "$C_END"; }
step() { printf '\n%s%s%s\n' "$C_STEP" "$*" "$C_END"; }
fail() {
  printf '\n%s[安装失败] %s%s\n' "$C_ERR" "$1" "$C_END"
  [ -n "${2:-}" ] && printf '%s%s%s\n' "$C_WARN" "$2" "$C_END"
  printf '%s重新运行安装命令即可继续（已下载的部分不会重下）。%s\n' "$C_WARN" "$C_END"
  exit 1
}

OS=$(uname -s)
ARCH=$(uname -m)
case "$OS/$ARCH" in
  Darwin/arm64)  ASSET=macos-arm64;  ASSET_SHA=814a633d50981d5319106c3cf422e2986424a68a8a2badcb6df5b4c4be3f0e2a; ASSET_SIZE=8562778 ;;
  Darwin/x86_64) ASSET=macos-x64;    ASSET_SHA=ce625613a20a7dde45fc87ce0ee45dc04a0912b36921a544f4bb8c708a8d9f7b; ASSET_SIZE=8596384 ;;
  Linux/x86_64)  ASSET=ubuntu-x64;   ASSET_SHA=198c1bb9df0da35883ab0b61e54db614749cb31fec0033be1250e4b90c8423e1; ASSET_SIZE=13914075 ;;
  *) fail "暂不支持这个系统：$OS $ARCH。" "支持：macOS（Apple 芯片 / Intel）、64 位 Linux。" ;;
esac
if [ "$OS" = Darwin ]; then DEFAULT_BASE="$HOME/Library/Application Support/JEV"
else DEFAULT_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/JEV"; fi
BASE="${JEV_INSTALL_DIR:-$DEFAULT_BASE}"
JEV_DIR="$BASE/jev"
LLAMA_DIR="$JEV_DIR/llama"
LLAMA_TGZ="llama-$LLAMA_TAG-bin-$ASSET.tar.gz"
GH="https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_TAG/$LLAMA_TGZ"
LLAMA_URLS="${JEV_LLAMA_URL:-https://gh-proxy.com/$GH https://ghproxy.net/$GH $GH}"
HF="chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF/resolve/main/$MODEL"
MODEL_URLS="${JEV_MODEL_URL:-https://hf-mirror.com/$HF https://huggingface.co/$HF}"
PERL=/usr/bin/perl
[ -x "$PERL" ] || PERL=$(command -v perl || true)
SCRIPT_DIR=""
case "${BASH_SOURCE[0]:-}" in */install.sh) SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) ;; esac

filesize() { wc -c < "$1" | tr -d ' '; }
sha256() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }

# 下载到 .part，大小与 SHA256 都对上才改成正式文件名
get_verified() {  # urls dest sha size label
  local urls=$1 dest=$2 sha=$3 size=$4 label=$5 part="$2.part" i=0 n u len host
  if [ -f "$dest" ] && [ "$(filesize "$dest")" = "$size" ]; then
    say "校验已有的$label…"
    if [ "$(sha256 "$dest")" = "$sha" ]; then ok "已存在且完整，跳过下载"; return 0; fi
    warn "已有文件损坏，重新下载"; rm -f "$dest"
  fi
  [ -f "$part" ] && [ "$(filesize "$part")" -gt "$size" ] && rm -f "$part"
  n=$(echo $urls | wc -w | tr -d ' ')
  for u in $urls; do
    i=$((i + 1)); host=$(echo "$u" | sed -E 's#^[a-z]+://([^/]+).*#\1#')
    say "下载中（线路 $i/$n：$host）"
    if ! curl -L --fail --retry 3 --retry-delay 2 --connect-timeout 20 -# -C - -o "$part" "$u"; then
      if ! curl -L --fail --retry 2 --connect-timeout 20 -# -o "$part" "$u"; then warn "这条线路失败，换下一条"; continue; fi
    fi
    [ -f "$part" ] || continue
    len=$(filesize "$part")
    if [ "$len" != "$size" ]; then warn "文件大小不对（$len / $size），换下一条"; [ "$len" -gt "$size" ] && rm -f "$part"; continue; fi
    say "校验中…"
    if [ "$(sha256 "$part")" != "$sha" ]; then warn "校验不通过（文件损坏或被篡改），换下一条"; rm -f "$part"; continue; fi
    mv -f "$part" "$dest"; ok "完成"; return 0
  done
  fail "$label 下载失败。" "请检查网络（校园网/代理有时会拦截大文件），稍后重试。"
}

llama_current() {
  [ -x "$LLAMA_DIR/llama-server" ] || return 1
  [ "$(cat "$LLAMA_DIR/VERSION" 2>/dev/null)" = "$LLAMA_TAG" ] && return 0
  if "$LLAMA_DIR/llama-server" --version 2>&1 | grep -Eq "version: ${LLAMA_TAG#b}( |$)"; then echo "$LLAMA_TAG" > "$LLAMA_DIR/VERSION"; return 0; fi
  return 1
}

stop_everything() {
  [ -f "$BASE/agent.pl" ] && "$PERL" "$BASE/agent.pl" stop >/dev/null 2>&1
  # 旧版（.command 启动）的 llama-server：命令行是相对路径
  pkill -f "^\./jev/llama/llama-server -m jev/$MODEL" 2>/dev/null
  pkill -f "^$LLAMA_DIR/llama-server " 2>/dev/null
  return 0
}

wait_ready() {
  local end=$(( $(date +%s) + $1 )) p body
  while [ "$(date +%s)" -lt "$end" ]; do
    for p in 8002 18002 28002; do
      # --noproxy：很多人设了 http_proxy（Clash 等），curl 又不认 no_proxy 里的 127.* 写法
      body=$(curl -s -m 2 --noproxy "*" "http://127.0.0.1:$p/status" 2>/dev/null) || continue
      case "$body" in
        *'"app":"jev-agent"'*'"state":"ready"'*|*'"state":"ready"'*'"app":"jev-agent"'*) echo ready; return ;;
        *'"app":"jev-agent"'*'"state":"error"'*) echo "$body" | sed -E 's/.*"error":"([a-z_]*)".*/\1/'; return ;;
      esac
    done
    sleep 0.7
  done
  echo timeout
}

# ======================================================================
printf '\n  JEV 本地判分服务 · 安装\n'
printf '  %s位置：%s%s\n' "$C_DIM" "$BASE" "$C_END"
printf '  %s装好以后不用管它：网页需要时自动启动，网页关掉自动停止。%s\n' "$C_DIM" "$C_END"

step "[1/5] 检查环境"
command -v curl >/dev/null 2>&1 || fail "需要 curl。"
[ -n "$PERL" ] && "$PERL" -MJSON::PP -MIO::Socket::INET -e1 2>/dev/null || fail "需要系统自带的 perl（含 JSON::PP）。" "Linux 可用包管理器安装 perl。"
mkdir -p "$LLAMA_DIR" || fail "无法创建目录：$BASE"
need_kb=61440
{ [ -f "$JEV_DIR/$MODEL" ] && [ "$(filesize "$JEV_DIR/$MODEL")" = "$MODEL_SIZE" ]; } || need_kb=$((need_kb + 573440))
free_kb=$(df -Pk "$BASE" | awk 'NR==2 {print $4}')
[ "${free_kb:-0}" -ge "$need_kb" ] || fail "磁盘空间不足（需要约 $((need_kb / 1024)) MB，剩余 $((${free_kb:-0} / 1024)) MB）。"
ok "磁盘空间够用（剩余 $((free_kb / 1024)) MB）"
stop_everything
ok "已停止正在运行的旧服务"

step "[2/5] 推理引擎 llama-server（$LLAMA_TAG · $ASSET）"
if llama_current; then
  ok "已是最新，跳过"
else
  TMP_TGZ="${TMPDIR:-/tmp}/$LLAMA_TGZ"
  get_verified "$LLAMA_URLS" "$TMP_TGZ" "$ASSET_SHA" "$ASSET_SIZE" "llama-server 压缩包"
  say "解压中…"
  rm -rf "$LLAMA_DIR" && mkdir -p "$LLAMA_DIR"
  tar -xzf "$TMP_TGZ" -C "$LLAMA_DIR" --strip-components=1 || fail "解压失败。"
  chmod +x "$LLAMA_DIR/llama-server"
  [ "$OS" = Darwin ] && xattr -dr com.apple.quarantine "$LLAMA_DIR" 2>/dev/null
  echo "$LLAMA_TAG" > "$LLAMA_DIR/VERSION"
  rm -f "$TMP_TGZ"
  "$LLAMA_DIR/llama-server" --version >/dev/null 2>&1 || fail "llama-server 无法运行。" "请把完整报错发给维护者：$LLAMA_DIR/llama-server --version"
  ok "完成"
fi

step "[3/5] 判分模型（约 505MB，第一次装需要几分钟）"
get_verified "$MODEL_URLS" "$JEV_DIR/$MODEL" "$MODEL_SHA" "$MODEL_SIZE" "模型"

step "[4/5] 安装服务组件"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/agent.pl" ]; then
  cp -f "$SCRIPT_DIR/agent.pl" "$BASE/agent.pl.new"
else
  curl -fsSL --retry 3 -o "$BASE/agent.pl.new" "$SOURCE/agent.pl" || fail "无法下载组件 agent.pl（$SOURCE）。"
fi
grep -q 'JEV local judging agent' "$BASE/agent.pl.new" && "$PERL" -c "$BASE/agent.pl.new" >/dev/null 2>&1 \
  || { rm -f "$BASE/agent.pl.new"; fail "下载到的 agent.pl 不完整。"; }
mv -f "$BASE/agent.pl.new" "$BASE/agent.pl"
chmod +x "$BASE/agent.pl"
# 允许访问本服务的网站：默认几项 + 安装来源，保留用户以前手动加的
JEV_ORIGIN_ADD="$ORIGIN" "$PERL" -MJSON::PP -e '
  my $f = shift; my @o = ("https://genuineedu.pages.dev", "https://*.genuineedu.pages.dev", "http://localhost:*", "http://127.0.0.1:*", $ENV{JEV_ORIGIN_ADD});
  if (open my $h, "<", $f) { local $/; my $j = eval { decode_json(<$h>) }; push @o, @{ $j->{allowedOrigins} || [] } if ref $j eq "HASH"; }
  my %s; @o = grep { defined && length && !$s{$_}++ } @o;
  open my $w, ">", $f or die; print $w encode_json({ allowedOrigins => \@o });
' "$BASE/config.json" || fail "无法写入配置。"
cat > "$BASE/uninstall.sh" <<EOS
#!/bin/bash
# JEV 本地判分服务 · 卸载：bash "$BASE/uninstall.sh"
"$PERL" "$BASE/agent.pl" stop >/dev/null 2>&1
rm -rf "$BASE/JEV.app" "$BASE/jev" "$BASE/agent.pl" "$BASE/agent.lock" "$BASE/agent.log" "$BASE/agent.log.old" "$BASE/config.json"
rm -f "\${XDG_DATA_HOME:-\$HOME/.local/share}/applications/jev-handler.desktop"
rm -f "$BASE/uninstall.sh"
rmdir "$BASE" 2>/dev/null
echo "已卸载。网页会自动退回文字匹配判分。"
EOS
chmod +x "$BASE/uninstall.sh"
rm -f "$BASE/启动判分服务.command" "$BASE/停止判分服务.command"   # 旧版手动启停脚本
ok "完成"

step "[5/5] 注册 jev:// 链接（网页靠它在需要时唤起服务）"
if [ -n "${JEV_NO_REGISTER:-}" ]; then
  say "测试模式：跳过注册"
elif [ "$OS" = Darwin ]; then
  APP="$BASE/JEV.app"
  rm -rf "$APP"
  AS_AGENT=$(printf '%s' "$BASE/agent.pl" | sed 's/\\/\\\\/g; s/"/\\"/g')
  osacompile -o "$APP" \
    -e 'on open location theURL' \
    -e "do shell script \"/usr/bin/perl \" & quoted form of \"$AS_AGENT\" & \" \" & quoted form of theURL & \" > /dev/null 2>&1 &\"" \
    -e 'end open location' \
    -e 'on run' \
    -e "do shell script \"/usr/bin/perl \" & quoted form of \"$AS_AGENT\" & \" start > /dev/null 2>&1 &\"" \
    -e 'end run' || fail "无法创建协议处理程序（osacompile）。"
  PL="$APP/Contents/Info.plist"
  PB=/usr/libexec/PlistBuddy
  $PB -c "Delete :CFBundleURLTypes" "$PL" >/dev/null 2>&1
  $PB -c "Add :CFBundleURLTypes array" -c "Add :CFBundleURLTypes:0 dict" \
      -c "Add :CFBundleURLTypes:0:CFBundleURLName string com.genuineedu.jev" \
      -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" \
      -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string jev" "$PL"
  $PB -c "Set :CFBundleIdentifier com.genuineedu.jev" "$PL" 2>/dev/null || $PB -c "Add :CFBundleIdentifier string com.genuineedu.jev" "$PL"
  $PB -c "Delete :LSUIElement" "$PL" >/dev/null 2>&1; $PB -c "Add :LSUIElement bool true" "$PL"
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || warn "签名失败（不影响大多数系统）"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null
  ok "完成"
else
  APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p "$APPS"
  cat > "$APPS/jev-handler.desktop" <<EOS
[Desktop Entry]
Type=Application
Name=JEV 本地判分服务
Exec=$PERL "$BASE/agent.pl" %u
NoDisplay=true
Terminal=false
MimeType=x-scheme-handler/jev;
EOS
  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default jev-handler.desktop x-scheme-handler/jev
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" 2>/dev/null
    ok "完成"
  else
    warn "没有 xdg-mime：网页无法自动唤起服务，需要时手动运行  perl \"$BASE/agent.pl\" start"
  fi
fi

if [ -n "${JEV_NO_START:-}" ]; then printf '\n'; ok "安装完成。"; exit 0; fi
printf '\n'; say "正在启动判分服务…"
"$PERL" "$BASE/agent.pl" start
res=$(wait_ready 90)
case "$res" in
  ready)
    printf '\n'; ok "✓ 安装完成，判分服务已就绪。回到网页就能用了。"
    printf '  %s以后不用再管它：网页需要时自动启动，关掉网页自动停止。卸载：bash "%s/uninstall.sh"%s\n' "$C_DIM" "$BASE" "$C_END" ;;
  model_missing) fail "模型文件缺失。" ;;
  llama_missing) fail "llama-server 缺失。" ;;
  port_busy) fail "本机端口被占满（8001/18001/28001）。" "关掉占用这些端口的程序后，回到网页点「启动」即可。" ;;
  *) fail "服务没有按时启动（$res）。" "日志：$BASE/agent.log 和 $JEV_DIR/server.log" ;;
esac
