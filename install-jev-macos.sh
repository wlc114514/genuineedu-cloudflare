#!/bin/bash
# 旧链接兼容：新版安装器在 jev/unix/install.sh（同时支持 macOS 和 Linux）
ORIGIN="${JEV_ORIGIN:-https://genuineedu.pages.dev}"
curl -fsSL "${ORIGIN%/}/jev/unix/install.sh" | JEV_ORIGIN="$ORIGIN" bash
