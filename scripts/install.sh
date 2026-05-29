#!/bin/bash

set -e

# GitHub 仓库地址（请根据实际情况修改）
GITHUB_REPO="wangmingfa/mvm"

# 解析参数
ONLINE=false
NO_PREFIX=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --online)      ONLINE=true; shift ;;
    --no-prefix)   NO_PREFIX=true; shift ;;
    -np)           NO_PREFIX=true; shift ;;
    *) echo "未知参数：$1"; exit 1 ;;
  esac
done

# 确定 MVM_HOME 目录（有环境变量则直接使用，否则使用 $HOME/.mvm）
MVM_HOME="${MVM_HOME:-$HOME/.mvm}"

# 确定 bin 目录
BIN_DIR="${MVM_HOME}/bin"
mkdir -p "${BIN_DIR}"

if [ "$ONLINE" = true ]; then
  # --online 模式：从 GitHub 下载最新 release
  echo "正在从 GitHub 下载最新 release..."

  # 检测操作系统
  case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *)      echo "不支持的操作系统：$(uname -s)"; exit 1 ;;
  esac

  # 检测架构
  case "$(uname -m)" in
    arm64|aarch64) ARCH="arm64" ;;
    x86_64|amd64)  ARCH="x86_64" ;;
    *)             echo "不支持的架构：$(uname -m)"; exit 1 ;;
  esac

  # 校验 OS+ARCH 组合（仅支持 macos+arm64、linux+x86_64）
  case "${OS}_${ARCH}" in
    macos_arm64|linux_x86_64) ;;
    *) echo "不支持的系统组合：${OS}_${ARCH}"; exit 1 ;;
  esac

  # 确定目标版本：MVM_VERSION 环境变量优先，否则从 GitHub API 获取最新版本
  if [ -n "$MVM_VERSION" ]; then
    LATEST_TAG="$MVM_VERSION"
    echo "指定版本：${LATEST_TAG}"
  else
    API_RESP=$(curl -sL \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")
    LATEST_TAG=$(echo "$API_RESP" | grep -o '"tag_name": *"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"')

    # 兜底：若 releases/latest 无结果，尝试 tags API
    if [ -z "$LATEST_TAG" ]; then
      echo "releases/latest 未找到，尝试从 tags 获取..."
      LATEST_TAG=$(curl -sL \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPO}/tags" \
        | grep -o '"name": *"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"')
    fi

    if [ -z "$LATEST_TAG" ]; then
      echo "无法获取最新 release 版本号"
      echo "API 响应：${API_RESP}"
      exit 1
    fi
    echo "最新版本：${LATEST_TAG}"
  fi

  # 确定压缩包文件名（格式：mvm-{version}-{os}-{arch}.tar.gz）
  ARCHIVE="mvm-${LATEST_TAG}-${OS}-${ARCH}.tar.gz"

  # 下载压缩包
  DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_TAG}/${ARCHIVE}"
  echo "正在下载：${DOWNLOAD_URL}"
  TMP_DIR="$(mktemp -d)"
  ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE}"
  curl -sL -o "${ARCHIVE_PATH}" "${DOWNLOAD_URL}"

  if [ ! -f "${ARCHIVE_PATH}" ]; then
    echo "下载失败"
    exit 1
  fi

  # 解压
  echo "正在解压..."
  if [[ "$ARCHIVE" == *.tar.gz ]]; then
    tar -xzf "${ARCHIVE_PATH}" -C "${BIN_DIR}"
  else
    unzip -q -o "${ARCHIVE_PATH}" -d "${BIN_DIR}"
  fi

  # 清理临时文件
  rm -rf "${TMP_DIR}"
else
  # 本地构建模式
  # 记录脚本开始位置
  tput sc
  if moon build --release; then
    # 回到开始位置
    tput rc
    # 清除脚本产生的内容
    tput ed
  else
    exit 1
  fi

  # 复制可执行文件
  BUILD_DIR="_build/native/release/build/cmd"
  cp "${BUILD_DIR}/main/main.exe" "${BIN_DIR}/mvm"
fi

# 执行 setup（创建工具软连接、配置 PATH 等）
# 默认无前缀；本地构建模式（非 --online 且非 --no-prefix）使用 f_ 前缀
# prefix 模式下自动管理所有工具（--tools all），因为加了前缀不影响原有工具
if [ "$ONLINE" = true ] || [ "$NO_PREFIX" = true ]; then
  "${BIN_DIR}/mvm" setup
else
  "${BIN_DIR}/mvm" setup -p --tools all
fi
