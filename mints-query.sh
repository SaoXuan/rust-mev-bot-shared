#!/bin/bash

# 设置严格模式
set -euo pipefail

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 常量定义
readonly DEFAULT_BATCH_SIZE=50
readonly DEFAULT_MIN_LIQUIDITY=100
readonly API_BASE_URL="https://public-api.birdeye.so/defi/tokenlist"
readonly CONFIG_FILE="$SCRIPT_DIR/config.yaml"
readonly OUTPUT_FILE="$SCRIPT_DIR/token-cache.json"

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

# 检查依赖
check_dependencies() {
    local deps=("jq" "yq" "curl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "未安装 $dep 命令。请先安装:"
            echo "Ubuntu/Debian: sudo apt-get install $dep"
            echo "CentOS/RHEL: sudo yum install $dep"
            exit 1
        fi
    done
}

# 从URL获取token列表
get_tokens_from_url() {
    local url="$1"
    log_info "正在从 $url 获取token列表..."
    
    # 使用curl获取数据，设置超时和重试
    local response
    if ! response=$(curl -s -m 10 --retry 3 "$url"); then
        log_error "无法从URL获取数据: $url"
        return 1
    fi
    
    # 尝试解析JSON响应
    if ! echo "$response" | jq -e . >/dev/null 2>&1; then
        log_error "从URL获取的数据不是有效的JSON格式"
        return 1
    fi
    
    # 提取token地址
    echo "$response" | jq -r '.[]'
}

# 从本地文件获取token列表
get_tokens_from_file() {
    local file="$1"
    log_info "正在从文件 $file 读取token列表..."
    
    if [ ! -f "$file" ]; then
        log_error "文件不存在: $file"
        return 1
    fi
    
    if ! jq -e . "$file" >/dev/null 2>&1; then
        log_error "文件不是有效的JSON格式: $file"
        return 1
    fi
    
    jq -r '.[]' "$file"
}

# 从Birdeye API获取代币列表
get_birdeye_token_addresses() {
    local api_key="$1"
    local limit="$2"
    local temp_file=$(mktemp)
    
    log_info "正在从Birdeye获取代币列表 (限制: $limit)..."
    
    local offset=0
    while [ $offset -lt $limit ]; do
        local current_limit=$DEFAULT_BATCH_SIZE
        if [ $((offset + current_limit)) -gt $limit ]; then
            current_limit=$((limit - offset))
        fi
        
        local request_url="${API_BASE_URL}?sort_by=v24hUSD&sort_type=desc&offset=${offset}&limit=${current_limit}&min_liquidity=${DEFAULT_MIN_LIQUIDITY}"
        log_debug "发送请求: $request_url"
        
        # 发送请求并检查响应
        local response
        if ! response=$(curl -s -H "X-API-KEY: $api_key" "$request_url"); then
            log_error "请求Birdeye API失败"
            rm -f "$temp_file"
            return 1
        fi
        
        # 检查响应是否为有效的JSON
        if ! echo "$response" | jq -e . >/dev/null 2>&1; then
            log_error "Birdeye API返回的数据不是有效的JSON格式"
            rm -f "$temp_file"
            return 1
        fi
        
        # 检查API返回的状态
        local success
        success=$(echo "$response" | jq -r '.success // false')
        if [ "$success" != "true" ]; then
            local error_msg
            error_msg=$(echo "$response" | jq -r '.message // "未知错误"')
            log_error "Birdeye API返回错误: $error_msg"
            rm -f "$temp_file"
            return 1
        fi
        
        # 检查数据结构
        if ! echo "$response" | jq -e '.data.tokens' >/dev/null 2>&1; then
            log_error "Birdeye API返回的数据结构不正确，缺少 .data.tokens"
            log_error "API返回: $(echo "$response" | jq -c '.')"
            rm -f "$temp_file"
            return 1
        fi
        
        # 提取token地址并追加到临时文件
        if ! echo "$response" | jq -r '.data.tokens[] | select(.address != null) | .address' >> "$temp_file"; then
            log_error "处理token数据失败"
            rm -f "$temp_file"
            return 1
        fi
        
        offset=$((offset + current_limit))
        log_debug "已处理: $offset / $limit"
    done
    
    # 检查是否获取到数据
    if [ ! -s "$temp_file" ]; then
        log_error "从Birdeye API没有获取到任何token数据"
        rm -f "$temp_file"
        return 1
    fi
    
    cat "$temp_file"
    rm -f "$temp_file"
    return 0
}

# 写入代币列表到文件
write_tokens_to_file() {
    local tokens="$1"
    local output_file="$2"
    
    # 如果文件存在，先删除
    if [ -f "$output_file" ]; then
        log_info "删除已存在的文件: $output_file"
        rm -f "$output_file" || {
            log_error "删除旧文件失败: $output_file"
            return 1
        }
    fi
    
    log_info "正在写入代币列表到 $output_file ..."
    echo "$tokens" | jq -R . | jq -s . > "$output_file"
    
    # 检查文件是否成功创建
    if [ -f "$output_file" ]; then
        local token_count=$(jq 'length' "$output_file")
        log_info "成功写入 $token_count 个代币到 $output_file"
        # 同时输出到标准输出
        cat "$output_file"
        return 0
    else
        log_error "写入文件失败: $output_file"
        return 1
    fi
}

# 合并和过滤token列表
merge_and_filter_tokens() {
    local temp_file
    temp_file=$(mktemp)
    
    # 直接使用yq读取配置
    local max_mints=$(yq -r '.load_mints_from_birdeye_api_max_mints // 0' "$CONFIG_FILE")
    local mints_url=$(yq -r '.load_mints_from_url // "未配置"' "$CONFIG_FILE")
    local mints_file=$(yq -r '.intermediate_tokens_file // "未配置"' "$CONFIG_FILE")
    local birdeye_api_key=$(yq -r '.birdeye_api_key // ""' "$CONFIG_FILE")
    
    local has_data=false
    local total_tokens=0

    # 从配置文件中读取 intermediate_tokens
    local config_tokens
    config_tokens=$(yq -r '.intermediate_tokens[]' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$config_tokens" ]; then
        echo "$config_tokens" >> "$temp_file"
        has_data=true
        local config_count=$(echo "$config_tokens" | wc -l)
        total_tokens=$((total_tokens + config_count))
    fi

    # 从Birdeye API获取数据
    if [ "$max_mints" -gt 0 ]; then
        if [ -z "$birdeye_api_key" ]; then
            log_warning "配置了 load_mints_from_birdeye_api_max_mints=$max_mints，但未配置 birdeye_api_key，跳过从 Birdeye 获取数据"
        else
            if birdeye_tokens=$(get_birdeye_token_addresses "$birdeye_api_key" "$max_mints"); then
                echo "$birdeye_tokens" >> "$temp_file"
                has_data=true
                local birdeye_count=$(echo "$birdeye_tokens" | wc -l)
                total_tokens=$((total_tokens + birdeye_count))
            fi
        fi
    fi

    # 从URL获取数据
    if [ "$mints_url" != "未配置" ]; then
        if url_tokens=$(get_tokens_from_url "$mints_url"); then
            echo "$url_tokens" >> "$temp_file"
            has_data=true
            local url_count=$(echo "$url_tokens" | wc -l)
            total_tokens=$((total_tokens + url_count))
        fi
    fi

    # 从本地文件获取数据
    if [ "$mints_file" != "未配置" ] && [ -f "$mints_file" ]; then
        if file_tokens=$(get_tokens_from_file "$mints_file"); then
            echo "$file_tokens" >> "$temp_file"
            has_data=true
            local file_count=$(echo "$file_tokens" | wc -l)
            total_tokens=$((total_tokens + file_count))
        fi
    fi

    # 如果没有任何数据，报错退出
    if [ "$has_data" = false ]; then
        log_error "没有获取到有效的token数据"
        rm -f "$temp_file"
        return 1
    fi

    # 过滤和去重
    if [ -f "$temp_file" ]; then
        # 添加 SOL 代币地址到临时文件
        echo "So11111111111111111111111111111111111111112" >> "$temp_file"
        
        # 去重并排序
        local valid_tokens
        valid_tokens=$(cat "$temp_file" | sort -u)

        if [ -z "$valid_tokens" ]; then
            log_error "过滤后没有任何有效的token地址"
            rm -f "$temp_file"
            return 1
        fi

        # 转换为JSON数组格式并写入输出文件
        echo "[" > "$OUTPUT_FILE"
        echo "$valid_tokens" | sed 's/^/"/;s/$/",/' | sed '$s/,$//' >> "$OUTPUT_FILE"
        echo "]" >> "$OUTPUT_FILE"
        
        local final_count=$(echo "$valid_tokens" | wc -l)
        log_info "原始token总数: $total_tokens"
        log_info "去重后token数: $final_count"
        
        rm -f "$temp_file"
        return 0
    else
        log_error "处理token数据时发生错误"
        rm -f "$temp_file"
        return 1
    fi
}

# 主函数
main() {
    check_dependencies
    merge_and_filter_tokens
}

# 仅在直接执行时运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi