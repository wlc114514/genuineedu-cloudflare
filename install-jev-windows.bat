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
echo raLmnI3liqHjgIHmiZPlvIDnvZHnq5njgIHpgIDlh7rmiZjnm5jjgIIKIyAgMikg
echo 55uR5ZCsIDEyNy4wLjAuMTo4MDAy77ya572R6aG15omT5byA5pe255qE5b+D6Lez
echo 77yIL3BpbmfvvInoh6rliqjmi4notbfliKTliIbmnI3liqHvvJsKIyAgICAg572R
echo 6aG15YWo6YOo5YWz6Zet5ZCO5b+D6Lez5raI5aSx57qmIDc1IOenku+8jOiHquWK
echo qOWBnOatouacjeWKoe+8iOmHiuaUvuWGheWtmO+8ieOAggojIOeUseWuieijheWZ
echo qOeUn+aIkO+8jOaXoOmcgOeuoeeQhuWRmOadg+mZkOOAggokRXJyb3JBY3Rpb25Q
echo cmVmZXJlbmNlID0gJ1NpbGVudGx5Q29udGludWUnCiRQcm9ncmVzc1ByZWZlcmVu
echo Y2UgPSAnU2lsZW50bHlDb250aW51ZScKCiMgLS0tLSDljZXlrp7kvovkv53miqQg
echo LS0tLQokY3JlYXRlZE5ldyA9ICRmYWxzZQokbXV0ZXggPSBOZXctT2JqZWN0IFN5
echo c3RlbS5UaHJlYWRpbmcuTXV0ZXgoJHRydWUsICdMb2NhbFxKRVZfVHJheV9Db250
echo cm9sbGVyJywgW3JlZl0kY3JlYXRlZE5ldykKaWYgKC1ub3QgJGNyZWF0ZWROZXcp
echo IHsgZXhpdCB9CgokYmFzZSA9IFNwbGl0LVBhdGggLVBhcmVudCAkTXlJbnZvY2F0
echo aW9uLk15Q29tbWFuZC5QYXRoCgp0cnkgewoKQWRkLVR5cGUgLUFzc2VtYmx5TmFt
echo ZSBTeXN0ZW0uV2luZG93cy5Gb3JtcwpBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5
echo c3RlbS5EcmF3aW5nCgojID09PT09PT09PT09PT09PT09IOWfuuehgOWHveaVsCA9
echo PT09PT09PT09PT09PT09PQpmdW5jdGlvbiBUZXN0LUpldlJ1bm5pbmcgewogIHRy
echo eSB7CiAgICAkciA9IEludm9rZS1XZWJSZXF1ZXN0IC1VcmkgJ2h0dHA6Ly8xMjcu
echo MC4wLjE6ODAwMS9oZWFsdGgnIC1UaW1lb3V0U2VjIDIgLVVzZUJhc2ljUGFyc2lu
echo ZwogICAgcmV0dXJuICgkci5TdGF0dXNDb2RlIC1lcSAyMDApCiAgfSBjYXRjaCB7
echo IHJldHVybiAkZmFsc2UgfQp9CgpmdW5jdGlvbiBTdG9wLUpldlNlcnZpY2Ugewog
echo ICRwID0gKEdldC1OZXRUQ1BDb25uZWN0aW9uIC1Mb2NhbFBvcnQgODAwMSAtU3Rh
echo dGUgTGlzdGVuIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgU2VsZWN0
echo LU9iamVjdCAtRmlyc3QgMSkuT3duaW5nUHJvY2VzcwogIGlmICgkcCkgeyBTdG9w
echo LVByb2Nlc3MgLUlkICRwIC1Gb3JjZSB9Cn0KCmZ1bmN0aW9uIFN0YXJ0LUpldlNl
echo cnZpY2VIaWRkZW4gewogIFN0YXJ0LVByb2Nlc3MgLUZpbGVQYXRoIChKb2luLVBh
echo dGggJGVudjpTeXN0ZW1Sb290ICdTeXN0ZW0zMlx3c2NyaXB0LmV4ZScpIC1Bcmd1
echo bWVudExpc3QgKCciJyArIChKb2luLVBhdGggJGJhc2UgJ3N0YXJ0X2pldl9oaWRk
echo ZW4udmJzJykgKyAnIicpIC1XaW5kb3dTdHlsZSBIaWRkZW4KfQoKIyA9PT09PT09
echo PT09PT09PT09PSDnirbmgIEgPT09PT09PT09PT09PT09PT0KJHNjcmlwdDpydW5u
echo aW5nID0gLTEgICAgICAgICAgIyAtMSA9IOacquefpe+8iOmmlui9ruS4jeW8uemA
echo muefpe+8iQokc2NyaXB0Omxhc3RQaW5nID0gW0RhdGVUaW1lXTo6TWluVmFsdWUK
echo JHNjcmlwdDpsYXN0U3RhcnRUcnkgPSBbRGF0ZVRpbWVdOjpNaW5WYWx1ZQokaGVh
echo cnRiZWF0VGltZW91dFNlYyA9IDc1Cgp0cnkgeyAkaWNvblJ1biA9IE5ldy1PYmpl
echo Y3QgU3lzdGVtLkRyYXdpbmcuSWNvbiAoSm9pbi1QYXRoICRiYXNlICdqZXZfcnVu
echo LmljbycpIH0gY2F0Y2ggeyAkaWNvblJ1biA9IFtTeXN0ZW0uRHJhd2luZy5TeXN0
echo ZW1JY29uc106OkFwcGxpY2F0aW9uIH0KdHJ5IHsgJGljb25TdG9wID0gTmV3LU9i
echo amVjdCBTeXN0ZW0uRHJhd2luZy5JY29uIChKb2luLVBhdGggJGJhc2UgJ2pldl9z
echo dG9wLmljbycpIH0gY2F0Y2ggeyAkaWNvblN0b3AgPSBbU3lzdGVtLkRyYXdpbmcu
echo U3lzdGVtSWNvbnNdOjpBcHBsaWNhdGlvbiB9CgojID09PT09PT09PT09PT09PT09
echo IOaJmOebmCBVSSA9PT09PT09PT09PT09PT09PQokdHJheSA9IE5ldy1PYmplY3Qg
echo U3lzdGVtLldpbmRvd3MuRm9ybXMuTm90aWZ5SWNvbgokbWVudSA9IE5ldy1PYmpl
echo Y3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuQ29udGV4dE1lbnVTdHJpcAoKJG1pU3Rh
echo dHVzID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Ub29sU3RyaXBN
echo ZW51SXRlbSAn54q25oCB77ya5qOA5rWL5LitLi4uJwokbWlTdGF0dXMuRW5hYmxl
echo ZCA9ICRmYWxzZQokbWlTdGFydCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3Mu
echo Rm9ybXMuVG9vbFN0cmlwTWVudUl0ZW0gJ+WQr+WKqOacjeWKoScKJG1pU3RvcCAg
echo PSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRvb2xTdHJpcE1lbnVJ
echo dGVtICflgZzmraLmnI3liqEnCiRtaVNpdGUgID0gTmV3LU9iamVjdCBTeXN0ZW0u
echo V2luZG93cy5Gb3Jtcy5Ub29sU3RyaXBNZW51SXRlbSAn5omT5byA6IOM6K+N572R
echo 56uZJwokbWlFeGl0ICA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMu
echo VG9vbFN0cmlwTWVudUl0ZW0gJ+mAgOWHuuaJmOebmCcKCiRudWxsID0gJG1lbnUu
echo SXRlbXMuQWRkKCRtaVN0YXR1cykKJG51bGwgPSAkbWVudS5JdGVtcy5BZGQoKE5l
echo dy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuVG9vbFN0cmlwU2VwYXJhdG9y
echo KSkKJG51bGwgPSAkbWVudS5JdGVtcy5BZGQoJG1pU3RhcnQpCiRudWxsID0gJG1l
echo bnUuSXRlbXMuQWRkKCRtaVN0b3ApCiRudWxsID0gJG1lbnUuSXRlbXMuQWRkKChO
echo ZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRvb2xTdHJpcFNlcGFyYXRv
echo cikpCiRudWxsID0gJG1lbnUuSXRlbXMuQWRkKCRtaVNpdGUpCiRudWxsID0gJG1l
echo bnUuSXRlbXMuQWRkKChOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRv
echo b2xTdHJpcFNlcGFyYXRvcikpCiRudWxsID0gJG1lbnUuSXRlbXMuQWRkKCRtaUV4
echo aXQpCgokbWlTdGFydC5hZGRfQ2xpY2soeyBTdGFydC1KZXZTZXJ2aWNlSGlkZGVu
echo IH0pCiRtaVN0b3AuYWRkX0NsaWNrKHsgU3RvcC1KZXZTZXJ2aWNlIH0pCiRtaVNp
echo dGUuYWRkX0NsaWNrKHsgU3RhcnQtUHJvY2VzcyAnaHR0cHM6Ly9nZW51aW5lZWR1
echo LnBhZ2VzLmRldicgfSkKJG1pRXhpdC5hZGRfQ2xpY2soewogICR0cmF5LlZpc2li
echo bGUgPSAkZmFsc2UKICAkdHJheS5EaXNwb3NlKCkKICBbU3lzdGVtLldpbmRvd3Mu
echo Rm9ybXMuQXBwbGljYXRpb25dOjpFeGl0KCkKfSkKCiR0cmF5LkNvbnRleHRNZW51
echo U3RyaXAgPSAkbWVudQokdHJheS5JY29uID0gJGljb25TdG9wCiR0cmF5LlRleHQg
echo PSAnSkVWIOacrOWcsOWIpOWIhuacjeWKoScKJHRyYXkuYWRkX01vdXNlRG91Ymxl
echo Q2xpY2soeyBTdGFydC1Qcm9jZXNzICdodHRwczovL2dlbnVpbmVlZHUucGFnZXMu
echo ZGV2JyB9KQokdHJheS5WaXNpYmxlID0gJHRydWUKCiMgPT09PT09PT09PT09PT09
echo PT0g572R6aG16IGU5Yqo55uR5ZCs77yIMTI3LjAuMC4xOjgwMDLvvIkgPT09PT09
echo PT09PT09PT09PT0KJGxpc3RlbmVyID0gJG51bGwKdHJ5IHsKICAkbGlzdGVuZXIg
echo PSBOZXctT2JqZWN0IFN5c3RlbS5OZXQuU29ja2V0cy5UY3BMaXN0ZW5lcihbU3lz
echo dGVtLk5ldC5JUEFkZHJlc3NdOjpMb29wYmFjaywgODAwMikKICAkbGlzdGVuZXIu
echo U3RhcnQoKQp9IGNhdGNoIHsgJGxpc3RlbmVyID0gJG51bGwgfQoKZnVuY3Rpb24g
echo U2VuZC1KZXZSZXNwb25zZSgkY2xpZW50LCAkYm9keSkgewogIHRyeSB7CiAgICAk
echo cmVzcCA9ICJIVFRQLzEuMSAyMDAgT0tgcmBuQWNjZXNzLUNvbnRyb2wtQWxsb3ct
echo T3JpZ2luOiAqYHJgbkFjY2Vzcy1Db250cm9sLUFsbG93LU1ldGhvZHM6IEdFVCwg
echo UE9TVCwgT1BUSU9OU2ByYG5BY2Nlc3MtQ29udHJvbC1BbGxvdy1IZWFkZXJzOiAq
echo YHJgbkFjY2Vzcy1Db250cm9sLUFsbG93LVByaXZhdGUtTmV0d29yazogdHJ1ZWBy
echo YG5Db250ZW50LVR5cGU6IHRleHQvcGxhaW5gcmBuQ2FjaGUtQ29udHJvbDogbm8t
echo c3RvcmVgcmBuQ29ubmVjdGlvbjogY2xvc2VgcmBuQ29udGVudC1MZW5ndGg6ICQo
echo JGJvZHkuTGVuZ3RoKWByYG5gcmBuJGJvZHkiCiAgICAkYnl0ZXMgPSBbU3lzdGVt
echo LlRleHQuRW5jb2RpbmddOjpBU0NJSS5HZXRCeXRlcygkcmVzcCkKICAgICRzID0g
echo JGNsaWVudC5HZXRTdHJlYW0oKQogICAgJHMuV3JpdGUoJGJ5dGVzLCAwLCAkYnl0
echo ZXMuTGVuZ3RoKQogICAgJHMuRmx1c2goKQogIH0gY2F0Y2gge30KICB0cnkgeyAk
echo Y2xpZW50LkNsb3NlKCkgfSBjYXRjaCB7fQp9CgokbGlzdGVuVGltZXIgPSBOZXct
echo T2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRpbWVyCiRsaXN0ZW5UaW1lci5J
echo bnRlcnZhbCA9IDMwMAokbGlzdGVuVGltZXIuYWRkX1RpY2soewogIHRyeSB7CiAg
echo ICBpZiAoLW5vdCAkbGlzdGVuZXIpIHsgcmV0dXJuIH0KICAgIHdoaWxlICgkbGlz
echo dGVuZXIuUGVuZGluZygpKSB7CiAgICAgICRjbGllbnQgPSAkbGlzdGVuZXIuQWNj
echo ZXB0VGNwQ2xpZW50KCkKICAgICAgJHN0cmVhbSA9ICRjbGllbnQuR2V0U3RyZWFt
echo KCkKICAgICAgJHN0cmVhbS5SZWFkVGltZW91dCA9IDgwMAogICAgICAkYnVmID0g
echo TmV3LU9iamVjdCBieXRlW10gNDA5NgogICAgICAkbiA9IDAKICAgICAgdHJ5IHsg
echo JG4gPSAkc3RyZWFtLlJlYWQoJGJ1ZiwgMCwgJGJ1Zi5MZW5ndGgpIH0gY2F0Y2gg
echo eyAkbiA9IDAgfQogICAgICAkcmVxID0gW1N5c3RlbS5UZXh0LkVuY29kaW5nXTo6
echo QVNDSUkuR2V0U3RyaW5nKCRidWYsIDAsICRuKQogICAgICAkZmlyc3QgPSAkcmVx
echo CiAgICAgICRpID0gJHJlcS5JbmRleE9mKCJgcmBuIikKICAgICAgaWYgKCRpIC1n
echo dCAwKSB7ICRmaXJzdCA9ICRyZXEuU3Vic3RyaW5nKDAsICRpKSB9CgogICAgICBp
echo ZiAoJGZpcnN0IC1tYXRjaCAnL3BpbmcnKSB7CiAgICAgICAgJHNjcmlwdDpsYXN0
echo UGluZyA9IEdldC1EYXRlCiAgICAgICAgaWYgKCgkc2NyaXB0OnJ1bm5pbmcgLW5l
echo ICR0cnVlKSAtYW5kICgoKEdldC1EYXRlKSAtICRzY3JpcHQ6bGFzdFN0YXJ0VHJ5
echo KS5Ub3RhbFNlY29uZHMgLWd0IDIwKSkgewogICAgICAgICAgJHNjcmlwdDpsYXN0
echo U3RhcnRUcnkgPSBHZXQtRGF0ZQogICAgICAgICAgU3RhcnQtSmV2U2VydmljZUhp
echo ZGRlbgogICAgICAgICAgJHRyYXkuU2hvd0JhbGxvb25UaXAoMjUwMCwgJ0pFViDm
echo nKzlnLDliKTliIbmnI3liqEnLCAn5qOA5rWL5Yiw572R6aG15omT5byA77yM5q2j
echo 5Zyo5ZCv5Yqo5Yik5YiG5pyN5Yqh4oCmJywgW1N5c3RlbS5XaW5kb3dzLkZvcm1z
echo LlRvb2xUaXBJY29uXTo6SW5mbykKICAgICAgICB9CiAgICAgICAgU2VuZC1KZXZS
echo ZXNwb25zZSAkY2xpZW50ICdvaycKICAgICAgfSBlbHNlaWYgKCRmaXJzdCAtbWF0
echo Y2ggJy9ieWUnKSB7CiAgICAgICAgaWYgKCRzY3JpcHQ6bGFzdFBpbmcgLW5lIFtE
echo YXRlVGltZV06Ok1pblZhbHVlKSB7ICRzY3JpcHQ6bGFzdFBpbmcgPSAkc2NyaXB0
echo Omxhc3RQaW5nLkFkZFNlY29uZHMoLTE1KSB9CiAgICAgICAgU2VuZC1KZXZSZXNw
echo b25zZSAkY2xpZW50ICdvaycKICAgICAgfSBlbHNlIHsKICAgICAgICBTZW5kLUpl
echo dlJlc3BvbnNlICRjbGllbnQgJ29rJwogICAgICB9CiAgICB9CiAgfSBjYXRjaCB7
echo fQp9KQokbGlzdGVuVGltZXIuU3RhcnQoKQoKaWYgKC1ub3QgJGxpc3RlbmVyKSB7
echo CiAgJHRyYXkuU2hvd0JhbGxvb25UaXAoNDAwMCwgJ0pFViDmnKzlnLDliKTliIbm
echo nI3liqEnLCAn572R6aG16IGU5Yqo56uv5Y+jIDgwMDIg6KKr5Y2g55So77ya6Ieq
echo 5Yqo5ouJ6LW35pqC5LiN5Y+v55So77yI5LiN5b2x5ZON5omL5Yqo5ZCv5Yqo77yJ
echo JywgW1N5c3RlbS5XaW5kb3dzLkZvcm1zLlRvb2xUaXBJY29uXTo6V2FybmluZykK
echo fQoKIyA9PT09PT09PT09PT09PT09PSDnirbmgIHova7or6IgKyDnvZHpobXlhbPp
echo l63oh6rliqjlgZzmraIgPT09PT09PT09PT09PT09PT0KJHRpbWVyID0gTmV3LU9i
echo amVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5UaW1lcgokdGltZXIuSW50ZXJ2YWwg
echo PSAzMDAwCiR0aW1lci5hZGRfVGljayh7CiAgdHJ5IHsKICAgICRub3cgPSBUZXN0
echo LUpldlJ1bm5pbmcKICAgIGlmICgkbm93IC1uZSAkc2NyaXB0OnJ1bm5pbmcpIHsK
echo ICAgICAgaWYgKCRub3cpIHsKICAgICAgICAkdHJheS5JY29uID0gJGljb25SdW4K
echo ICAgICAgICAkdHJheS5UZXh0ID0gJ0pFViDmnKzlnLDliKTliIbmnI3liqHvvJro
echo v5DooYzkuK0nCiAgICAgICAgJG1pU3RhdHVzLlRleHQgPSAn54q25oCB77ya6L+Q
echo 6KGM5Lit77yI56uv5Y+jIDgwMDHvvIknCiAgICAgICAgJG1pU3RhcnQuRW5hYmxl
echo ZCA9ICRmYWxzZQogICAgICAgICRtaVN0b3AuRW5hYmxlZCA9ICR0cnVlCiAgICAg
echo ICAgaWYgKCRzY3JpcHQ6cnVubmluZyAtbmUgLTEpIHsgJHRyYXkuU2hvd0JhbGxv
echo b25UaXAoMjUwMCwgJ0pFViDmnKzlnLDliKTliIbmnI3liqEnLCAn5pyN5Yqh5bey
echo 5ZCv5YqoJywgW1N5c3RlbS5XaW5kb3dzLkZvcm1zLlRvb2xUaXBJY29uXTo6SW5m
echo bykgfQogICAgICB9IGVsc2UgewogICAgICAgICR0cmF5Lkljb24gPSAkaWNvblN0
echo b3AKICAgICAgICAkdHJheS5UZXh0ID0gJ0pFViDmnKzlnLDliKTliIbmnI3liqHv
echo vJrlt7LlgZzmraInCiAgICAgICAgJG1pU3RhdHVzLlRleHQgPSAn54q25oCB77ya
echo 5bey5YGc5q2iJwogICAgICAgICRtaVN0YXJ0LkVuYWJsZWQgPSAkdHJ1ZQogICAg
echo ICAgICRtaVN0b3AuRW5hYmxlZCA9ICRmYWxzZQogICAgICAgIGlmICgkc2NyaXB0
echo OnJ1bm5pbmcgLW5lIC0xKSB7ICR0cmF5LlNob3dCYWxsb29uVGlwKDI1MDAsICdK
echo RVYg5pys5Zyw5Yik5YiG5pyN5YqhJywgJ+acjeWKoeW3suWBnOatoicsIFtTeXN0
echo ZW0uV2luZG93cy5Gb3Jtcy5Ub29sVGlwSWNvbl06Oldhcm5pbmcpIH0KICAgICAg
echo fQogICAgICAkc2NyaXB0OnJ1bm5pbmcgPSAkbm93CiAgICB9CgogICAgaWYgKCgk
echo c2NyaXB0Omxhc3RQaW5nIC1uZSBbRGF0ZVRpbWVdOjpNaW5WYWx1ZSkgLWFuZCAk
echo c2NyaXB0OnJ1bm5pbmcgLWFuZCAoKChHZXQtRGF0ZSkgLSAkc2NyaXB0Omxhc3RQ
echo aW5nKS5Ub3RhbFNlY29uZHMgLWd0ICRoZWFydGJlYXRUaW1lb3V0U2VjKSkgewog
echo ICAgICBTdG9wLUpldlNlcnZpY2UKICAgICAgJHNjcmlwdDpsYXN0UGluZyA9IFtE
echo YXRlVGltZV06Ok1pblZhbHVlCiAgICAgICR0cmF5LlNob3dCYWxsb29uVGlwKDI1
echo MDAsICdKRVYg5pys5Zyw5Yik5YiG5pyN5YqhJywgJ+e9kemhteW3suWFs+mXre+8
echo jOWIpOWIhuacjeWKoeiHquWKqOWBnOatou+8iOmHiuaUvuWGheWtmO+8iScsIFtT
echo eXN0ZW0uV2luZG93cy5Gb3Jtcy5Ub29sVGlwSWNvbl06OkluZm8pCiAgICB9CiAg
echo fSBjYXRjaCB7fQp9KQokdGltZXIuU3RhcnQoKQoKW1N5c3RlbS5XaW5kb3dzLkZv
echo cm1zLkFwcGxpY2F0aW9uXTo6UnVuKCkKCn0gY2F0Y2ggewogICgkXyB8IE91dC1T
echo dHJpbmcpIHwgQWRkLUNvbnRlbnQgLVBhdGggKEpvaW4tUGF0aCAkYmFzZSAndHJh
echo eV9lcnJvci5sb2cnKSAtRW5jb2RpbmcgVVRGOAp9Cg==
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
echo     1. 打开背词网站会自动启动判分服务（几秒就绪）；关闭网页约 1 分钟后自动停止
echo     2. 托盘区 JEV 管家图标：查看状态、手动开/关、打开网站、退出托盘
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
