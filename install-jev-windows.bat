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
echo   装好后：托盘区出现 JEV 管家图标（无窗口）；
echo   打开背词网站自动启动判分服务，关闭网页约 1 分钟后自动停止。
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

echo [5/5] 创建启动脚本（隐藏启动 + 托盘管家 + 网页联动）...
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
echo cnQgfCBqZXY6Ly9zdG9wIHwgdHJheSB8IChub25lKV0KJyBub25lL3N0YXJ0IDog
echo ZW5zdXJlIGxsYW1hLXNlcnZlciArIHRyYXkgY29udHJvbGxlciBhcmUgcnVubmlu
echo ZwonIHRyYXkgICAgICAgOiBlbnN1cmUgb25seSB0aGUgdHJheSBjb250cm9sbGVy
echo IChubyBzZXJ2aWNlIHN0YXJ0OyB1c2VkIGF0IGxvZ29uKQonIHN0b3AgICAgICAg
echo OiBzdG9wIHRoZSBzZXJ2aWNlIChwcm9jZXNzIGxpc3RlbmluZyBvbiBwb3J0IDgw
echo MDEpCk9wdGlvbiBFeHBsaWNpdApEaW0gZnNvLCBzaGVsbCwgYmFzZSwgYXJnClNl
echo dCBmc28gPSBDcmVhdGVPYmplY3QoIlNjcmlwdGluZy5GaWxlU3lzdGVtT2JqZWN0
echo IikKU2V0IHNoZWxsID0gQ3JlYXRlT2JqZWN0KCJXU2NyaXB0LlNoZWxsIikKYmFz
echo ZSA9IGZzby5HZXRQYXJlbnRGb2xkZXJOYW1lKFdTY3JpcHQuU2NyaXB0RnVsbE5h
echo bWUpCgphcmcgPSAiIgpJZiBXU2NyaXB0LkFyZ3VtZW50cy5Db3VudCA+IDAgVGhl
echo biBhcmcgPSBMQ2FzZShXU2NyaXB0LkFyZ3VtZW50cygwKSkKCklmIEluU3RyKGFy
echo ZywgInN0b3AiKSA+IDAgVGhlbgogICcgc3RvcCB0aGUgcHJvY2VzcyBsaXN0ZW5p
echo bmcgb24gcG9ydCA4MDAxCiAgc2hlbGwuUnVuICJwb3dlcnNoZWxsLmV4ZSAtTm9Q
echo cm9maWxlIC1FeGVjdXRpb25Qb2xpY3kgQnlwYXNzIC1XaW5kb3dTdHlsZSBIaWRk
echo ZW4gLUNvbW1hbmQgIiIkcD0oR2V0LU5ldFRDUENvbm5lY3Rpb24gLUxvY2FsUG9y
echo dCA4MDAxIC1TdGF0ZSBMaXN0ZW4gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGlu
echo dWUgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxKS5Pd25pbmdQcm9jZXNzOyBJZiAo
echo JHApIHsgU3RvcC1Qcm9jZXNzIC1JZCAkcCAtRm9yY2UgfSIiIiwgMCwgVHJ1ZQog
echo IFdTY3JpcHQuUXVpdCAwCkVuZCBJZgoKSWYgSW5TdHIoYXJnLCAidHJheSIpID0g
echo MCBUaGVuCiAgJyAtLS0tIGVuc3VyZSBzZXJ2aWNlIC0tLS0KICBEaW0gaHR0cCwg
echo cnVubmluZwogIHJ1bm5pbmcgPSBGYWxzZQogIE9uIEVycm9yIFJlc3VtZSBOZXh0
echo CiAgU2V0IGh0dHAgPSBDcmVhdGVPYmplY3QoIk1TWE1MMi5TZXJ2ZXJYTUxIVFRQ
echo LjYuMCIpCiAgaHR0cC5vcGVuICJHRVQiLCAiaHR0cDovLzEyNy4wLjAuMTo4MDAx
echo L2hlYWx0aCIsIEZhbHNlCiAgaHR0cC5zZW5kCiAgSWYgRXJyLk51bWJlciA9IDAg
echo VGhlbgogICAgSWYgaHR0cC5zdGF0dXMgPSAyMDAgVGhlbiBydW5uaW5nID0gVHJ1
echo ZQogIEVuZCBJZgogIEVyci5DbGVhcgogIE9uIEVycm9yIEdvdG8gMAoKICBJZiBO
echo b3QgcnVubmluZyBUaGVuCiAgICBEaW0gY21kCiAgICBjbWQgPSAiY21kIC9jIGNk
echo IC9kICIiIiAmIGJhc2UgJiAiXGpldiIiICYmIGxsYW1hXGxsYW1hLXNlcnZlci5l
echo eGUgLW0gIiJKZXYtU3R5bGUtMC44Qi1EZWNpc2lvbi12My1RNF9LX00uZ2d1ZiIi
echo IC0taG9zdCAxMjcuMC4wLjEgLS1wb3J0IDgwMDEgLWMgMjA0OCAtdCA4IC0tbm8t
echo d2VidWkgPj4gIiJzZXJ2ZXIubG9nIiIgMj4mMSIKICAgIHNoZWxsLlJ1biBjbWQs
echo IDAsIEZhbHNlCiAgRW5kIElmCkVuZCBJZgoKJyBlbnN1cmUgdHJheSBjb250cm9s
echo bGVyIGlzIHJ1bm5pbmcgKGd1YXJkZWQgYnkgYSBzaW5nbGUtaW5zdGFuY2UgbXV0
echo ZXggaW5zaWRlKQpzaGVsbC5SdW4gInBvd2Vyc2hlbGwuZXhlIC1Ob1Byb2ZpbGUg
echo LUV4ZWN1dGlvblBvbGljeSBCeXBhc3MgLVdpbmRvd1N0eWxlIEhpZGRlbiAtRmls
echo ZSAiIiIgJiBiYXNlICYgIlxqZXZfdHJheS5wczEiIiIsIDAsIEZhbHNlCg==
echo -----END CERTIFICATE-----
) > "%JEV_B64%"
certutil -f -decode "%JEV_B64%" "%INSTALL_DIR%\start_jev_hidden.vbs" >nul 2>nul
del "%JEV_B64%" 2>nul
if not exist "%INSTALL_DIR%\start_jev_hidden.vbs" echo         [警告] 隐藏启动器生成失败，可重新运行本脚本

