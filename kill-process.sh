#!/bin/bash

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# 通过进程名称杀死进程
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

# 日志函数
log_info() {
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $1" >&2
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1" >&2
}

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# 检查是否需要启动本地 Jupiter
check_local_jupiter_enabled() {
    local disable_local_jupiter
    disable_local_jupiter=$(yq -r '.jupiter_disable_local // false' config.yaml)
    if [[ "$disable_local_jupiter" == "true" ]]; then
        return 1 # 禁用时返回1（false）
    fi
    return 0 # 启用时返回0（true）
}
# 检查是否需要启动本地 rust-mev-bot
check_local_bot_enabled() {
    local disable_local_bot
    disable_local_bot=$(yq -r '.disable_local_bot // false' config.yaml)
    if [[ "$disable_local_bot" == "true" ]]; then
        return 1
    fi
    return 0
}

# 通过 PID 文件清理进程
if [ -f "jupiter.pid" ]; then
    pkill -9 -P $(cat jupiter.pid) 2>/dev/null || true # 先杀子进程
    kill -9 $(cat jupiter.pid) 2>/dev/null || true     # 再杀父进程
    rm -f jupiter.pid
    kill_process_by_name "jupiter-swap-api"
    log_warning "jup stop complete ..."
fi

# 清理监控进程
if [ -f "monitor.pid" ]; then
    kill -9 $(cat monitor.pid) 2>/dev/null || true
    rm -f monitor.pid
    log_warning "kill monitor.pid complete..."
fi

# 清理 bot 进程
if [ -f "bot.pid" ]; then
    kill -9 $(cat bot.pid) 2>/dev/null || true
    rm -f bot.pid
    kill_process_by_name "rust-mev-bot"
    log_warning "bot stop complete ..."
fi

# 清理其他文件
rm -f .jupiter_running 2>/dev/null
