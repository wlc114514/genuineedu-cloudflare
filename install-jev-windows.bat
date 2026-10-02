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
echo   装好后：判分服务自动在后台运行（无窗口），托盘区出现 JEV 图标，
echo   可随时查看状态、开启或停止；网页上也提供一键开启/停止。
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

echo [5/5] 创建启动脚本（隐藏启动 + 托盘控制 + 网页唤起）...
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

:: 生成隐藏启动/停止器 start_jev_hidden.vbs（base64 内嵌，certutil 解码，纯 ASCII 无编码风险）
set "JEV_B64=%TEMP%\jev_vbs_b64.txt"
(
echo -----BEGIN CERTIFICATE-----
echo JyBKRVYgbG9jYWwganVkZ2luZyBzZXJ2aWNlIC0gaGlkZGVuIGxhdW5jaGVyIC8g
echo c3RvcHBlcgonIFVzYWdlOiBzdGFydF9qZXZfaGlkZGVuLnZicyBbamV2Oi8vc3Rh
echo cnQgfCBqZXY6Ly9zdG9wIHwgKG5vbmUpID0gc3RhcnRdCicgc3RhcnQ6IGVuc3Vy
echo ZXMgbGxhbWEtc2VydmVyICsgdHJheSBjb250cm9sbGVyIGFyZSBydW5uaW5nIChu
echo byB3aW5kb3cpCicgc3RvcCA6IHN0b3BzIHRoZSBzZXJ2aWNlIChwcm9jZXNzIGxp
echo c3RlbmluZyBvbiBwb3J0IDgwMDEpCk9wdGlvbiBFeHBsaWNpdApEaW0gZnNvLCBz
echo aGVsbCwgYmFzZSwgYXJnClNldCBmc28gPSBDcmVhdGVPYmplY3QoIlNjcmlwdGlu
echo Zy5GaWxlU3lzdGVtT2JqZWN0IikKU2V0IHNoZWxsID0gQ3JlYXRlT2JqZWN0KCJX
echo U2NyaXB0LlNoZWxsIikKYmFzZSA9IGZzby5HZXRQYXJlbnRGb2xkZXJOYW1lKFdT
echo Y3JpcHQuU2NyaXB0RnVsbE5hbWUpCgphcmcgPSAiIgpJZiBXU2NyaXB0LkFyZ3Vt
echo ZW50cy5Db3VudCA+IDAgVGhlbiBhcmcgPSBMQ2FzZShXU2NyaXB0LkFyZ3VtZW50
echo cygwKSkKCklmIEluU3RyKGFyZywgInN0b3AiKSA+IDAgVGhlbgogICcgc3RvcCB0
echo aGUgcHJvY2VzcyBsaXN0ZW5pbmcgb24gcG9ydCA4MDAxCiAgc2hlbGwuUnVuICJw
echo b3dlcnNoZWxsLmV4ZSAtTm9Qcm9maWxlIC1FeGVjdXRpb25Qb2xpY3kgQnlwYXNz
echo IC1XaW5kb3dTdHlsZSBIaWRkZW4gLUNvbW1hbmQgIiIkcD0oR2V0LU5ldFRDUENv
echo bm5lY3Rpb24gLUxvY2FsUG9ydCA4MDAxIC1TdGF0ZSBMaXN0ZW4gLUVycm9yQWN0
echo aW9uIFNpbGVudGx5Q29udGludWUgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxKS5P
echo d25pbmdQcm9jZXNzOyBJZiAoJHApIHsgU3RvcC1Qcm9jZXNzIC1JZCAkcCAtRm9y
echo Y2UgfSIiIiwgMCwgVHJ1ZQogIFdTY3JpcHQuUXVpdCAwCkVuZCBJZgoKJyAtLS0t
echo IHN0YXJ0IC0tLS0KRGltIGh0dHAsIHJ1bm5pbmcKcnVubmluZyA9IEZhbHNlCk9u
echo IEVycm9yIFJlc3VtZSBOZXh0ClNldCBodHRwID0gQ3JlYXRlT2JqZWN0KCJNU1hN
echo TDIuU2VydmVyWE1MSFRUUC42LjAiKQpodHRwLm9wZW4gIkdFVCIsICJodHRwOi8v
echo MTI3LjAuMC4xOjgwMDEvaGVhbHRoIiwgRmFsc2UKaHR0cC5zZW5kCklmIEVyci5O
echo dW1iZXIgPSAwIFRoZW4KICBJZiBodHRwLnN0YXR1cyA9IDIwMCBUaGVuIHJ1bm5p
echo bmcgPSBUcnVlCkVuZCBJZgpFcnIuQ2xlYXIKT24gRXJyb3IgR290byAwCgpJZiBO
echo b3QgcnVubmluZyBUaGVuCiAgRGltIGNtZAogIGNtZCA9ICJjbWQgL2MgY2QgL2Qg
echo IiIiICYgYmFzZSAmICJcamV2IiIgJiYgbGxhbWFcbGxhbWEtc2VydmVyLmV4ZSAt
echo bSAiIkpldi1TdHlsZS0wLjhCLURlY2lzaW9uLXYzLVE0X0tfTS5nZ3VmIiIgLS1o
echo b3N0IDEyNy4wLjAuMSAtLXBvcnQgODAwMSAtYyAyMDQ4IC10IDggLS1uby13ZWJ1
echo aSA+PiAiInNlcnZlci5sb2ciIiAyPiYxIgogIHNoZWxsLlJ1biBjbWQsIDAsIEZh
echo bHNlCkVuZCBJZgoKJyBlbnN1cmUgdHJheSBjb250cm9sbGVyIGlzIHJ1bm5pbmcg
echo KGd1YXJkZWQgYnkgYSBzaW5nbGUtaW5zdGFuY2UgbXV0ZXggaW5zaWRlKQpzaGVs
echo bC5SdW4gInBvd2Vyc2hlbGwuZXhlIC1Ob1Byb2ZpbGUgLUV4ZWN1dGlvblBvbGlj
echo eSBCeXBhc3MgLVdpbmRvd1N0eWxlIEhpZGRlbiAtRmlsZSAiIiIgJiBiYXNlICYg
echo IlxqZXZfdHJheS5wczEiIiIsIDAsIEZhbHNlCg==
echo -----END CERTIFICATE-----
) > "%JEV_B64%"
certutil -f -decode "%JEV_B64%" "%INSTALL_DIR%\start_jev_hidden.vbs" >nul 2>nul
del "%JEV_B64%" 2>nul
if not exist "%INSTALL_DIR%\start_jev_hidden.vbs" echo         [警告] 隐藏启动器生成失败，可重新运行本脚本

