#!/bin/bash
# ==========================================
# [NEXUS_ULTRA_V3] 赛博先知 实战落地版 (自动抓取引擎 + 真实大模型)
# ==========================================

if [ -z "$CF_TOKEN" ]; then
    echo "[!!FATAL!!] 核心密钥缺失！请确保 CF_TOKEN 已注入。"
    exit 1
fi

WORK_DIR="/home/user/projects/ai_core"
# 使用真实存在且强悍的 Gemma 2 9B (约 5.4GB) 来验证 64G RAM Disk 威力
MODEL_NAME="gemma-2-9b-it-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/bartowski/gemma-2-9b-it-GGUF/resolve/main/gemma-2-9b-it-Q4_K_M.gguf"
RAM_DISK="/dev/shm"

mkdir -p $WORK_DIR
cd $WORK_DIR

# 1. 动态抓取最新版 llama-server 引擎
echo "[NEXUS] 正在获取最新版引擎核心..."
if [ ! -f "cloudflared" ]; then
    wget -qO cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared
fi

if [ ! -f "llama-server" ]; then
    # 利用 GitHub API 动态匹配最新的 ubuntu-x64 二进制文件
    LLAMA_ZIP_URL=$(curl -s https://api.github.com/repos/ggerganov/llama.cpp/releases/latest | grep -o 'https://[^"]*-bin-ubuntu-x64\.zip')
    wget -qO llama.zip "$LLAMA_ZIP_URL"
    # 解压并提取 llama-server，忽略目录结构
    unzip -o -j llama.zip '*llama-server' && rm llama.zip
    chmod +x llama-server
fi

# 2. 内存盘装载 (5.4GB 写入物理内存)
echo "[NEXUS] 正在验证内存盘 (RAM Disk) 状态..."
if [ ! -f "${RAM_DISK}/${MODEL_NAME}" ]; then
    echo "[NEXUS] 正在将模型灌入物理内存 (约 5.4GB)，请等待下载进度条跑完..."
    # -L 参数极其重要，用于跟随 HuggingFace 的 CDN 重定向
    curl -L -o "${RAM_DISK}/${MODEL_NAME}" "$MODEL_URL" 
fi

# 3. 清理之前的失败进程（防止端口占用）
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

echo "[NEXUS] 重装甲已完全上线！你可以使用 tail -f /tmp/gemma_ultra.log 查看引擎状态。"
