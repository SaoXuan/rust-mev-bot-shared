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

# 清理函数
cleanup() {
    ./kill-process.sh
}
cleanup_and_exit() {
    ./kill-process.sh
    exit 0
}
# 设置信号处理
trap cleanup SIGINT SIGTERM SIGHUP
# 设置信号处理
trap cleanup_and_exit SIGINT SIGTERM

# 设置系统文件描述符限制
ulimit -n 100000

# 检查Jupiter API程序是否存在
if [ ! -f "$SCRIPT_DIR/jupiter-swap-api" ]; then
    log_error "未找到jupiter-swap-api文件！"
    exit 1
fi

# 设置默认Jupiter端口
LOCAL_JUPITER_PORT=${LOCAL_JUPITER_PORT:-18080}

# 生成 Jupiter 启动命令
generate_jupiter_command() {
    local cmd="RUST_LOG=info ./jupiter-swap-api"
    # 从 config.yaml 读取配置
    local rpc_url=$(yq -r '.rpc_url // ""' config.yaml)
    local yellowstone_url=$(yq -r '.yellowstone_grpc_url // ""' config.yaml)
    local yellowstone_token=$(yq -r '.yellowstone_grpc_token // ""' config.yaml)
    local port=$(yq -r '.jupiter_local_port // 18080' config.yaml)
    local market_mode=$(yq -r '.jupiter_market_mode // "remote"' config.yaml)
    local webserver_thread_count=$(yq -r '.jupiter_webserver // 4' config.yaml)
    local update_thread_count=$(yq -r '.jupiter_update // 4' config.yaml)
    local total_thread_count=$(yq -r '.total_thread_count // 16' config.yaml)
    local host=$(yq -r '.jup_bind_local_host // "0.0.0.0"' config.yaml)

    # 检查必要的配置
    if [ -z "$rpc_url" ]; then
        log_error "RPC URL 未配置"
        exit 1
    fi

    # 构建命令
    cmd+=" --rpc-url $rpc_url"
    cmd+=" --market-cache https://cache.jup.ag/markets?v=4"
    cmd+=" --market-mode $market_mode"
    cmd+=" --port $port"
    cmd+=" --host $host"
    cmd+=" --allow-circular-arbitrage"
    cmd+=" --enable-new-dexes"
    cmd+=" --expose-quote-and-simulate"

    # 添加 Yellowstone 配置
    if [ -n "$yellowstone_url" ]; then
        cmd+=" --yellowstone-grpc-endpoint $yellowstone_url"
        if [ -n "$yellowstone_token" ]; then
            cmd+=" --yellowstone-grpc-x-token $yellowstone_token"
        fi
    fi

    # 添加线程配置
    cmd+=" --total-thread-count $total_thread_count"
    cmd+=" --webserver-thread-count $webserver_thread_count"
    cmd+=" --update-thread-count $update_thread_count"

    # 添加代币过滤
    if [ -f "token-cache.json" ]; then
        local mints=$(jq -r 'join(",")' token-cache.json)
        log_info "使用 token-cache.json 中的代币列表"
        cmd+=" --filter-markets-with-mints $mints"
    else
        log_error "未找到 token-cache.json 文件"
        exit 1
    fi

    # 添加排除的 DEX
    local exclude_dex_ids=$(yq -r '.jup_exclude_dex_program_ids[]' config.yaml 2>/dev/null | paste -sd "," -)
    if [ -n "$exclude_dex_ids" ]; then
        cmd+=" --exclude-dex-program-ids $exclude_dex_ids"
    fi

    echo "$cmd"
}

# 启动 Jupiter 服务
start_jupiter_service() {
    local jupiter_cmd
    jupiter_cmd=$(generate_jupiter_command)

    # 打印启动命令
    log_info "启动命令: $jupiter_cmd"

    # 执行命令
    if [[ "${DEBUG:-false}" == "true" ]]; then
        eval "$jupiter_cmd" 2>&1 | tee jupiter-api.log
    else
        eval "$jupiter_cmd" >jupiter-api.log 2>&1 &
    fi

    local pid=$!
    echo $pid >jupiter.pid

    # 检查进程是否存活
    if kill -0 $pid 2>/dev/null; then
        log_info "Jupiter API 启动成功 (PID: $pid)"
        return 0
    else
        log_error "Jupiter API 启动失败"
        return 1
    fi
}

# 监控进程并在崩溃时重启
monitor_and_restart() {
    touch .jupiter_running

    while [ -f .jupiter_running ]; do
        start_jupiter_service
        local parent_pid=$(cat jupiter.pid 2>/dev/null)
        
        if [ -n "$parent_pid" ]; then
            log_info "监控 Jupiter 进程 (父进程 PID: $parent_pid)"
            
            # 等待父进程创建子进程
            local max_wait=10
            local waited=0
            while [ $waited -lt $max_wait ]; do
                local child_pid=$(pgrep -P "$parent_pid" 2>/dev/null)
                if [ -n "$child_pid" ]; then
                    log_info "检测到子进程 (PID: $child_pid)"
                    break
                fi
                log_debug "等待子进程创建... ($waited/$max_wait)"
                sleep 1
                ((waited++))
            done
            
            # 监控父进程和子进程
            while true; do
                # 检查父进程状态
                if ! kill -0 "$parent_pid" 2>/dev/null; then
                    log_warning "父进程 $parent_pid 已终止"
                    break
                fi
                log_debug "父进程 $parent_pid 存活"

                # 检查子进程状态
                if [ -n "$child_pid" ]; then
                    if ! kill -0 "$child_pid" 2>/dev/null; then
                        log_warning "子进程 $child_pid 已终止"
                        break
                    fi
                    log_debug "子进程 $child_pid 存活"
                fi

                # 打印进程状态
                log_debug "进程状态："
                ps -f -p "$parent_pid" "$child_pid" 2>/dev/null >&2
                
                sleep 5
            done
            
            log_warning "检测到进程终止，准备重启..."
            # 确保清理所有相关进程
            log_debug "清理子进程..."
            pkill -P "$parent_pid" 2>/dev/null
            log_debug "清理父进程..."
            kill -9 "$parent_pid" 2>/dev/null
        else
            log_error "无法获取 Jupiter PID"
        fi
        
        log_debug "等待进程完全退出..."
        sleep 2
    done
}

# 主函数
main() {
    monitor_and_restart
}

# 执行主函数
main "$@"