:: 生成托盘控制器 jev_tray.ps1（UTF-8 BOM，单实例，certutil 解码）
set "JEV_B64=%TEMP%\jev_ps1_b64.txt"
(
echo -----BEGIN CERTIFICATE-----
echo 77u/IyBKRVYg5pys5Zyw5Yik5YiG5pyN5YqhIC0g5omY55uY5o6n5Yi25ZmoCiMg
echo 5Yqf6IO977ya5omY55uY5Zu+5qCH5pi+56S65pyN5Yqh54q25oCB77yb5Y+z6ZSu
echo 6I+c5Y2V5Y+v5ZCv5YqoL+WBnOatouacjeWKoeOAgeaJk+W8gOe9keermeOAgemA
echo gOWHuuaJmOebmOOAggojIOeUseWuieijheWZqOeUn+aIkO+8jOaXoOmcgOeuoeeQ
echo huWRmOadg+mZkO+8jOS4jeWGmeazqOWGjOihqO+8iOmZpOWuieijheWZqOazqOWG
echo jOeahCBqZXY6Ly8g5Y2P6K6u77yJ44CCCiRFcnJvckFjdGlvblByZWZlcmVuY2Ug
echo PSAnU2lsZW50bHlDb250aW51ZScKJFByb2dyZXNzUHJlZmVyZW5jZSA9ICdTaWxl
echo bnRseUNvbnRpbnVlJwoKIyAtLS0tIOWNleWunuS+i+S/neaKpO+8muW3suacieaJ
echo mOebmOWcqOi3keWImeacrOi/m+eoi+ebtOaOpemAgOWHuiAtLS0tCiRjcmVhdGVk
echo TmV3ID0gJGZhbHNlCiRtdXRleCA9IE5ldy1PYmplY3QgU3lzdGVtLlRocmVhZGlu
echo Zy5NdXRleCgkdHJ1ZSwgJ0xvY2FsXEpFVl9UcmF5X0NvbnRyb2xsZXInLCBbcmVm
echo XSRjcmVhdGVkTmV3KQppZiAoLW5vdCAkY3JlYXRlZE5ldykgeyBleGl0IH0KCiRi
echo YXNlID0gU3BsaXQtUGF0aCAtUGFyZW50ICRNeUludm9jYXRpb24uTXlDb21tYW5k
echo LlBhdGgKCnRyeSB7CgpBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5XaW5k
echo b3dzLkZvcm1zCkFkZC1UeXBlIC1Bc3NlbWJseU5hbWUgU3lzdGVtLkRyYXdpbmcK
echo CmZ1bmN0aW9uIFRlc3QtSmV2UnVubmluZyB7CiAgdHJ5IHsKICAgICRyID0gSW52
echo b2tlLVdlYlJlcXVlc3QgLVVyaSAnaHR0cDovLzEyNy4wLjAuMTo4MDAxL2hlYWx0
echo aCcgLVRpbWVvdXRTZWMgMiAtVXNlQmFzaWNQYXJzaW5nCiAgICByZXR1cm4gKCRy
echo LlN0YXR1c0NvZGUgLWVxIDIwMCkKICB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9
echo Cn0KCiRzY3JpcHQ6cnVubmluZyA9IC0xICAgIyAtMSA9IOacquefpe+8iOmmlui9
echo ruS4jeW8uemAmuefpe+8iQp0cnkgeyAkaWNvblJ1biA9IE5ldy1PYmplY3QgU3lz
echo dGVtLkRyYXdpbmcuSWNvbiAoSm9pbi1QYXRoICRiYXNlICdqZXZfcnVuLmljbycp
echo IH0gY2F0Y2ggeyAkaWNvblJ1biA9IFtTeXN0ZW0uRHJhd2luZy5TeXN0ZW1JY29u
echo c106OkFwcGxpY2F0aW9uIH0KdHJ5IHsgJGljb25TdG9wID0gTmV3LU9iamVjdCBT
echo eXN0ZW0uRHJhd2luZy5JY29uIChKb2luLVBhdGggJGJhc2UgJ2pldl9zdG9wLmlj
echo bycpIH0gY2F0Y2ggeyAkaWNvblN0b3AgPSBbU3lzdGVtLkRyYXdpbmcuU3lzdGVt
echo SWNvbnNdOjpBcHBsaWNhdGlvbiB9CgokdHJheSA9IE5ldy1PYmplY3QgU3lzdGVt
echo LldpbmRvd3MuRm9ybXMuTm90aWZ5SWNvbgokbWVudSA9IE5ldy1PYmplY3QgU3lz
echo dGVtLldpbmRvd3MuRm9ybXMuQ29udGV4dE1lbnVTdHJpcAoKJG1pU3RhdHVzID0g
echo TmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Ub29sU3RyaXBNZW51SXRl
echo bSAn54q25oCB77ya5qOA5rWL5LitLi4uJwokbWlTdGF0dXMuRW5hYmxlZCA9ICRm
echo YWxzZQokbWlTdGFydCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMu
echo VG9vbFN0cmlwTWVudUl0ZW0gJ+WQr+WKqOacjeWKoScKJG1pU3RvcCAgPSBOZXct
echo T2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRvb2xTdHJpcE1lbnVJdGVtICfl
echo gZzmraLmnI3liqEnCiRtaVNpdGUgID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93
echo cy5Gb3Jtcy5Ub29sU3RyaXBNZW51SXRlbSAn5omT5byA6IOM6K+N572R56uZJwok
echo bWlFeGl0ICA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuVG9vbFN0
echo cmlwTWVudUl0ZW0gJ+mAgOWHuuaJmOebmCcKCiRudWxsID0gJG1lbnUuSXRlbXMu
echo QWRkKCRtaVN0YXR1cykKJG51bGwgPSAkbWVudS5JdGVtcy5BZGQoKE5ldy1PYmpl
echo Y3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuVG9vbFN0cmlwU2VwYXJhdG9yKSkKJG51
echo bGwgPSAkbWVudS5JdGVtcy5BZGQoJG1pU3RhcnQpCiRudWxsID0gJG1lbnUuSXRl
echo bXMuQWRkKCRtaVN0b3ApCiRudWxsID0gJG1lbnUuSXRlbXMuQWRkKChOZXctT2Jq
echo ZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRvb2xTdHJpcFNlcGFyYXRvcikpCiRu
echo dWxsID0gJG1lbnUuSXRlbXMuQWRkKCRtaVNpdGUpCiRudWxsID0gJG1lbnUuSXRl
echo bXMuQWRkKCRtaUV4aXQpCgokbWlTdGFydC5hZGRfQ2xpY2soewogIFN0YXJ0LVBy
echo b2Nlc3MgLUZpbGVQYXRoIChKb2luLVBhdGggJGVudjpTeXN0ZW1Sb290ICdTeXN0
echo ZW0zMlx3c2NyaXB0LmV4ZScpIC1Bcmd1bWVudExpc3QgKCciJyArIChKb2luLVBh
echo dGggJGJhc2UgJ3N0YXJ0X2pldl9oaWRkZW4udmJzJykgKyAnIicpIC1XaW5kb3dT
echo dHlsZSBIaWRkZW4KfSkKCiRtaVN0b3AuYWRkX0NsaWNrKHsKICAkcCA9IChHZXQt
echo TmV0VENQQ29ubmVjdGlvbiAtTG9jYWxQb3J0IDgwMDEgLVN0YXRlIExpc3RlbiAt
echo RXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFNlbGVjdC1PYmplY3QgLUZp
echo cnN0IDEpLk93bmluZ1Byb2Nlc3MKICBpZiAoJHApIHsgU3RvcC1Qcm9jZXNzIC1J
echo ZCAkcCAtRm9yY2UgfQp9KQoKJG1pU2l0ZS5hZGRfQ2xpY2soeyBTdGFydC1Qcm9j
echo ZXNzICdodHRwczovL2dlbnVpbmVlZHUucGFnZXMuZGV2JyB9KQokbWlFeGl0LmFk
echo ZF9DbGljayh7CiAgJHRyYXkuVmlzaWJsZSA9ICRmYWxzZQogICR0cmF5LkRpc3Bv
echo c2UoKQogIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5BcHBsaWNhdGlvbl06OkV4aXQo
echo KQp9KQoKJHRyYXkuQ29udGV4dE1lbnVTdHJpcCA9ICRtZW51CiR0cmF5Lkljb24g
echo PSAkaWNvblN0b3AKJHRyYXkuVGV4dCA9ICdKRVYg5pys5Zyw5Yik5YiG5pyN5Yqh
echo JwokdHJheS5hZGRfTW91c2VEb3VibGVDbGljayh7IFN0YXJ0LVByb2Nlc3MgJ2h0
echo dHBzOi8vZ2VudWluZWVkdS5wYWdlcy5kZXYnIH0pCiR0cmF5LlZpc2libGUgPSAk
echo dHJ1ZQoKJHRpbWVyID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5U
echo aW1lcgokdGltZXIuSW50ZXJ2YWwgPSAzMDAwCiR0aW1lci5hZGRfVGljayh7CiAg
echo dHJ5IHsKICAgICRub3cgPSBUZXN0LUpldlJ1bm5pbmcKICAgIGlmICgkbm93IC1u
echo ZSAkc2NyaXB0OnJ1bm5pbmcpIHsKICAgICAgaWYgKCRub3cpIHsKICAgICAgICAk
echo dHJheS5JY29uID0gJGljb25SdW4KICAgICAgICAkdHJheS5UZXh0ID0gJ0pFViDm
echo nKzlnLDliKTliIbmnI3liqHvvJrov5DooYzkuK0nCiAgICAgICAgJG1pU3RhdHVz
echo LlRleHQgPSAn54q25oCB77ya6L+Q6KGM5Lit77yI56uv5Y+jIDgwMDHvvIknCiAg
echo ICAgICAgJG1pU3RhcnQuRW5hYmxlZCA9ICRmYWxzZQogICAgICAgICRtaVN0b3Au
echo RW5hYmxlZCA9ICR0cnVlCiAgICAgICAgaWYgKCRzY3JpcHQ6cnVubmluZyAtbmUg
echo LTEpIHsgJHRyYXkuU2hvd0JhbGxvb25UaXAoMjUwMCwgJ0pFViDmnKzlnLDliKTl
echo iIbmnI3liqEnLCAn5pyN5Yqh5bey5ZCv5YqoJywgW1N5c3RlbS5XaW5kb3dzLkZv
echo cm1zLlRvb2xUaXBJY29uXTo6SW5mbykgfQogICAgICB9IGVsc2UgewogICAgICAg
echo ICR0cmF5Lkljb24gPSAkaWNvblN0b3AKICAgICAgICAkdHJheS5UZXh0ID0gJ0pF
echo ViDmnKzlnLDliKTliIbmnI3liqHvvJrlt7LlgZzmraInCiAgICAgICAgJG1pU3Rh
echo dHVzLlRleHQgPSAn54q25oCB77ya5bey5YGc5q2iJwogICAgICAgICRtaVN0YXJ0
echo LkVuYWJsZWQgPSAkdHJ1ZQogICAgICAgICRtaVN0b3AuRW5hYmxlZCA9ICRmYWxz
echo ZQogICAgICAgIGlmICgkc2NyaXB0OnJ1bm5pbmcgLW5lIC0xKSB7ICR0cmF5LlNo
echo b3dCYWxsb29uVGlwKDI1MDAsICdKRVYg5pys5Zyw5Yik5YiG5pyN5YqhJywgJ+ac
echo jeWKoeW3suWBnOatoicsIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Ub29sVGlwSWNv
echo bl06Oldhcm5pbmcpIH0KICAgICAgfQogICAgICAkc2NyaXB0OnJ1bm5pbmcgPSAk
echo bm93CiAgICB9CiAgfSBjYXRjaCB7fQp9KQokdGltZXIuU3RhcnQoKQoKW1N5c3Rl
echo bS5XaW5kb3dzLkZvcm1zLkFwcGxpY2F0aW9uXTo6UnVuKCkKCn0gY2F0Y2ggewog
echo ICgkXyB8IE91dC1TdHJpbmcpIHwgQWRkLUNvbnRlbnQgLVBhdGggKEpvaW4tUGF0
echo aCAkYmFzZSAndHJheV9lcnJvci5sb2cnKSAtRW5jb2RpbmcgVVRGOAp9Cg==
echo -----END CERTIFICATE-----
) > "%JEV_B64%"
certutil -f -decode "%JEV_B64%" "%INSTALL_DIR%\jev_tray.ps1" >nul 2>nul
del "%JEV_B64%" 2>nul
if not exist "%INSTALL_DIR%\jev_tray.ps1" echo         [警告] 托盘控制器生成失败，可重新运行本脚本

