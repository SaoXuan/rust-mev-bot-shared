#!/bin/bash
set -e

# 解析命令行参数
version=""
beta=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --beta)
      beta=true
      shift
      ;;
    *)
      if [ -z "$version" ]; then
        version="$1"
      fi
      shift
      ;;
  esac
done

echo "调试: 版本是 '$version'"
echo "调试: beta标志是 '$beta'"

# 根据beta标志设置项目名称
project_name="rust-mev-bot"
if [ "$beta" = true ]; then
  project_name="rust-mev-bot-beta"
fi

if [ -n "$version" ]; then
    # 提供了版本参数
    echo "📦 检测到版本参数: $version"
    download_link="https://sourceforge.net/projects/$project_name/files/rust-mev-bot-$version.zip"

    echo "🌐 构建下载链接: $download_link"

    # 检查URL是否存在
    if curl --output /dev/null --silent --head --fail "$download_link"; then
        echo "✅ 版本 $version 已找到。"
    else
        echo "❌ 版本 $version 未找到。"
        exit 1
    fi
else
    # 没有版本参数，继续执行当前逻辑
    URL="https://sourceforge.net/projects/$project_name/files/"

    echo "🌐 正在从SourceForge获取项目文件页面..."

    # 修改grep使用-E而不是-P并调整正则表达式
    download_link=$(curl -s "$URL" | grep -Eo 'href="[^"]+\.zip/download"' | head -n 1 | sed -E 's/href="([^"]+)\/download"/\1/')

    if [ -z "$download_link" ]; then
      echo "❌ 未找到压缩包。"
      exit 1
    fi

    # 检查download_link是否为相对路径
    if [[ ! $download_link =~ ^https?:// ]]; then
        # 如果download_link是相对路径，添加基础URL
        download_link="https://sourceforge.net${download_link}"
    fi

    echo "最新压缩包链接: $download_link"
    echo "✅ 已找到最新压缩包。"

    # 使用正则表达式提取版本号
    if [[ $download_link =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
      version="${BASH_REMATCH[1]}"
      echo "版本号: $version"
    else
      echo "未找到版本号"
    fi
fi

echo "📥 正在下载压缩包..."

filename=$(basename "$download_link")
output_file="./$filename"

curl -sL "$download_link" -o "$output_file"

if [ $? -ne 0 ]; then
  echo "❌ 下载压缩包失败。"
  exit 1
fi

echo "✅ 下载成功。"
echo "📂 正在解压到当前目录..."

if [ -f "$output_file" ]; then
  unzip -o "$output_file"

  if [ $? -ne 0 ]; then
    echo "❌ 解压压缩包失败。"
    exit 1
  fi

  echo "✅ 解压完成。"
else
  echo "❌ 未找到或无法下载压缩包。"
  exit 1
fi

echo "🧹 正在清理..."
rm -f "$output_file"

echo "✨ 进程成功完成！"

# 设置文件权限
setup_file_permissions() {
    echo "🔒 设置文件权限..."
    chmod +x run.sh 2>/dev/null || true
}

# 调用权限设置函数.
setup_file_permissions

