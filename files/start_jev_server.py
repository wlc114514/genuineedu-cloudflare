#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
JEV 服务跨平台启动脚本
支持 Windows / macOS (Intel & Apple Silicon) / Linux
自动检测平台并选择最优配置
"""

import sys
import os
import platform
import subprocess
from pathlib import Path

def get_llama_server_path():
    """根据平台返回 llama-server 路径"""
    system = platform.system()
    script_dir = Path(__file__).parent
    
    if system == "Windows":
        return script_dir / "jev/llama/llama-server.exe"
    elif system == "Darwin":  # macOS
        return script_dir / "jev/llama/llama-server"
    else:  # Linux
        return script_dir / "jev/llama/llama-server"

def is_apple_silicon():
    """检测是否为 Apple Silicon"""
    if platform.system() != "Darwin":
        return False
    return platform.machine() == "arm64"

def check_llama_cpp_installed():
    """检查系统是否安装了 llama.cpp (Homebrew)"""
    try:
        result = subprocess.run(
            ["which", "llama-server"],
            capture_output=True,
            text=True,
            check=False
        )
        return result.returncode == 0
    except:
        return False

def start_server():
    script_dir = Path(__file__).parent
    model_path = script_dir / "jev/Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
    
    # 检查模型文件
    if not model_path.exists():
        print(f"错误: 找不到模型文件: {model_path}")
        print("\n请先运行: python download_jev_from_mirror.py")
        return 1
    
    # 确定使用哪个 llama-server
    server_path = get_llama_server_path()
    use_system_llama = False
    
    if not server_path.exists():
        # 本地没有，检查系统是否安装了
        if check_llama_cpp_installed():
            print("本地未找到 llama-server，使用系统安装的版本 (Homebrew)")
            server_path = "llama-server"  # 使用系统 PATH 中的
            use_system_llama = True
        else:
            print(f"错误: 找不到 llama-server")
            print(f"期望位置: {server_path}")
            print("\nmacOS/Linux 用户可以通过以下方式安装:")
            print("  brew install llama.cpp")
            print("\nWindows 用户请确保 jev/llama/llama-server.exe 存在")
            return 1
    
    # 根据平台选择参数
    ngl = "99" if is_apple_silicon() else "0"
    
    cmd = [
        str(server_path),
        "-m", str(model_path),
        "--port", "8001",
        "-ngl", ngl,
        "-c", "2048",
        "--host", "127.0.0.1"  # 只监听本地，安全
    ]
    
    print("="*70)
    print("JEV 判分服务启动中...")
    print("="*70)
    print(f"平台: {platform.system()} {platform.machine()}")
    print(f"llama-server: {'系统安装' if use_system_llama else '本地'}")
    print(f"模型: {model_path.name}")
    print(f"GPU 加速: {'✓ Metal (Apple Silicon)' if ngl == '99' else '✗ 纯 CPU'}")
    print(f"监听: http://127.0.0.1:8001")
    print("="*70)
    
    if is_apple_silicon():
        print("\n提示: 检测到 Apple Silicon，已启用 Metal GPU 加速")
        print("      如果遇到问题，可以手动禁用 GPU: 修改 -ngl 99 为 -ngl 0\n")
    
    print("按 Ctrl+C 停止服务\n")
    
    try:
        subprocess.run(cmd, check=True)
    except KeyboardInterrupt:
        print("\n\n服务已停止")
        return 0
    except subprocess.CalledProcessError as e:
        print(f"\n启动失败 (退出码 {e.returncode})")
        return 1
    except FileNotFoundError:
        print(f"\n错误: 找不到可执行文件: {server_path}")
        return 1
    except Exception as e:
        print(f"\n意外错误: {e}")
        return 1

def show_status():
    """显示服务状态"""
    import socket
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(1)
    result = sock.connect_ex(('127.0.0.1', 8001))
    sock.close()
    
    if result == 0:
        print("✓ JEV 服务正在运行 (http://127.0.0.1:8001)")
        return 0
    else:
        print("✗ JEV 服务未运行")
        return 1

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "status":
        sys.exit(show_status())
    
    sys.exit(start_server())
