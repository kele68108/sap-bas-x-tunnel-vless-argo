#!/bin/bash
# ==========================================
# [NEXUS_ULTRA_V5] 赛博先知 液态金属流式版 (突破 64MB shm 限制)
# ==========================================

if [ -z "$CF_TOKEN" ]; then
    echo "[!!FATAL!!] 核心密钥缺失！请确保 CF_TOKEN 已注入。"
    exit 1
fi

WORK_DIR="/home/user/projects/ai_core"
MODEL_URL="https://huggingface.co/bartowski/gemma-2-9b-it-GGUF/resolve/main/gemma-2-9b-it-Q4_K_M.gguf"
PIPE_PATH="/tmp/gemma_stream"

mkdir -p $WORK_DIR
cd $WORK_DIR

# 1. 获取探针与引擎核心 (放在本地硬盘，体积极小)
echo "[NEXUS] 正在获取稳定版探针与引擎..."
if [ ! -f "cloudflared" ]; then
    wget -qO cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared
fi

if [ ! -f "llama-server" ]; then
    STABLE_LLAMA_URL="https://github.com/ggerganov/llama.cpp/releases/download/b4618/llama-b4618-bin-ubuntu-x64.zip"
    wget -qO llama.zip "$STABLE_LLAMA_URL"
    unzip -q -o -j llama.zip '*llama-server' && rm llama.zip
    chmod +x llama-server
fi

# 2. 清理旧战场
pkill -f llama-server
pkill -f cloudflared
rm -f "$PIPE_PATH"

# 3. 建立“液态金属”流式管道
echo "[NEXUS] 正在构建虚拟数据管道..."
mkfifo "$PIPE_PATH"

# 4. 后台疯狂接水 (将 5.4GB 数据灌入管道)
echo "[NEXUS] 正在从公网抽取 Gemma 2 (5.4GB) 纯量能量流..."
# 注意：这里我们让它在后台默默下载，只要引擎端开始吸，它就会一直流
curl -s -L "$MODEL_URL" > "$PIPE_PATH" &

# 5. 8核引擎全功率点火 (从管道中吸取数据存入堆内存)
echo "[NEXUS] 引擎开始吞噬管道流，分配进程内存..."
# 【极其重要】：必须加 --no-mmap，强迫引擎把数据加载到 64G 内存堆中！
nohup ./llama-server -m "$PIPE_PATH" --no-mmap \
    -c 4096 --host 0.0.0.0 --port 8080 \
    -t 8 > /tmp/gemma_ultra.log 2>&1 &

# 6. 打通公网隧道
echo "[NEXUS] 正在撕开 BTP 防火墙..."
nohup ./cloudflared tunnel run --token $CF_TOKEN > /tmp/tunnel.log 2>&1 &

echo "[NEXUS] 注入进程已启动！"
echo "[>>] 请使用 tail -f /tmp/gemma_ultra.log 查看引擎加载进度。"
echo "[>>] 注意：因为是流式加载 5.4GB 数据，大概需要等待 3-5 分钟引擎才能吐出 HTTP server listening。"
