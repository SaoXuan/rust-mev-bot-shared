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
cleanup_and_exit() {
    # 传入 true 参数以保留监控进程
    kill_process_by_name "jupiter-swap-api"
    rm -f .jupiter_running
    exit 0
}



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


# 设置信号处理
trap cleanup_and_exit SIGINT SIGTERM SIGHUP

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
	# 启动健康检查
	cmd+=" --enable-markets --enable-tokens"
	cmd+=" --metrics-port 18081"
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
    log_info "启动命令: $jupiter_cmd"

    # 启动服务
    eval "$jupiter_cmd" >jupiter-api.log 2>&1 &
    # 增加启动延迟
    sleep 5
    
    # 获取进程 PID
    local pid=$(pgrep -f "jupiter-swap-api")
    if [ -n "$pid" ]; then
        echo $pid >jupiter.pid
        log_info "Jupiter 服务启动成功 (进程 PID: $pid)"
        return 0
    fi
    
    log_error "Jupiter 服务启动失败"
    return 1
}

# 监控进程并在崩溃时重启
monitor_and_restart() {
    touch .jupiter_running
    local retry_count=0
    local max_retries=5  # 最大重试次数
    local retry_interval=60  # 重试间隔（秒）

    while [ -f .jupiter_running ]; do
        rm -f jupiter.pid
        
        # 检查重试次数
        if [ $retry_count -ge $max_retries ]; then
            log_error "达到最大重试次数($max_retries)，等待 $retry_interval 秒后重置计数..."
            sleep $retry_interval
            retry_count=0
        fi

        if ! start_jupiter_service; then
            ((retry_count++))
            log_error "Jupiter 服务启动失败 (尝试 $retry_count/$max_retries)..."
            sleep 5
            continue
        fi

        # 启动成功，重置重试计数
        retry_count=0

        # 获取并验证 PID
        local pid=$(cat jupiter.pid 2>/dev/null)
        if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
            log_error "无法获取有效的进程 PID"
            sleep 2
            continue
        fi
        # 监控进程
        log_info "开始监控 Jupiter 服务 (PID: $pid)"
        while kill -0 "$pid" 2>/dev/null; do
            sleep 5
        done

        log_error "Jupiter 服务已停止，准备重启..."
        # 添加诊断信息
        if [ -f "jupiter-api.log" ]; then
            log_warning "最后的日志输出:"
            tail -n 5 jupiter-api.log
            log_error "---------------重启中-----------------"
        fi
        sleep 2
    done
}

# 主函数
main() {
    monitor_and_restart
}

# 执行主函数
main "$@"
