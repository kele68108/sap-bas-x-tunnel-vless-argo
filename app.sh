#!/bin/bash
# ==========================================
# [NEXUS_ULTRA_V4] 赛博先知 绝对防弹版 (绕开 GitHub API 封锁)
# ==========================================

if [ -z "$CF_TOKEN" ]; then
    echo "[!!FATAL!!] 核心密钥缺失！请确保 CF_TOKEN 已注入。"
    exit 1
fi

WORK_DIR="/home/user/projects/ai_core"
MODEL_NAME="gemma-2-9b-it-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/bartowski/gemma-2-9b-it-GGUF/resolve/main/gemma-2-9b-it-Q4_K_M.gguf"
RAM_DISK="/dev/shm"

mkdir -p $WORK_DIR
cd $WORK_DIR

# 1. 抓取探针与引擎核心
echo "[NEXUS] 正在获取穿透探针与引擎核心..."
if [ ! -f "cloudflared" ]; then
    wget -qO cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared
fi

if [ ! -f "llama-server" ]; then
    echo "[NEXUS] 启用高可靠直连通道，下载稳定版引擎..."
    # 彻底弃用 API 动态抓取，直接写死一个经过检验的稳定版 (b4618)，保证 100% 下载成功！
    STABLE_LLAMA_URL="https://github.com/ggerganov/llama.cpp/releases/download/b4618/llama-b4618-bin-ubuntu-x64.zip"
    wget -qO llama.zip "$STABLE_LLAMA_URL"
    
    # 静默解压并清理
    unzip -q -o -j llama.zip '*llama-server' && rm llama.zip
    chmod +x llama-server
fi

# 2. 内存盘装载
echo "[NEXUS] 正在验证内存盘 (RAM Disk) 状态..."
if [ ! -f "${RAM_DISK}/${MODEL_NAME}" ]; then
    echo "[NEXUS] 正在将模型灌入物理内存 (约 5.4GB)，避开硬盘瓶颈..."
    curl -L -o "${RAM_DISK}/${MODEL_NAME}" "$MODEL_URL" 
else
    echo "[NEXUS] 内存盘中已存在模型碎片，跳过下载。"
fi

# 3. 战场清理：杀掉死掉的旧进程
pkill -f llama-server
pkill -f cloudflared

# 4. 8核全功率点火
echo "[NEXUS] 引擎准备就绪，正在点火..."
nohup ./llama-server -m "${RAM_DISK}/${MODEL_NAME}" \
    -c 4096 --host 0.0.0.0 --port 8080 \
    -t 8 --mlock > /tmp/gemma_ultra.log 2>&1 &

# 5. 打通公网隧道
echo "[NEXUS] 正在撕开 BTP 防火墙..."
nohup ./cloudflared tunnel run --token $CF_TOKEN > /tmp/tunnel.log 2>&1 &

echo "[NEXUS] 重装甲已完全上线！输入 tail -f /tmp/gemma_ultra.log 查看引擎状态。"
