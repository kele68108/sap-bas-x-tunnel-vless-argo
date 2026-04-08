#!/bin/bash
# ==========================================
# [NEXUS_BOOT] 赛博先知 全自动装甲引擎 (Qwen2 极速特化版)
# ==========================================

if [ -z "$CF_TOKEN" ]; then
    echo "[!!FATAL!!] 核心密钥缺失！请使用 export CF_TOKEN='你的密钥' 注入。"
    exit 1
fi

WORK_DIR="/home/user/projects/ai_core"
# 【提速 1】：换装极其轻量、原生中文无敌的 Qwen2-1.5B (仅 1.1GB)
MODEL_URL="https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF/resolve/main/qwen2-1_5b-instruct-q4_k_m.gguf?download=true"

if pgrep -x "llama-server" > /dev/null || pgrep -x "cloudflared" > /dev/null; then
    echo "[NEXUS] 核心引擎已在运行，静默退出。"
    exit 0
fi

> /tmp/ai_core.log
> /tmp/tunnel.log
mkdir -p $WORK_DIR
cd $WORK_DIR

# (引擎和探针都不需要再编译了，我们直接利用上一轮留下的完美战利品！)
if [ ! -f "cloudflared" ]; then
    wget -qO cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared
fi

# 检测并下载新的 Qwen2 大脑
if [ ! -f "qwen2.gguf" ] || [ $(stat -c%s "qwen2.gguf" 2>/dev/null || echo 0) -lt 1000000000 ]; then
    echo "[NEXUS] 正在深度连接 Qwen2 神经元 (1.1GB)..."
    wget -c -O qwen2.gguf $MODEL_URL
fi

# 【提速 2】：线程减半！-t 8 改为 -t 4，解除 K8s 线程互斥锁！
echo "[NEXUS] 正在点火 4 线程极速模式..."
nohup ./llama-server -m qwen2.gguf -c 4096 --host 0.0.0.0 --port 8080 -t 4 > /tmp/ai_core.log 2>&1 &

echo "[NEXUS] 正在打通全局内网隧道..."
nohup ./cloudflared tunnel run --token $CF_TOKEN > /tmp/tunnel.log 2>&1 &

echo "[NEXUS] 极速特化版激活完毕！面甲已降下。"
