@echo off
setlocal
title JEV 背词环境一键安装
:: ============================================================
::  JEV 背词环境一键安装（Windows）
::  安装内容：llama-server + JEV 模型 + 背词工具脚本 + 启动器
:: ============================================================

if not "%JEV_TEST_DIR%"=="" set "INSTALL_DIR=%JEV_TEST_DIR%"
if "%INSTALL_DIR%"=="" set "INSTALL_DIR=%USERPROFILE%\Desktop\背词工具"
if "%JEV_FILES_BASE%"=="" set "JEV_FILES_BASE=https://genuineedu.pages.dev/files"

echo ==================================================================
echo              JEV 背词环境一键安装（Windows）
echo ==================================================================
echo.
echo   安装位置：%INSTALL_DIR%
echo   安装内容：llama-server、JEV 模型、背词工具脚本与启动器
echo   下载总量：约 550MB，具体用时取决于网速
echo.
echo   下载中断不要紧，重新运行本脚本即可断点续传。
echo   安装过程请保持本窗口打开。
echo ==================================================================
echo.

echo [1/7] 检查系统环境...
where curl >nul 2>nul
if errorlevel 1 goto err_curl
echo         curl 可用
echo.

echo [2/7] 创建目录...
mkdir "%INSTALL_DIR%" 2>nul
mkdir "%INSTALL_DIR%\jev" 2>nul
mkdir "%INSTALL_DIR%\jev\llama" 2>nul
if not exist "%INSTALL_DIR%\jev\llama" goto err_mkdir
echo         完成
echo.

echo [3/7] 准备 llama-server（约 16MB）...
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

echo [4/7] 下载 JEV 判分模型（约 505MB，请耐心等待）...
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

echo [5/7] 检查 Python 环境...
set "PYEXE="
python --version >nul 2>nul
if errorlevel 1 goto py_try_launcher
set "PYEXE=python"
goto py_ready

:py_try_launcher
py -3 --version >nul 2>nul
if errorlevel 1 goto py_install
set "PYEXE=py"
goto py_ready

:py_install
echo         未检测到 Python，下载安装包（约 25MB）...
set "PY_SETUP=%TEMP%\python-3.11.9-setup.exe"
curl -L -# --fail --retry 3 --connect-timeout 20 -o "%PY_SETUP%" "https://registry.npmmirror.com/-/binary/python/3.11.9/python-3.11.9-amd64.exe"
if errorlevel 1 goto py_fail
echo         静默安装（仅当前用户，无需管理员权限）...
"%PY_SETUP%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
del "%PY_SETUP%" 2>nul
set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
set /a PYT_N=0

:pyt_wait
if exist "%PYEXE%" goto py_ready
timeout /t 3 /nobreak >nul
set /a PYT_N+=1
if %PYT_N% LSS 20 goto pyt_wait
goto py_fail

:py_fail
echo         [提示] Python 自动安装未成功，稍后可手动安装：
echo                https://www.python.org/downloads/ （安装时勾选 Add to PATH）
set "PYEXE=python"
goto py_after

:py_ready
echo         使用 Python：%PYEXE%
"%PYEXE%" -c "import tkinter" >nul 2>nul
if errorlevel 1 echo         [提示] 当前 Python 缺少 tkinter，默写界面需要完整版 Python
echo         安装依赖库 requests...
"%PYEXE%" -m pip install requests -q -i https://pypi.tuna.tsinghua.edu.cn/simple
if errorlevel 1 "%PYEXE%" -m pip install requests -q

:py_after
echo.

echo [6/7] 下载背词工具脚本...
curl -L --fail --connect-timeout 20 -s --retry 2 -o "%INSTALL_DIR%\dictation.py" "%JEV_FILES_BASE%/dictation.py"
curl -L --fail --connect-timeout 20 -s --retry 2 -o "%INSTALL_DIR%\dictation_forms.py" "%JEV_FILES_BASE%/dictation_forms.py"
curl -L --fail --connect-timeout 20 -s --retry 2 -o "%INSTALL_DIR%\dictation_judge.json" "%JEV_FILES_BASE%/dictation_judge.json"
curl -L --fail --connect-timeout 20 -s --retry 2 -o "%INSTALL_DIR%\download_jev_from_mirror.py" "%JEV_FILES_BASE%/download_jev_from_mirror.py"
curl -L --fail --connect-timeout 20 -s --retry 2 -o "%INSTALL_DIR%\start_jev_server.py" "%JEV_FILES_BASE%/start_jev_server.py"
curl -L --fail --connect-timeout 20 -s --retry 2 -o "%INSTALL_DIR%\jev\readout_config.json" "%JEV_FILES_BASE%/readout_config.json"
curl -L --fail --connect-timeout 20 -s --retry 2 -o "%INSTALL_DIR%\jev\jev_style_decision_gguf.py" "%JEV_FILES_BASE%/jev_style_decision_gguf.py"
if not exist "%INSTALL_DIR%\dictation.py" goto err_files
echo         完成
echo.

echo [7/7] 创建启动脚本...
(
echo @echo off
echo title JEV 判分服务-保持本窗口打开
echo cd /d "%%~dp0"
echo echo.
echo echo JEV 判分服务启动中，服务地址 http://127.0.0.1:8001
echo echo 请保持本窗口打开；按 Ctrl+C 停止服务。
echo echo.
echo "%PYEXE%" "%%~dp0start_jev_server.py"
echo echo.
echo echo 服务已停止。按任意键关闭...
echo pause
) > "%INSTALL_DIR%\启动判分服务.bat"
(
echo @echo off
echo title 单词默写
echo cd /d "%%~dp0"
echo "%PYEXE%" dictation.py
echo pause
) > "%INSTALL_DIR%\单词默写.bat"
(
echo @echo off
echo title 变形默写
echo cd /d "%%~dp0"
echo "%PYEXE%" dictation_forms.py
echo pause
) > "%INSTALL_DIR%\变形默写.bat"
if not "%JEV_TEST_DIR%"=="" goto no_shortcut
powershell -NoProfile -Command "$WS=New-Object -ComObject WScript.Shell; $SC=$WS.CreateShortcut('%USERPROFILE%\Desktop\背词工具-启动服务.lnk'); $SC.TargetPath='%INSTALL_DIR%\启动判分服务.bat'; $SC.WorkingDirectory='%INSTALL_DIR%'; $SC.IconLocation='shell32.dll,277'; $SC.Save()" 2>nul
:no_shortcut
echo         完成
echo.

echo ==================================================================
echo    安装完成！
echo ==================================================================
echo.
echo   安装位置：%INSTALL_DIR%
echo.
echo   使用方法：
echo     1. 双击桌面「背词工具-启动服务」启动判分服务
echo        （也可以双击安装目录里的 启动判分服务.bat）
echo     2. 双击「单词默写.bat」开始默写，双击「变形默写.bat」做变形默写
echo.
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

:err_files
echo.
echo [错误] 背词工具脚本下载失败（网络问题）。
echo        请检查网络后重新运行本脚本：
echo        %JEV_FILES_BASE%
goto the_end_fail

:the_end_fail
echo.
echo 按任意键关闭本窗口...
pause >nul
exit /b 1
