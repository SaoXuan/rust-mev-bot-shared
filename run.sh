#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR"

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

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${COLOR_BLUE}[DEBUG]${COLOR_RESET} $1" >&2
    fi
}

# 显示帮助信息
show_help() {
    log_info "用法: $0 [选项]"
    log_info "选项:"
    log_info "  --debug    启用调试模式，显示所有日志输出"
    log_info "  --help     显示此帮助信息"
}

# 安装 yq 函数
install_yq() {
    if ! command -v yq &>/dev/null; then
        log_info "正在安装 yq..."
        if wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64; then
            chmod +x /usr/local/bin/yq
            log_info "yq 安装成功"
        else
            log_error "yq 下载失败"
            return 1
        fi
    fi
    return 0
}

# 检查依赖工具是否安装
check_dependencies() {
    # 首先安装 yq
    install_yq || {
        log_error "yq 安装失败"
        exit 1
    }

    # 检查其他依赖
    local dependencies=("jq")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_info "正在安装 $dep..."
            apt update && apt install -y "$dep"
        fi
    done
}

# 检查必要文件
check_required_files() {
    if [ ! -f "config.yaml" ]; then
        log_error "config.yaml 文件不存在！"
        exit 1
    fi

    if [ ! -f "jupiter-swap-api" ]; then
        log_error "jupiter-swap-api 文件不存在！"
        exit 1
    else
        log_info "设置 jupiter-swap-api 权限..."
        chmod +x jupiter-swap-api
    fi
}

# 设置文件权限
setup_file_permissions() {
    log_info "设置文件权限..."
    chmod +x rust-mev-bot upgrade.sh jupiter-swap-api kill-process.sh run-jup.sh mints-query.sh 2>/dev/null || true
}

# 获取重启间隔时间（分钟）
get_restart_interval() {
    local interval
    interval=$(yq -r '.auto_restart // 0' config.yaml)
    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        interval=0
    fi
    echo "$interval"
}

# 生成代币列表
generate_token_list() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        DEBUG=true ./mints-query.sh
    else
        ./mints-query.sh
    fi

    if [ $? -ne 0 ] || [ ! -f "$SCRIPT_DIR/token-cache.json" ]; then
        log_error "token-cache.json 生成失败"
        exit 1
    fi
}

# 检查是否需要启动本地 Jupiter
check_local_jupiter_enabled() {
    local disable_local_jupiter
    disable_local_jupiter=$(yq -r '.jupiter_disable_local // false' config.yaml)

    if [[ "$disable_local_jupiter" == "true" ]]; then
        log_info "配置文件设置为不启动本地 Jupiter，跳过启动步骤"
        return 1 # 禁用时返回1（false）
    fi
    return 0 # 启用时返回0（true）
}

# 检查是否需要启动本地 rust-mev-bot
check_local_bot_enabled() {
    local disable_local_bot
    disable_local_bot=$(yq -r '.disable_local_bot // false' config.yaml)

    if [[ "$disable_local_bot" == "true" ]]; then
        log_info "配置文件设置为不启动本地 Bot，跳过启动步骤"
        return 1
    fi
    return 0
}

# 初始化环境
init_environment() {
    check_dependencies
    setup_file_permissions
    check_required_files
    generate_token_list
}

# 启动服务
start_service() {
    local restart_interval
    restart_interval=$(get_restart_interval)
    [ "$restart_interval" -gt 0 ] && log_info "自动重启: ${restart_interval}分钟"

    # 检查是否需要启动本地 Jupiter
    if check_local_jupiter_enabled; then
        # 启动 Jupiter 并记录监控进程 PID
        if [[ "${DEBUG:-false}" == "true" ]]; then
            DEBUG=true ./run-jup.sh --debug &
            echo $! >monitor.pid
        else
            ./run-jup.sh &
            echo $! >monitor.pid
        fi
        sleep 5
    fi

    # 启动 rust-mev-bot 并记录 PID
    if check_local_bot_enabled; then
        ./rust-mev-bot &
        echo $! >bot.pid
    fi
}

# 清理函数
cleanup() {
    local is_exit=$1 # 传入参数：true 表示退出，false 表示重启

    if [ "$is_exit" = "true" ]; then
        echo ""
        log_error "正在终止所有进程..."
    else
        log_error "——————Restart Task On——————"
    fi
    ./kill-process.sh
    if [ "$is_exit" = "true" ]; then
        log_info "清理完成"
        exit 1
    else
        return 0
    fi
}

# 为了保持原有的函数名，创建两个包装函数
cleanup_for_restart() {
    cleanup false
}

cleanup_and_exit() {
    cleanup true
}

# 设置信号处理
trap cleanup_and_exit SIGINT SIGTERM SIGHUP INT

# 主循环
run_main_loop() {
    while true; do
        init_environment
        start_service

        local interval
        interval=$(get_restart_interval)

        # 只有当 interval 为 0 时不重启
        if [ "$interval" -eq 0 ]; then
            wait
            break
        fi

        sleep "${interval}m"
        cleanup_for_restart
    done
}

# 主函数
main() {
    # 先行设置资源限制
    ulimit -n 65535
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
        --debug)
            export DEBUG=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
        esac
    done

    run_main_loop
}

# 执行主函数
main "$@"
