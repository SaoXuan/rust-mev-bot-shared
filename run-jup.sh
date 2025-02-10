#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
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

# 根据端口号杀死进程的函数
kill_process_on_port() {
    local port=$1
    local pids
    
    # 使用lsof查找端口对应的进程，并忽略错误输出
    pids=$(lsof -ti tcp:${port} 2>/dev/null)

    if [ -n "$pids" ]; then
        log_info "正在关闭端口 $port 上的进程..."
        
        # 遍历所有找到的PID
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                log_info "正在停止进程 PID: $pid"
                kill -15 "$pid" 2>/dev/null
                
                # 等待最多3秒看进程是否结束
                local count=0
                while kill -0 "$pid" 2>/dev/null && [ $count -lt 3 ]; do
                    sleep 1
                    count=$((count + 1))
                done
                
                # 如果进程还在运行，使用强制终止
                if kill -0 "$pid" 2>/dev/null; then
                    log_warning "进程 $pid 未能正常终止，使用强制终止"
                    kill -9 "$pid" 2>/dev/null
                fi
            fi
        done
    else
        log_info "端口 $port 上没有运行的进程"
    fi
}

# 递归杀死进程及其子进程的函数
kill_process_and_children() {
    local pid=$1
    
    # 检查PID是否有效
    if ! kill -0 "$pid" 2>/dev/null; then
        return 0
    fi
    
    # 获取子进程列表
    local children
    children=$(pgrep -P "$pid" 2>/dev/null)
    
    # 递归终止子进程
    if [ -n "$children" ]; then
        log_info "找到子进程: $children"
        for child in $children; do
            kill_process_and_children "$child"
        done
    fi
    
    # 终止当前进程
    if kill -0 "$pid" 2>/dev/null; then
        log_info "正在终止进程 $pid"
        kill -15 "$pid" 2>/dev/null
        
        # 等待最多3秒
        local count=0
        while kill -0 "$pid" 2>/dev/null && [ $count -lt 3 ]; do
            sleep 1
            count=$((count + 1))
        done
        
        # 如果还在运行，强制终止
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "进程 $pid 未能正常终止，使用强制终止"
            kill -9 "$pid" 2>/dev/null
        fi
    fi
}

cleanup_and_exit() {
    # 终止jupiter-swap-api进程
    if [ -n "$JUPITER_PID" ]; then
        kill_process_and_children "$JUPITER_PID"
    fi
    # 清理端口上的进程
    kill_process_on_port "$LOCAL_JUPITER_PORT"
    log_info "清理完成，正在退出..."
    exit 0
}

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

log_info "正在清理... 如果看到No such file or directory或No process to kill on port $LOCAL_JUPITER_PORT是正常的"

# 如果未禁用本地Jupiter服务，则关闭可能存在的旧进程
if [ "$DISABLE_LOCAL_JUPITER" != "true" ]; then
    kill_process_on_port $LOCAL_JUPITER_PORT
fi

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
        eval "$jupiter_cmd" > jupiter-api.log 2>&1 &
    fi
    
    local pid=$!
    echo $pid > jupiter.pid
    
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
    # 创建运行标记文件
    touch .jupiter_running
    
    while [ -f .jupiter_running ]; do
        if [[ "${DEBUG:-false}" == "true" ]]; then
            start_jupiter_service
            break
        else
            start_jupiter_service
            if [ $? -eq 0 ]; then
                local pid=$(cat jupiter.pid 2>/dev/null)
                if [ -n "$pid" ]; then
                    log_info "开始监控 Jupiter 进程 (PID: $pid)"
                    while kill -0 $pid 2>/dev/null && [ -f .jupiter_running ]; do
                        sleep 5
                    done
                fi
            fi
            
            # 如果标记文件被删除，退出循环
            [ ! -f .jupiter_running ] && break
            
            sleep 5
        fi
    done
}

# 清理函数
cleanup() {
    rm -f .jupiter_running 2>/dev/null
    if [ -f jupiter.pid ]; then
        kill -9 $(cat jupiter.pid) 2>/dev/null
        rm -f jupiter.pid
    fi
}

# 设置信号处理
trap cleanup SIGINT SIGTERM SIGHUP

# 主函数
main() {
    monitor_and_restart
}

# 执行主函数
main "$@"
