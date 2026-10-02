@echo off
setlocal
title JEV 本地判分服务一键安装
:: ============================================================
::  JEV 本地判分服务一键安装（Windows）
::  为网页版背词工具提供本地释义判分（llama-server + JEV 模型）
:: ============================================================

if not "%JEV_TEST_DIR%"=="" set "INSTALL_DIR=%JEV_TEST_DIR%"
if "%INSTALL_DIR%"=="" set "INSTALL_DIR=%USERPROFILE%\Desktop\背词工具"

echo ==================================================================
echo         JEV 本地判分服务一键安装（Windows）
echo ==================================================================
echo.
echo   安装位置：%INSTALL_DIR%
echo   安装内容：llama-server + JEV 判分模型（约 520MB）
echo.
echo   装好后：双击桌面「JEV本地判分服务」启动，
echo   网页版默写时的释义判分会自动使用它。
echo.
echo   下载中断不要紧，重新运行本脚本即可断点续传。
echo   安装过程请保持本窗口打开。
echo ==================================================================
echo.

echo [1/5] 检查系统环境...
where curl >nul 2>nul
if errorlevel 1 goto err_curl
echo         curl 可用
echo.

echo [2/5] 创建目录...
mkdir "%INSTALL_DIR%" 2>nul
mkdir "%INSTALL_DIR%\jev" 2>nul
mkdir "%INSTALL_DIR%\jev\llama" 2>nul
if not exist "%INSTALL_DIR%\jev\llama" goto err_mkdir
echo         完成
echo.

echo [3/5] 准备 llama-server（约 16MB）...
set "LLAMA_EXE=%INSTALL_DIR%\jev\llama\llama-server.exe"
set "LLAMA_ZIP=%TEMP%\llama-cpp-b8944.zip"
if exist "%LLAMA_EXE%" goto llama_done
if exist "%LLAMA_ZIP%" for %%A in ("%LLAMA_ZIP%") do if %%~zA GEQ 15895092 goto llama_extract
echo         下载中（源 1/3）...
curl -L -# --fail --retry 3 --connect-timeout 20 -C - -o "%LLAMA_ZIP%" "https://gh-proxy.com/https://github.com/ggml-org/llama.cpp/releases/download/b8944/llama-b8944-bin-win-cpu-x64.zip"
if not errorlevel 1 goto llama_extract
echo         源 1 失败，换源 2/3...
curl -L -# --fail --retry 3 --connect-timeout 20 -C - -o "%LLAMA_ZIP%" "https://ghproxy.net/https://github.com/ggml-org/llama.cpp/releases/download/b8944/llama-b8944-bin-win-cpu-x64.zip"
if not errorlevel 1 goto llama_extract
echo         换源 3/3（GitHub 直连）...
curl -L -# --fail --retry 3 --connect-timeout 20 -C - -o "%LLAMA_ZIP%" "https://github.com/ggml-org/llama.cpp/releases/download/b8944/llama-b8944-bin-win-cpu-x64.zip"
if not errorlevel 1 goto llama_extract
echo         重新尝试完整下载...
curl -L -# --fail --retry 3 --connect-timeout 20 -o "%LLAMA_ZIP%" "https://gh-proxy.com/https://github.com/ggml-org/llama.cpp/releases/download/b8944/llama-b8944-bin-win-cpu-x64.zip"
if errorlevel 1 goto err_llama

:llama_extract
echo         正在解压...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$z='%LLAMA_ZIP%'; $d='%INSTALL_DIR%\jev\llama'; $t=Join-Path $env:TEMP ('llama_x_'+[guid]::NewGuid().ToString('N')); Expand-Archive -LiteralPath $z -DestinationPath $t -Force; $f=Get-ChildItem $t -Recurse -Filter 'llama-server.exe' | Select-Object -First 1; if ($f) { Copy-Item (Join-Path $f.DirectoryName '*') $d -Recurse -Force }; Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue"
if not exist "%LLAMA_EXE%" goto err_llama
del "%LLAMA_ZIP%" 2>nul

:llama_done
echo         完成
echo.

