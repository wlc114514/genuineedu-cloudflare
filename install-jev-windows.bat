@echo off
setlocal
title JEV 本地判分服务一键安装
:: ============================================================
::  JEV 本地判分服务一键安装（Windows）
::  为网页版背词工具提供本地释义判分（llama-server + JEV 模型）
:: ============================================================

if not "%JEV_TEST_DIR%"=="" set "INSTALL_DIR=%JEV_TEST_DIR%"
if "%INSTALL_DIR%"=="" set "INSTALL_DIR=%LOCALAPPDATA%\Programs\JEV"

echo ==================================================================
echo         JEV 本地判分服务一键安装（Windows）
echo ==================================================================
echo.
echo   安装位置：%INSTALL_DIR%
echo   安装内容：llama-server + JEV 判分模型（约 520MB）
echo.
echo   装好后：判分服务自动在后台运行（无窗口、无桌面图标），
echo   网页版默写时自动使用；网页上可一键唤起。
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

echo [5/5] 创建启动脚本（隐藏启动 + 网页唤起）...
(
echo @echo off
echo title JEV本地判分服务-保持本窗口打开
echo cd /d "%%~dp0jev"
echo echo.
echo echo JEV 本地判分服务启动中...
echo echo 服务地址 http://127.0.0.1:8001
echo echo 打开网页版默写时，释义判分会自动使用本服务。
echo echo 请保持本窗口打开；按 Ctrl+C 停止服务。
echo echo.
echo llama\llama-server.exe -m "Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf" --host 127.0.0.1 --port 8001 -c 2048 -t 8 --no-webui
echo echo.
echo echo 服务已停止。按任意键关闭...
echo pause
) > "%INSTALL_DIR%\启动判分服务.bat"

:: 生成隐藏启动器 start_jev_hidden.vbs（base64 内嵌，certutil 解码，纯 ASCII 无编码风险）
set "JEV_B64=%TEMP%\jev_vbs_b64.txt"
(
echo -----BEGIN CERTIFICATE-----
echo JyBKRVYgbG9jYWwganVkZ2luZyBzZXJ2aWNlIC0gaGlkZGVuIGxhdW5jaGVyCicgQ2hlY2tzIGlm
echo IHNlcnZpY2UgaXMgYWxyZWFkeSBydW5uaW5nOyBpZiBub3QsIHN0YXJ0cyBsbGFtYS1zZXJ2ZXIg
echo d2l0aCBubyB3aW5kb3cuCk9wdGlvbiBFeHBsaWNpdApEaW0gZnNvLCBzaGVsbCwgYmFzZSwgaHR0
echo cCwgY21kClNldCBmc28gPSBDcmVhdGVPYmplY3QoIlNjcmlwdGluZy5GaWxlU3lzdGVtT2JqZWN0
echo IikKU2V0IHNoZWxsID0gQ3JlYXRlT2JqZWN0KCJXU2NyaXB0LlNoZWxsIikKYmFzZSA9IGZzby5H
echo ZXRQYXJlbnRGb2xkZXJOYW1lKFdTY3JpcHQuU2NyaXB0RnVsbE5hbWUpCgpPbiBFcnJvciBSZXN1
echo bWUgTmV4dApTZXQgaHR0cCA9IENyZWF0ZU9iamVjdCgiTVNYTUwyLlNlcnZlclhNTEhUVFAuNi4w
echo IikKaHR0cC5vcGVuICJHRVQiLCAiaHR0cDovLzEyNy4wLjAuMTo4MDAxL2hlYWx0aCIsIEZhbHNl
echo Cmh0dHAuc2VuZApJZiBFcnIuTnVtYmVyID0gMCBUaGVuCiAgSWYgaHR0cC5zdGF0dXMgPSAyMDAg
echo VGhlbgogICAgV1NjcmlwdC5RdWl0IDAKICBFbmQgSWYKRW5kIElmCkVyci5DbGVhcgpPbiBFcnJv
echo ciBHb3RvIDAKCmNtZCA9ICJjbWQgL2MgY2QgL2QgIiIiICYgYmFzZSAmICJcamV2IiIgJiYgbGxh
echo bWFcbGxhbWEtc2VydmVyLmV4ZSAtbSAiIkpldi1TdHlsZS0wLjhCLURlY2lzaW9uLXYzLVE0X0tf
echo TS5nZ3VmIiIgLS1ob3N0IDEyNy4wLjAuMSAtLXBvcnQgODAwMSAtYyAyMDQ4IC10IDggLS1uby13
echo ZWJ1aSA+PiAiInNlcnZlci5sb2ciIiAyPiYxIgpzaGVsbC5SdW4gY21kLCAwLCBGYWxzZQo=
echo -----END CERTIFICATE-----
) > "%JEV_B64%"
certutil -decode "%JEV_B64%" "%INSTALL_DIR%\start_jev_hidden.vbs" >nul 2>nul
del "%JEV_B64%" 2>nul
if not exist "%INSTALL_DIR%\start_jev_hidden.vbs" echo         [警告] 隐藏启动器生成失败，可重新运行本脚本

:: 注册 jev:// 协议（网页「启动判分服务」按钮唤起用；测试模式跳过，避免覆盖正式注册）
if not "%JEV_TEST_DIR%"=="" goto skip_reg
reg add "HKCU\Software\Classes\jev" /ve /d "URL:JEV Local Service" /f >nul 2>nul
reg add "HKCU\Software\Classes\jev" /v "URL Protocol" /t REG_SZ /d "" /f >nul 2>nul
reg add "HKCU\Software\Classes\jev\shell\open\command" /ve /t REG_SZ /d "\"C:\Windows\System32\wscript.exe\" \"%INSTALL_DIR%\start_jev_hidden.vbs\" \"%%1\"" /f >nul 2>nul
:skip_reg
echo         完成
echo.

echo ==================================================================
echo    安装完成！
echo ==================================================================
echo.
echo   使用方法：
echo     1. 判分服务已在后台运行（无窗口，桌面无任何图标）
echo     2. 以后（如重启后）要用时：打开网页，点顶部「启动判分服务」按钮
echo     3. 打开网页版答题，释义判分会自动使用本地模型
echo.
echo   如果浏览器询问「是否允许访问本地网络/设备」，请点允许。
echo   服务地址：http://127.0.0.1:8001
echo ==================================================================
echo.
set "SN="
set /p SN=是否立即在后台启动判分服务？(Y/N): 
if /i not "%SN%"=="Y" goto the_end
"%SystemRoot%\System32\wscript.exe" "%INSTALL_DIR%\start_jev_hidden.vbs"
echo         服务已在后台启动（无窗口）

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
