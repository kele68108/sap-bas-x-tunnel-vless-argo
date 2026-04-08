#!/bin/bash
# ==========================================
# [NEXUS_ULTRA_V6] 赛博先知 终极液态金属版 (修复动态库 + 强制清场)
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

# 1. 抓取探针与引擎核心 (包含所有动态依赖库)
echo "[NEXUS] 正在获取稳定版探针与引擎核心..."
if [ ! -f "cloudflared" ]; then
    wget -qO cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared
fi

if [ ! -f "llama-server" ] || [ ! -f "libllama.so" ]; then
    echo "[NEXUS] 正在下载并解压完整的引擎组件..."
    STABLE_LLAMA_URL="https://github.com/ggerganov/llama.cpp/releases/download/b4618/llama-b4618-bin-ubuntu-x64.zip"
    wget -qO llama.zip "$STABLE_LLAMA_URL"
    
    # 【关键修复1】：同时提取 server 和所有 .so 动态链接库！
    unzip -q -o -j llama.zip '*llama-server' '*.so' && rm llama.zip
    chmod +x llama-server
fi

# 2. 深度清理旧战场（消灭 64MB 的碎片毒瘤）
echo "[NEXUS] 正在执行深度清场..."
pkill -f llama-server
pkill -f cloudflared
rm -f "$PIPE_PATH"
# 强制清理 RAM Disk 中上次失败的残留文件
rm -f /dev/shm/gemma* # 3. 建立“液态金属”流式管道
echo "[NEXUS] 正在构建虚拟数据管道 (绕开 64MB shm 限制)..."
mkfifo "$PIPE_PATH"

# 4. 后台疯狂接水 (将 5.4GB 数据灌入管道)
echo "[NEXUS] 正在从公网抽取 Gemma 2 (5.4GB) 纯量能量流..."
curl -s -L "$MODEL_URL" > "$PIPE_PATH" &

# 5. 8核引擎全功率点火 (绑定动态库路径)
echo "[NEXUS] 引擎开始吞噬管道流，分配进程内存..."
# 【关键修复2】：使用 env LD_LIBRARY_PATH=$PWD 让引擎能找到脚底下的 .so 文件
nohup env LD_LIBRARY_PATH=$PWD ./llama-server -m "$PIPE_PATH" --no-mmap \
    -c 4096 --host 0.0.0.0 --port 8080 \
    -t 8 > /tmp/gemma_ultra.log 2>&1 &

# 6. 打通公网隧道
echo "[NEXUS] 正在撕开 BTP 防火墙..."
nohup ./cloudflared tunnel run --token $CF_TOKEN > /tmp/tunnel.log 2>&1 &

echo "[NEXUS] 重装甲已完全上线！"
echo "[>>] 请使用 tail -f /tmp/gemma_ultra.log 查看引擎加载进度。"