:: 生成托盘图标 jev_run.ico（运行中 = 绿色圆点）
set "JEV_B64=%TEMP%\jev_ico1_b64.txt"
(
echo -----BEGIN CERTIFICATE-----
echo AAABAAIAEBAAAAEAIABIBAAAJgAAACAgAAABACAAqBAAAG4EAAAoAAAAEAAAACAA
echo AAABACAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiQV7FIoxexSKzXsUis17FIoxexSJBXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIdXsUis17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIrNexSIdXsUiAF7FIgBexSIAXsUiAF7FIgBexSIdXsUi2l7F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi2l7FIh1exSIAXsUiAF7F
echo IgBexSIAXsUis17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSKzXsUiAF7FIgBexSIAXsUiQV7FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIkFexSIAXsUiAF7FIoxexSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSKMXsUiAF7F
echo IgBexSKzXsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUis17FIgBexSIAXsUis17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIrNexSIAXsUiAF7FIoxexSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSKMXsUiAF7F
echo IgBexSJBXsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUiQV7FIgBexSIAXsUiAF7FIrNexSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUis17FIgBexSIAXsUiAF7FIgBexSIdXsUi2l7F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi2l7FIh1exSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIh1exSKzXsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUis17F
echo Ih1exSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIkFexSKMXsUis17F
echo IrNexSKMXsUiQV7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAACAAAABAAAAAAQAgAAAA
echo AAAAEAAAAAAAAAAAAAAAAAAAAAAAAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiNl7F
echo IltexSJuXsUibl7FIltexSI2XsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSJIXsUip17FIvVexSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL1XsUip17FIkhexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSI2XsUiul7F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo IrpexSI2XsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUibl7FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSJuXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IoFexSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSKBXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSJuXsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSJuXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiNl7FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSI2XsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSK6XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIrpexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiSF7FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIkhexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSKnXsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUip17FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIvVexSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL1XsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSI2XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSI2XsUiAF7FIgBexSIAXsUiAF7F
echo IltexSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIltexSIAXsUiAF7FIgBexSIAXsUibl7FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUibl7F
echo IgBexSIAXsUiAF7FIgBexSJuXsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSJuXsUiAF7FIgBexSIAXsUiAF7F
echo IltexSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIltexSIAXsUiAF7FIgBexSIAXsUiNl7FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUiNl7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUi9V7FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIvVexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSKnXsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUip17FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIkhexSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSJIXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIrpexSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUiul7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiNl7FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSI2XsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUibl7F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUibl7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUigV7FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIoFexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUibl7FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIv9exSJuXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiNl7FIrpexSL/XsUi/17FIv9exSL/XsUi/17FIv9exSL/XsUi/17F
echo Iv9exSL/XsUi/17FIv9exSK6XsUiNl7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IkhexSKnXsUi9V7FIv9exSL/XsUi/17FIv9exSL/XsUi/17FIvVexSKnXsUiSF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiNl7F
echo IltexSJuXsUibl7FIltexSI2XsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7F
echo IgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgBexSIAXsUiAF7FIgAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==
echo -----END CERTIFICATE-----
) > "%JEV_B64%"
certutil -f -decode "%JEV_B64%" "%INSTALL_DIR%\jev_run.ico" >nul 2>nul
del "%JEV_B64%" 2>nul
if not exist "%INSTALL_DIR%\jev_run.ico" echo         [警告] 托盘图标1生成失败，可重新运行本脚本