:: 生成托盘控制器 jev_tray.ps1（UTF-8 BOM，单实例，certutil 解码）
set "JEV_B64=%TEMP%\jev_ps1_b64.txt"
(
echo -----BEGIN CERTIFICATE-----
echo 77u/IyBKRVYg5pys5Zyw5Yik5YiG5pyN5YqhIC0g5omY55uY5o6n5Yi25ZmoICsg
echo 572R6aG16IGU5Yqo566h5a62CiMg5Yqf6IO977yaCiMgIDEpIOaJmOebmOWbvuag
echo h+aYvuekuuacjeWKoeeKtuaAge+8m+WPs+mUruiPnOWNleWPr+WQr+WKqC/lgZzm
echo raLmnI3liqHjgIHmiZPlvIDnvZHnq5njgIHlvIDmnLroh6rlkK/lvIDlhbPjgIHp
echo gIDlh7rmiZjnm5jjgIIKIyAgMikg55uR5ZCsIDEyNy4wLjAuMTo4MDAy77ya572R
echo 6aG15omT5byA5pe255qE5b+D6Lez77yIL3BpbmfvvInoh6rliqjmi4notbfliKTl
echo iIbmnI3liqHvvJsKIyAgICAg572R6aG15YWo6YOo5YWz6Zet5ZCO5b+D6Lez5raI
echo 5aSx57qmIDc1IOenku+8jOiHquWKqOWBnOatouacjeWKoe+8iOmHiuaUvuWGheWt
echo mO+8ieOAggojIOeUseWuieijheWZqOeUn+aIkO+8jOaXoOmcgOeuoeeQhuWRmOad
echo g+mZkOOAggokRXJyb3JBY3Rpb25QcmVmZXJlbmNlID0gJ1NpbGVudGx5Q29udGlu
echo dWUnCiRQcm9ncmVzc1ByZWZlcmVuY2UgPSAnU2lsZW50bHlDb250aW51ZScKCiMg
echo LS0tLSDljZXlrp7kvovkv53miqQgLS0tLQokY3JlYXRlZE5ldyA9ICRmYWxzZQok
echo bXV0ZXggPSBOZXctT2JqZWN0IFN5c3RlbS5UaHJlYWRpbmcuTXV0ZXgoJHRydWUs
echo ICdMb2NhbFxKRVZfVHJheV9Db250cm9sbGVyJywgW3JlZl0kY3JlYXRlZE5ldykK
echo aWYgKC1ub3QgJGNyZWF0ZWROZXcpIHsgZXhpdCB9CgokYmFzZSA9IFNwbGl0LVBh
echo dGggLVBhcmVudCAkTXlJbnZvY2F0aW9uLk15Q29tbWFuZC5QYXRoCgp0cnkgewoK
echo QWRkLVR5cGUgLUFzc2VtYmx5TmFtZSBTeXN0ZW0uV2luZG93cy5Gb3JtcwpBZGQt
echo VHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5EcmF3aW5nCgojID09PT09PT09PT09
echo PT09PT09IOWfuuehgOWHveaVsCA9PT09PT09PT09PT09PT09PQpmdW5jdGlvbiBU
echo ZXN0LUpldlJ1bm5pbmcgewogIHRyeSB7CiAgICAkciA9IEludm9rZS1XZWJSZXF1
echo ZXN0IC1VcmkgJ2h0dHA6Ly8xMjcuMC4wLjE6ODAwMS9oZWFsdGgnIC1UaW1lb3V0
echo U2VjIDIgLVVzZUJhc2ljUGFyc2luZwogICAgcmV0dXJuICgkci5TdGF0dXNDb2Rl
echo IC1lcSAyMDApCiAgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQp9CgpmdW5jdGlv
echo biBTdG9wLUpldlNlcnZpY2UgewogICRwID0gKEdldC1OZXRUQ1BDb25uZWN0aW9u
echo IC1Mb2NhbFBvcnQgODAwMSAtU3RhdGUgTGlzdGVuIC1FcnJvckFjdGlvbiBTaWxl
echo bnRseUNvbnRpbnVlIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSkuT3duaW5nUHJv
echo Y2VzcwogIGlmICgkcCkgeyBTdG9wLVByb2Nlc3MgLUlkICRwIC1Gb3JjZSB9Cn0K
echo CmZ1bmN0aW9uIFN0YXJ0LUpldlNlcnZpY2VIaWRkZW4gewogIFN0YXJ0LVByb2Nl
echo c3MgLUZpbGVQYXRoIChKb2luLVBhdGggJGVudjpTeXN0ZW1Sb290ICdTeXN0ZW0z
echo Mlx3c2NyaXB0LmV4ZScpIC1Bcmd1bWVudExpc3QgKCciJyArIChKb2luLVBhdGgg
echo JGJhc2UgJ3N0YXJ0X2pldl9oaWRkZW4udmJzJykgKyAnIicpIC1XaW5kb3dTdHls
echo ZSBIaWRkZW4KfQoKIyA9PT09PT09PT09PT09PT09PSDnirbmgIEgPT09PT09PT09
echo PT09PT09PT0KJHNjcmlwdDpydW5uaW5nID0gLTEgICAgICAgICAgIyAtMSA9IOac
echo quefpe+8iOmmlui9ruS4jeW8uemAmuefpe+8iQokc2NyaXB0Omxhc3RQaW5nID0g
echo W0RhdGVUaW1lXTo6TWluVmFsdWUKJHNjcmlwdDpsYXN0U3RhcnRUcnkgPSBbRGF0
echo ZVRpbWVdOjpNaW5WYWx1ZQokaGVhcnRiZWF0VGltZW91dFNlYyA9IDc1Cgp0cnkg
echo eyAkaWNvblJ1biA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuSWNvbiAoSm9p
echo bi1QYXRoICRiYXNlICdqZXZfcnVuLmljbycpIH0gY2F0Y2ggeyAkaWNvblJ1biA9
echo IFtTeXN0ZW0uRHJhd2luZy5TeXN0ZW1JY29uc106OkFwcGxpY2F0aW9uIH0KdHJ5
echo IHsgJGljb25TdG9wID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5JY29uIChK
echo b2luLVBhdGggJGJhc2UgJ2pldl9zdG9wLmljbycpIH0gY2F0Y2ggeyAkaWNvblN0
echo b3AgPSBbU3lzdGVtLkRyYXdpbmcuU3lzdGVtSWNvbnNdOjpBcHBsaWNhdGlvbiB9
echo CgojID09PT09PT09PT09PT09PT09IOaJmOebmCBVSSA9PT09PT09PT09PT09PT09
echo PQokdHJheSA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuTm90aWZ5
echo SWNvbgokbWVudSA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuQ29u
echo dGV4dE1lbnVTdHJpcAoKJG1pU3RhdHVzID0gTmV3LU9iamVjdCBTeXN0ZW0uV2lu
echo ZG93cy5Gb3Jtcy5Ub29sU3RyaXBNZW51SXRlbSAn54q25oCB77ya5qOA5rWL5Lit
echo Li4uJwokbWlTdGF0dXMuRW5hYmxlZCA9ICRmYWxzZQokbWlTdGFydCA9IE5ldy1P
echo YmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuVG9vbFN0cmlwTWVudUl0ZW0gJ+WQ
echo r+WKqOacjeWKoScKJG1pU3RvcCAgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dz
echo LkZvcm1zLlRvb2xTdHJpcE1lbnVJdGVtICflgZzmraLmnI3liqEnCiRtaVNpdGUg
echo ID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Ub29sU3RyaXBNZW51
echo SXRlbSAn5omT5byA6IOM6K+N572R56uZJwokbWlBdXRvc3RhcnQgPSBOZXctT2Jq
echo ZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRvb2xTdHJpcE1lbnVJdGVtICflvIDm
echo nLroh6rlkK/vvIjmiZjnm5jnrqHlrrbvvIknCiRtaUF1dG9zdGFydC5DaGVja09u
echo Q2xpY2sgPSAkdHJ1ZQokbWlFeGl0ICA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRv
echo d3MuRm9ybXMuVG9vbFN0cmlwTWVudUl0ZW0gJ+mAgOWHuuaJmOebmCcKCiRudWxs
echo ID0gJG1lbnUuSXRlbXMuQWRkKCRtaVN0YXR1cykKJG51bGwgPSAkbWVudS5JdGVt
echo cy5BZGQoKE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuVG9vbFN0cmlw
echo U2VwYXJhdG9yKSkKJG51bGwgPSAkbWVudS5JdGVtcy5BZGQoJG1pU3RhcnQpCiRu
echo dWxsID0gJG1lbnUuSXRlbXMuQWRkKCRtaVN0b3ApCiRudWxsID0gJG1lbnUuSXRl
echo bXMuQWRkKChOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRvb2xTdHJp
echo cFNlcGFyYXRvcikpCiRudWxsID0gJG1lbnUuSXRlbXMuQWRkKCRtaVNpdGUpCiRu
echo dWxsID0gJG1lbnUuSXRlbXMuQWRkKCRtaUF1dG9zdGFydCkKJG51bGwgPSAkbWVu
echo dS5JdGVtcy5BZGQoKE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuVG9v
echo bFN0cmlwU2VwYXJhdG9yKSkKJG51bGwgPSAkbWVudS5JdGVtcy5BZGQoJG1pRXhp
echo dCkKCiRzdGFydHVwTG5rID0gSm9pbi1QYXRoICRlbnY6QVBQREFUQSAnTWljcm9z
echo b2Z0XFdpbmRvd3NcU3RhcnQgTWVudVxQcm9ncmFtc1xTdGFydHVwXEpFVuWIpOWI
echo hueuoeWuti5sbmsnCmZ1bmN0aW9uIFN5bmMtQXV0b3N0YXJ0Q2hlY2sgeyB0cnkg
echo eyAkbWlBdXRvc3RhcnQuQ2hlY2tlZCA9IChUZXN0LVBhdGggJHN0YXJ0dXBMbmsp
echo IH0gY2F0Y2gge30gfQoKJG1pU3RhcnQuYWRkX0NsaWNrKHsgU3RhcnQtSmV2U2Vy
echo dmljZUhpZGRlbiB9KQokbWlTdG9wLmFkZF9DbGljayh7IFN0b3AtSmV2U2Vydmlj
echo ZSB9KQokbWlTaXRlLmFkZF9DbGljayh7IFN0YXJ0LVByb2Nlc3MgJ2h0dHBzOi8v
echo Z2VudWluZWVkdS5wYWdlcy5kZXYnIH0pCiRtaUF1dG9zdGFydC5hZGRfQ2xpY2so
echo ewogIGlmICgkbWlBdXRvc3RhcnQuQ2hlY2tlZCkgewogICAgJFdTID0gTmV3LU9i
echo amVjdCAtQ29tT2JqZWN0IFdTY3JpcHQuU2hlbGwKICAgICRTQyA9ICRXUy5DcmVh
echo dGVTaG9ydGN1dCgkc3RhcnR1cExuaykKICAgICRxID0gW2NoYXJdMzQKICAgICRT
echo Qy5UYXJnZXRQYXRoID0gKEpvaW4tUGF0aCAkZW52OlN5c3RlbVJvb3QgJ1N5c3Rl
echo bTMyXHdzY3JpcHQuZXhlJykKICAgICRTQy5Bcmd1bWVudHMgPSAkcSArIChKb2lu
echo LVBhdGggJGJhc2UgJ3N0YXJ0X2pldl9oaWRkZW4udmJzJykgKyAkcSArICcgdHJh
echo eScKICAgICRTQy5Xb3JraW5nRGlyZWN0b3J5ID0gJGJhc2UKICAgIGlmIChUZXN0
echo LVBhdGggKEpvaW4tUGF0aCAkYmFzZSAnamV2X3J1bi5pY28nKSkgeyAkU0MuSWNv
echo bkxvY2F0aW9uID0gKEpvaW4tUGF0aCAkYmFzZSAnamV2X3J1bi5pY28nKSB9CiAg
echo ICAkU0MuU2F2ZSgpCiAgfSBlbHNlIHsKICAgIFJlbW92ZS1JdGVtICRzdGFydHVw
echo TG5rIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogIH0KICBT
echo eW5jLUF1dG9zdGFydENoZWNrCn0pCiRtaUV4aXQuYWRkX0NsaWNrKHsKICAkdHJh
echo eS5WaXNpYmxlID0gJGZhbHNlCiAgJHRyYXkuRGlzcG9zZSgpCiAgW1N5c3RlbS5X
echo aW5kb3dzLkZvcm1zLkFwcGxpY2F0aW9uXTo6RXhpdCgpCn0pCiRtZW51LmFkZF9P
echo cGVuaW5nKHsgU3luYy1BdXRvc3RhcnRDaGVjayB9KQoKJHRyYXkuQ29udGV4dE1l
echo bnVTdHJpcCA9ICRtZW51CiR0cmF5Lkljb24gPSAkaWNvblN0b3AKJHRyYXkuVGV4
echo dCA9ICdKRVYg5pys5Zyw5Yik5YiG5pyN5YqhJwokdHJheS5hZGRfTW91c2VEb3Vi
echo bGVDbGljayh7IFN0YXJ0LVByb2Nlc3MgJ2h0dHBzOi8vZ2VudWluZWVkdS5wYWdl
echo cy5kZXYnIH0pCiR0cmF5LlZpc2libGUgPSAkdHJ1ZQpTeW5jLUF1dG9zdGFydENo
echo ZWNrCgojID09PT09PT09PT09PT09PT09IOe9kemhteiBlOWKqOebkeWQrO+8iDEy
echo Ny4wLjAuMTo4MDAy77yJID09PT09PT09PT09PT09PT09CiRsaXN0ZW5lciA9ICRu
echo dWxsCnRyeSB7CiAgJGxpc3RlbmVyID0gTmV3LU9iamVjdCBTeXN0ZW0uTmV0LlNv
echo Y2tldHMuVGNwTGlzdGVuZXIoW1N5c3RlbS5OZXQuSVBBZGRyZXNzXTo6TG9vcGJh
echo Y2ssIDgwMDIpCiAgJGxpc3RlbmVyLlN0YXJ0KCkKfSBjYXRjaCB7ICRsaXN0ZW5l
echo ciA9ICRudWxsIH0KCmZ1bmN0aW9uIFNlbmQtSmV2UmVzcG9uc2UoJGNsaWVudCwg
echo JGJvZHkpIHsKICB0cnkgewogICAgJHJlc3AgPSAiSFRUUC8xLjEgMjAwIE9LYHJg
echo bkFjY2Vzcy1Db250cm9sLUFsbG93LU9yaWdpbjogKmByYG5BY2Nlc3MtQ29udHJv
echo bC1BbGxvdy1NZXRob2RzOiBHRVQsIFBPU1QsIE9QVElPTlNgcmBuQWNjZXNzLUNv
echo bnRyb2wtQWxsb3ctSGVhZGVyczogKmByYG5BY2Nlc3MtQ29udHJvbC1BbGxvdy1Q
echo cml2YXRlLU5ldHdvcms6IHRydWVgcmBuQ29udGVudC1UeXBlOiB0ZXh0L3BsYWlu
echo YHJgbkNhY2hlLUNvbnRyb2w6IG5vLXN0b3JlYHJgbkNvbm5lY3Rpb246IGNsb3Nl
echo YHJgbkNvbnRlbnQtTGVuZ3RoOiAkKCRib2R5Lkxlbmd0aClgcmBuYHJgbiRib2R5
echo IgogICAgJGJ5dGVzID0gW1N5c3RlbS5UZXh0LkVuY29kaW5nXTo6QVNDSUkuR2V0
echo Qnl0ZXMoJHJlc3ApCiAgICAkcyA9ICRjbGllbnQuR2V0U3RyZWFtKCkKICAgICRz
echo LldyaXRlKCRieXRlcywgMCwgJGJ5dGVzLkxlbmd0aCkKICAgICRzLkZsdXNoKCkK
echo ICB9IGNhdGNoIHt9CiAgdHJ5IHsgJGNsaWVudC5DbG9zZSgpIH0gY2F0Y2gge30K
echo fQoKJGxpc3RlblRpbWVyID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jt
echo cy5UaW1lcgokbGlzdGVuVGltZXIuSW50ZXJ2YWwgPSAzMDAKJGxpc3RlblRpbWVy
echo LmFkZF9UaWNrKHsKICB0cnkgewogICAgaWYgKC1ub3QgJGxpc3RlbmVyKSB7IHJl
echo dHVybiB9CiAgICB3aGlsZSAoJGxpc3RlbmVyLlBlbmRpbmcoKSkgewogICAgICAk
echo Y2xpZW50ID0gJGxpc3RlbmVyLkFjY2VwdFRjcENsaWVudCgpCiAgICAgICRzdHJl
echo YW0gPSAkY2xpZW50LkdldFN0cmVhbSgpCiAgICAgICRzdHJlYW0uUmVhZFRpbWVv
echo dXQgPSA4MDAKICAgICAgJGJ1ZiA9IE5ldy1PYmplY3QgYnl0ZVtdIDQwOTYKICAg
echo ICAgJG4gPSAwCiAgICAgIHRyeSB7ICRuID0gJHN0cmVhbS5SZWFkKCRidWYsIDAs
echo ICRidWYuTGVuZ3RoKSB9IGNhdGNoIHsgJG4gPSAwIH0KICAgICAgJHJlcSA9IFtT
echo eXN0ZW0uVGV4dC5FbmNvZGluZ106OkFTQ0lJLkdldFN0cmluZygkYnVmLCAwLCAk
echo bikKICAgICAgJGZpcnN0ID0gJHJlcQogICAgICAkaSA9ICRyZXEuSW5kZXhPZigi
echo YHJgbiIpCiAgICAgIGlmICgkaSAtZ3QgMCkgeyAkZmlyc3QgPSAkcmVxLlN1YnN0
echo cmluZygwLCAkaSkgfQoKICAgICAgaWYgKCRmaXJzdCAtbWF0Y2ggJy9waW5nJykg
echo ewogICAgICAgICRzY3JpcHQ6bGFzdFBpbmcgPSBHZXQtRGF0ZQogICAgICAgIGlm
echo ICgoJHNjcmlwdDpydW5uaW5nIC1uZSAkdHJ1ZSkgLWFuZCAoKChHZXQtRGF0ZSkg
echo LSAkc2NyaXB0Omxhc3RTdGFydFRyeSkuVG90YWxTZWNvbmRzIC1ndCAyMCkpIHsK
echo ICAgICAgICAgICRzY3JpcHQ6bGFzdFN0YXJ0VHJ5ID0gR2V0LURhdGUKICAgICAg
echo ICAgIFN0YXJ0LUpldlNlcnZpY2VIaWRkZW4KICAgICAgICAgICR0cmF5LlNob3dC
echo YWxsb29uVGlwKDI1MDAsICdKRVYg5pys5Zyw5Yik5YiG5pyN5YqhJywgJ+ajgOa1
echo i+WIsOe9kemhteaJk+W8gO+8jOato+WcqOWQr+WKqOWIpOWIhuacjeWKoeKApics
echo IFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Ub29sVGlwSWNvbl06OkluZm8pCiAgICAg
echo ICAgfQogICAgICAgIFNlbmQtSmV2UmVzcG9uc2UgJGNsaWVudCAnb2snCiAgICAg
echo IH0gZWxzZWlmICgkZmlyc3QgLW1hdGNoICcvYnllJykgewogICAgICAgIGlmICgk
echo c2NyaXB0Omxhc3RQaW5nIC1uZSBbRGF0ZVRpbWVdOjpNaW5WYWx1ZSkgeyAkc2Ny
echo aXB0Omxhc3RQaW5nID0gJHNjcmlwdDpsYXN0UGluZy5BZGRTZWNvbmRzKC0xNSkg
echo fQogICAgICAgIFNlbmQtSmV2UmVzcG9uc2UgJGNsaWVudCAnb2snCiAgICAgIH0g
echo ZWxzZSB7CiAgICAgICAgU2VuZC1KZXZSZXNwb25zZSAkY2xpZW50ICdvaycKICAg
echo ICAgfQogICAgfQogIH0gY2F0Y2gge30KfSkKJGxpc3RlblRpbWVyLlN0YXJ0KCkK
echo CmlmICgtbm90ICRsaXN0ZW5lcikgewogICR0cmF5LlNob3dCYWxsb29uVGlwKDQw
echo MDAsICdKRVYg5pys5Zyw5Yik5YiG5pyN5YqhJywgJ+e9kemhteiBlOWKqOerr+WP
echo oyA4MDAyIOiiq+WNoOeUqO+8muiHquWKqOaLiei1t+aaguS4jeWPr+eUqO+8iOS4
echo jeW9seWTjeaJi+WKqOWQr+WKqO+8iScsIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5U
echo b29sVGlwSWNvbl06Oldhcm5pbmcpCn0KCiMgPT09PT09PT09PT09PT09PT0g54q2
echo 5oCB6L2u6K+iICsg572R6aG15YWz6Zet6Ieq5Yqo5YGc5q2iID09PT09PT09PT09
echo PT09PT09CiR0aW1lciA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMu
echo VGltZXIKJHRpbWVyLkludGVydmFsID0gMzAwMAokdGltZXIuYWRkX1RpY2soewog
echo IHRyeSB7CiAgICAkbm93ID0gVGVzdC1KZXZSdW5uaW5nCiAgICBpZiAoJG5vdyAt
echo bmUgJHNjcmlwdDpydW5uaW5nKSB7CiAgICAgIGlmICgkbm93KSB7CiAgICAgICAg
echo JHRyYXkuSWNvbiA9ICRpY29uUnVuCiAgICAgICAgJHRyYXkuVGV4dCA9ICdKRVYg
echo 5pys5Zyw5Yik5YiG5pyN5Yqh77ya6L+Q6KGM5LitJwogICAgICAgICRtaVN0YXR1
echo cy5UZXh0ID0gJ+eKtuaAge+8mui/kOihjOS4re+8iOerr+WPoyA4MDAx77yJJwog
echo ICAgICAgICRtaVN0YXJ0LkVuYWJsZWQgPSAkZmFsc2UKICAgICAgICAkbWlTdG9w
echo LkVuYWJsZWQgPSAkdHJ1ZQogICAgICAgIGlmICgkc2NyaXB0OnJ1bm5pbmcgLW5l
echo IC0xKSB7ICR0cmF5LlNob3dCYWxsb29uVGlwKDI1MDAsICdKRVYg5pys5Zyw5Yik
echo 5YiG5pyN5YqhJywgJ+acjeWKoeW3suWQr+WKqCcsIFtTeXN0ZW0uV2luZG93cy5G
echo b3Jtcy5Ub29sVGlwSWNvbl06OkluZm8pIH0KICAgICAgfSBlbHNlIHsKICAgICAg
echo ICAkdHJheS5JY29uID0gJGljb25TdG9wCiAgICAgICAgJHRyYXkuVGV4dCA9ICdK
echo RVYg5pys5Zyw5Yik5YiG5pyN5Yqh77ya5bey5YGc5q2iJwogICAgICAgICRtaVN0
echo YXR1cy5UZXh0ID0gJ+eKtuaAge+8muW3suWBnOatoicKICAgICAgICAkbWlTdGFy
echo dC5FbmFibGVkID0gJHRydWUKICAgICAgICAkbWlTdG9wLkVuYWJsZWQgPSAkZmFs
echo c2UKICAgICAgICBpZiAoJHNjcmlwdDpydW5uaW5nIC1uZSAtMSkgeyAkdHJheS5T
echo aG93QmFsbG9vblRpcCgyNTAwLCAnSkVWIOacrOWcsOWIpOWIhuacjeWKoScsICfm
echo nI3liqHlt7LlgZzmraInLCBbU3lzdGVtLldpbmRvd3MuRm9ybXMuVG9vbFRpcElj
echo b25dOjpXYXJuaW5nKSB9CiAgICAgIH0KICAgICAgJHNjcmlwdDpydW5uaW5nID0g
echo JG5vdwogICAgfQoKICAgIGlmICgoJHNjcmlwdDpsYXN0UGluZyAtbmUgW0RhdGVU
echo aW1lXTo6TWluVmFsdWUpIC1hbmQgJHNjcmlwdDpydW5uaW5nIC1hbmQgKCgoR2V0
echo LURhdGUpIC0gJHNjcmlwdDpsYXN0UGluZykuVG90YWxTZWNvbmRzIC1ndCAkaGVh
echo cnRiZWF0VGltZW91dFNlYykpIHsKICAgICAgU3RvcC1KZXZTZXJ2aWNlCiAgICAg
echo ICRzY3JpcHQ6bGFzdFBpbmcgPSBbRGF0ZVRpbWVdOjpNaW5WYWx1ZQogICAgICAk
echo dHJheS5TaG93QmFsbG9vblRpcCgyNTAwLCAnSkVWIOacrOWcsOWIpOWIhuacjeWK
echo oScsICfnvZHpobXlt7LlhbPpl63vvIzliKTliIbmnI3liqHoh6rliqjlgZzmraLv
echo vIjph4rmlL7lhoXlrZjvvIknLCBbU3lzdGVtLldpbmRvd3MuRm9ybXMuVG9vbFRp
echo cEljb25dOjpJbmZvKQogICAgfQogIH0gY2F0Y2gge30KfSkKJHRpbWVyLlN0YXJ0
echo KCkKCltTeXN0ZW0uV2luZG93cy5Gb3Jtcy5BcHBsaWNhdGlvbl06OlJ1bigpCgp9
echo IGNhdGNoIHsKICAoJF8gfCBPdXQtU3RyaW5nKSB8IEFkZC1Db250ZW50IC1QYXRo
echo IChKb2luLVBhdGggJGJhc2UgJ3RyYXlfZXJyb3IubG9nJykgLUVuY29kaW5nIFVU
echo RjgKfQo=
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

:: 托盘管家开机自启（可在托盘菜单里关闭；测试模式跳过）
if not "%JEV_TEST_DIR%"=="" goto skip_autostart2
powershell -NoProfile -Command "$WS=New-Object -ComObject WScript.Shell; $SC=$WS.CreateShortcut((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\JEV判分管家.lnk')); $q=[char]34; $SC.TargetPath=(Join-Path $env:SystemRoot 'System32\wscript.exe'); $SC.Arguments=$q+'%INSTALL_DIR%\start_jev_hidden.vbs'+$q+' tray'; $SC.WorkingDirectory='%INSTALL_DIR%'; $SC.IconLocation='%INSTALL_DIR%\jev_run.ico'; $SC.Save()" 2>nul
:skip_autostart2
echo         完成
echo.

echo ==================================================================
echo    安装完成！
echo ==================================================================
echo.
echo   使用方法：
echo     1. 打开背词网站会自动启动判分服务（几秒就绪）；关闭网页约 1 分钟后自动停止
echo     2. 托盘区 JEV 管家图标：查看状态、手动开/关、开机自启开关、退出托盘
echo     3. 若没自动起来：点网页顶部「启动判分服务」按钮兜底
echo.
echo   如果浏览器询问「是否允许访问本地网络/设备」，请点允许。
echo   服务地址：http://127.0.0.1:8001
echo ==================================================================
echo.
set "SN="
set /p SN=是否立即启动判分服务与托盘管家？(Y/N): 
if /i not "%SN%"=="Y" goto the_end
"%SystemRoot%\System32\wscript.exe" "%INSTALL_DIR%\start_jev_hidden.vbs"
echo         服务与托盘管家已在后台运行

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
