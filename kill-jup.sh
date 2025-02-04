#!/bin/bash

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# 日志函数
log_info() {
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $1" >&2
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1" >&2
}

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 杀死指定名称的进程
kill_process_by_name() {
    local process_name="$1"
    local pids=$(pgrep -f "$process_name")
    
    if [ -n "$pids" ]; then
        log_info "找到 $process_name 进程，PID: $pids"
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                log_info "正在停止进程 $pid..."
                kill -15 "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
            fi
        done
    else
        log_warning "没有找到 $process_name 相关的进程"
    fi
}

# 清理进程
log_info "开始清理进程..."

# 清理jupiter-swap-api进程
kill_process_by_name "jupiter-swap-api"

# 清理rust-mev-bot进程
kill_process_by_name "rust-mev-bot"

# 删除PID文件
rm -f "$SCRIPT_DIR/jupiter.pid" "$SCRIPT_DIR/rust-mev-bot.pid"

log_info "清理完成"