echo [4/5] 下载 JEV 判分模型（约 505MB，请耐心等待）...
set "MODEL=%INSTALL_DIR%\jev\Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
if exist "%MODEL%" for %%A in ("%MODEL%") do if %%~zA GEQ 528000000 goto model_done
echo         下载中（hf-mirror 镜像）...
curl -L -# --fail --retry 3 --connect-timeout 20 -C - -o "%MODEL%" "https://hf-mirror.com/chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF/resolve/main/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
if not errorlevel 1 goto model_check
echo         镜像失败，请稍候重试一次（服务器繁忙时有效）...
timeout /t 5 /nobreak >nul
curl -L -# --fail --retry 5 --retry-delay 3 --connect-timeout 20 -C - -o "%MODEL%" "https://hf-mirror.com/chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF/resolve/main/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"

:model_check
if not exist "%MODEL%" goto err_model
for %%A in ("%MODEL%") do if %%~zA LSS 528000000 goto err_model

:model_done
echo         完成
echo.

echo [5/5] 创建启动脚本...
(
echo @echo off
echo title JEV本地判分服务-保持本窗口打开
echo cd /d "%%~dp0"
echo echo.
echo echo JEV 本地判分服务启动中...
echo echo 服务地址 http://127.0.0.1:8001
echo echo 打开网页版默写时，释义判分会自动使用本服务。
echo echo 请保持本窗口打开；按 Ctrl+C 停止服务。
echo echo.
echo "%%~dp0jev\llama\llama-server.exe" -m "%%~dp0jev\Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf" --host 127.0.0.1 --port 8001 -c 2048 -t 8 --no-webui
echo echo.
echo echo 服务已停止。按任意键关闭...
echo pause
) > "%INSTALL_DIR%\启动判分服务.bat"
if not "%JEV_TEST_DIR%"=="" goto no_shortcut
powershell -NoProfile -Command "$WS=New-Object -ComObject WScript.Shell; $SC=$WS.CreateShortcut('%USERPROFILE%\Desktop\JEV本地判分服务.lnk'); $SC.TargetPath='%INSTALL_DIR%\启动判分服务.bat'; $SC.WorkingDirectory='%INSTALL_DIR%'; $SC.IconLocation='shell32.dll,277'; $SC.Save()" 2>nul
:no_shortcut
echo         完成
echo.

echo ==================================================================
echo    安装完成！
echo ==================================================================
echo.
echo   使用方法：
echo     1. 双击桌面「JEV本地判分服务」启动服务（保持窗口打开）
echo     2. 打开网页版答题，释义判分会自动使用本地模型
echo.
echo   如果浏览器询问「是否允许访问本地网络/设备」，请点允许。
echo   服务地址：http://127.0.0.1:8001
echo ==================================================================
echo.
set "SN="
set /p SN=是否立即启动判分服务？(Y/N): 
if /i not "%SN%"=="Y" goto the_end
start "" "%INSTALL_DIR%\启动判分服务.bat"

:the_end
echo.
echo 按任意键关闭本窗口...
pause >nul
exit /b 0

:err_curl
echo.
echo [错误] 未找到 curl：本安装器需要 Windows 10 (1803) 及以上版本。
echo        请升级系统后重试，或参考 https://genuineedu.pages.dev 手动安装。
goto the_end_fail

:err_mkdir
echo.
echo [错误] 无法创建目录：%INSTALL_DIR%
echo        请检查磁盘空间与权限后重试。
goto the_end_fail

:err_llama
echo.
echo [错误] llama-server 下载或解压失败。重新运行本脚本可断点续传。
echo        手动方案：访问 https://github.com/ggml-org/llama.cpp/releases/tag/b8944
echo        下载 llama-b8944-bin-win-cpu-x64.zip，解压后把其中所有文件放到：
echo        %INSTALL_DIR%\jev\llama\
goto the_end_fail

:err_model
echo.
echo [错误] 模型下载失败或不完整。重新运行本脚本可断点续传。
echo        手动方案：从 https://hf-mirror.com/chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF
echo        下载 Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf，放到：
echo        %INSTALL_DIR%\jev\
goto the_end_fail

:the_end_fail
echo.
echo 按任意键关闭本窗口...
pause >nul
exit /b 1
