#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从国内镜像下载 JEV 模型
支持 HuggingFace 镜像、GitHub 加速等多个源
"""

import os
import sys
import time
import requests
from pathlib import Path

# 目标文件信息
MODEL_REPO = "chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF"
MODEL_FILE = "Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
EXPECTED_SIZE = 530_000_000  # 约 530 MB

# 镜像源列表（按优先级排序）
MIRRORS = [
    {
        "name": "HF-Mirror (国内主镜像)",
        "url": f"https://hf-mirror.com/{MODEL_REPO}/resolve/main/{MODEL_FILE}",
        "type": "hf"
    },
    {
        "name": "HuggingFace 官方",
        "url": f"https://huggingface.co/{MODEL_REPO}/resolve/main/{MODEL_FILE}",
        "type": "official"
    },
    {
        "name": "GitHub 加速 (ghproxy)",
        "url": f"https://ghproxy.com/https://huggingface.co/{MODEL_REPO}/resolve/main/{MODEL_FILE}",
        "type": "proxy"
    }
]

def format_size(bytes_size):
    """格式化文件大小"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024:
            return f"{bytes_size:.2f} {unit}"
        bytes_size /= 1024
    return f"{bytes_size:.2f} TB"

def test_mirror(mirror):
    """测试镜像源是否可用"""
    try:
        print(f"  测试 {mirror['name']}...", end=" ", flush=True)
        response = requests.head(mirror['url'], timeout=10, allow_redirects=True)
        if response.status_code == 200:
            size = int(response.headers.get('Content-Length', 0))
            print(f"✓ 可用 ({format_size(size)})")
            return True, size
        else:
            print(f"✗ HTTP {response.status_code}")
            return False, 0
    except Exception as e:
        print(f"✗ {str(e)[:50]}")
        return False, 0

def download_file(url, output_path, mirror_name):
    """下载文件（支持断点续传）"""
    output_path = Path(output_path)
    temp_path = output_path.with_suffix(output_path.suffix + '.downloading')
    
    # 检查已下载大小
    downloaded_size = 0
    if temp_path.exists():
        downloaded_size = temp_path.stat().st_size
        print(f"  检测到未完成的下载，从 {format_size(downloaded_size)} 处继续...")
    
    headers = {}
    if downloaded_size > 0:
        headers['Range'] = f'bytes={downloaded_size}-'
    
    try:
        print(f"\n开始下载: {mirror_name}")
        print(f"目标文件: {output_path}")
        
        response = requests.get(url, headers=headers, stream=True, timeout=30)
        response.raise_for_status()
        
        total_size = int(response.headers.get('Content-Length', 0)) + downloaded_size
        
        mode = 'ab' if downloaded_size > 0 else 'wb'
        with open(temp_path, mode) as f:
            start_time = time.time()
            last_print = start_time
            
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded_size += len(chunk)
                    
                    # 每秒更新一次进度
                    now = time.time()
                    if now - last_print >= 1.0:
                        elapsed = now - start_time
                        speed = downloaded_size / elapsed if elapsed > 0 else 0
                        progress = (downloaded_size / total_size * 100) if total_size > 0 else 0
                        
                        print(f"\r  进度: {progress:.1f}% | "
                              f"{format_size(downloaded_size)}/{format_size(total_size)} | "
                              f"速度: {format_size(speed)}/s", end="", flush=True)
                        last_print = now
        
        print()  # 换行
        
        # 验证文件大小
        final_size = temp_path.stat().st_size
        if total_size > 0 and final_size != total_size:
            print(f"✗ 下载不完整: {format_size(final_size)}/{format_size(total_size)}")
            return False
        
        # 重命名为最终文件
        if output_path.exists():
            output_path.unlink()
        temp_path.rename(output_path)
        
        print(f"✓ 下载成功: {format_size(final_size)}")
        return True
        
    except KeyboardInterrupt:
        print("\n\n用户中断下载（已下载的部分已保存，重新运行可继续）")
        return False
    except Exception as e:
        print(f"\n✗ 下载失败: {e}")
        return False

def main():
    # 确定输出目录
    script_dir = Path(__file__).parent
    jev_dir = script_dir / "jev"
    jev_dir.mkdir(exist_ok=True)
    
    output_file = jev_dir / MODEL_FILE
    
    # 检查文件是否已存在
    if output_file.exists():
        size = output_file.stat().st_size
        print(f"模型文件已存在: {output_file}")
        print(f"文件大小: {format_size(size)}")
        
        if abs(size - EXPECTED_SIZE) < 1_000_000:  # 1MB 误差内
            print("✓ 文件大小正常，无需重新下载")
            return 0
        else:
            print("⚠ 文件大小异常，将重新下载")
    
    print("\n正在测试镜像源可用性...\n")
    
    # 测试所有镜像源
    available_mirrors = []
    for mirror in MIRRORS:
        ok, size = test_mirror(mirror)
        if ok:
            available_mirrors.append((mirror, size))
    
    if not available_mirrors:
        print("\n✗ 所有镜像源均不可用")
        print("建议:")
        print("  1. 检查网络连接")
        print("  2. 如果可以科学上网，请开启后重试")
        print("  3. 手动从 HuggingFace 下载后放到 jev/ 目录")
        return 1
    
    print(f"\n找到 {len(available_mirrors)} 个可用镜像源\n")
    
    # 依次尝试下载
    for i, (mirror, size) in enumerate(available_mirrors, 1):
        print(f"[{i}/{len(available_mirrors)}] 尝试从 {mirror['name']} 下载")
        
        if download_file(mirror['url'], output_file, mirror['name']):
            print("\n" + "="*60)
            print("下载完成！")
            print(f"模型文件: {output_file}")
            print(f"文件大小: {format_size(output_file.stat().st_size)}")
            print("="*60)
            return 0
        
        if i < len(available_mirrors):
            print(f"\n尝试下一个镜像源...\n")
    
    print("\n✗ 所有镜像源下载均失败")
    return 1

if __name__ == "__main__":
    sys.exit(main())