:: 生成托盘图标 jev_stop.ico（已停止 = 灰色圆环）
set "JEV_B64=%TEMP%\jev_ico2_b64.txt"
(
echo -----BEGIN CERTIFICATE-----
echo AAABAAIAEBAAAAEAIABIBAAAJgAAACAgAAABACAAqBAAAG4EAAAoAAAAEAAAACAA
echo AAABACAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUQbijlIy4o5SzuKOUs7ijlIy4o5RBuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QduKOUs7ijlP+4o5T/uKOU/7ij
echo lP+4o5T/uKOU/7ijlLO4o5QduKOUALijlAC4o5QAuKOUALijlAC4o5QduKOU2rij
echo lP+4o5T/uKOUw7ijlIy4o5SMuKOUw7ijlP+4o5T/uKOU2rijlB24o5QAuKOUALij
echo lAC4o5QAuKOUs7ijlP+4o5T3uKOUUrijlAC4o5QAuKOUALijlAC4o5RSuKOU97ij
echo lP+4o5SzuKOUALijlAC4o5QAuKOUQbijlP+4o5T/uKOUUrijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlFK4o5T/uKOU/7ijlEG4o5QAuKOUALijlIy4o5T/uKOUw7ij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUw7ijlP+4o5SMuKOUALij
echo lAC4o5SzuKOU/7ijlIy4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lIy4o5T/uKOUs7ijlAC4o5QAuKOUs7ijlP+4o5SMuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5SMuKOU/7ijlLO4o5QAuKOUALijlIy4o5T/uKOUw7ij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUw7ijlP+4o5SMuKOUALij
echo lAC4o5RBuKOU/7ijlP+4o5RSuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUUrij
echo lP+4o5T/uKOUQbijlAC4o5QAuKOUALijlLO4o5T/uKOU97ijlFK4o5QAuKOUALij
echo lAC4o5QAuKOUUrijlPe4o5T/uKOUs7ijlAC4o5QAuKOUALijlAC4o5QduKOU2rij
echo lP+4o5T/uKOUw7ijlIy4o5SMuKOUw7ijlP+4o5T/uKOU2rijlB24o5QAuKOUALij
echo lAC4o5QAuKOUALijlB24o5SzuKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOUs7ij
echo lB24o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlEG4o5SMuKOUs7ij
echo lLO4o5SMuKOUQbijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAACAAAABAAAAAAQAgAAAA
echo AAAAEAAAAAAAAAAAAAAAAAAAAAAAALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUNrij
echo lFu4o5RuuKOUbrijlFu4o5Q2uKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5RIuKOUp7ijlPW4o5T/uKOU/7ijlP+4o5T/uKOU/7ij
echo lP+4o5T1uKOUp7ijlEi4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5Q2uKOUurij
echo lP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ij
echo lLq4o5Q2uKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUbrijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ij
echo lP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5RuuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lIG4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ij
echo lP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5SBuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5RuuKOU/7ijlP+4o5T/uKOU/7ij
echo lP+4o5T/uKOUu7ijlGa4o5QsuKOUDrijlA64o5QsuKOUZrijlLu4o5T/uKOU/7ij
echo lP+4o5T/uKOU/7ijlP+4o5RuuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUNrijlP+4o5T/uKOU/7ijlP+4o5T/uKOU1rijlEm4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlEm4o5TWuKOU/7ijlP+4o5T/uKOU/7ij
echo lP+4o5Q2uKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5S6uKOU/7ij
echo lP+4o5T/uKOU/7ijlLu4o5QOuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlA64o5S7uKOU/7ijlP+4o5T/uKOU/7ijlLq4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUSLijlP+4o5T/uKOU/7ijlP+4o5TWuKOUDrij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lA64o5TWuKOU/7ijlP+4o5T/uKOU/7ijlEi4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5SnuKOU/7ijlP+4o5T/uKOU/7ijlEm4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlEm4o5T/uKOU/7ij
echo lP+4o5T/uKOUp7ijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlPW4o5T/uKOU/7ij
echo lP+4o5S7uKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlLu4o5T/uKOU/7ijlP+4o5T1uKOUALij
echo lAC4o5QAuKOUALijlAC4o5Q2uKOU/7ijlP+4o5T/uKOU/7ijlGa4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUZrijlP+4o5T/uKOU/7ijlP+4o5Q2uKOUALijlAC4o5QAuKOUALij
echo lFu4o5T/uKOU/7ijlP+4o5T/uKOULLijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QsuKOU/7ij
echo lP+4o5T/uKOU/7ijlFu4o5QAuKOUALijlAC4o5QAuKOUbrijlP+4o5T/uKOU/7ij
echo lP+4o5QOuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlA64o5T/uKOU/7ijlP+4o5T/uKOUbrij
echo lAC4o5QAuKOUALijlAC4o5RuuKOU/7ijlP+4o5T/uKOU/7ijlA64o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUDrijlP+4o5T/uKOU/7ijlP+4o5RuuKOUALijlAC4o5QAuKOUALij
echo lFu4o5T/uKOU/7ijlP+4o5T/uKOULLijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QsuKOU/7ij
echo lP+4o5T/uKOU/7ijlFu4o5QAuKOUALijlAC4o5QAuKOUNrijlP+4o5T/uKOU/7ij
echo lP+4o5RmuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlGa4o5T/uKOU/7ijlP+4o5T/uKOUNrij
echo lAC4o5QAuKOUALijlAC4o5QAuKOU9bijlP+4o5T/uKOU/7ijlLu4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUu7ijlP+4o5T/uKOU/7ijlPW4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5SnuKOU/7ijlP+4o5T/uKOU/7ijlEm4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlEm4o5T/uKOU/7ij
echo lP+4o5T/uKOUp7ijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlEi4o5T/uKOU/7ij
echo lP+4o5T/uKOU1rijlA64o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QOuKOU1rijlP+4o5T/uKOU/7ijlP+4o5RIuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlLq4o5T/uKOU/7ijlP+4o5T/uKOUu7ij
echo lA64o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUDrij
echo lLu4o5T/uKOU/7ijlP+4o5T/uKOUurijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUNrijlP+4o5T/uKOU/7ijlP+4o5T/uKOU1rijlEm4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlEm4o5TWuKOU/7ijlP+4o5T/uKOU/7ij
echo lP+4o5Q2uKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUbrij
echo lP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlLu4o5RmuKOULLijlA64o5QOuKOULLij
echo lGa4o5S7uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOUbrijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUgbijlP+4o5T/uKOU/7ij
echo lP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ij
echo lP+4o5T/uKOU/7ijlIG4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUbrijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ij
echo lP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5RuuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUNrijlLq4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ij
echo lP+4o5T/uKOU/7ijlP+4o5S6uKOUNrijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lEi4o5SnuKOU9bijlP+4o5T/uKOU/7ijlP+4o5T/uKOU/7ijlPW4o5SnuKOUSLij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUNrij
echo lFu4o5RuuKOUbrijlFu4o5Q2uKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALij
echo lAC4o5QAuKOUALijlAC4o5QAuKOUALijlAC4o5QAuKOUALijlAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==
echo -----END CERTIFICATE-----
) > "%JEV_B64%"
certutil -f -decode "%JEV_B64%" "%INSTALL_DIR%\jev_stop.ico" >nul 2>nul
del "%JEV_B64%" 2>nul
if not exist "%INSTALL_DIR%\jev_stop.ico" echo         [警告] 托盘图标2生成失败，可重新运行本脚本

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
echo     1. 判分服务已在后台运行；任务栏托盘区的 JEV 图标可查看状态、开/关服务
echo     2. 以后（如重启后）要用时：点网页顶部「启动判分服务」按钮即可
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
echo         服务已在后台启动（无窗口，托盘图标已就位）

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
