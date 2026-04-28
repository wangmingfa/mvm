#!/bin/bash

set -e

# GitHub 仓库地址（请根据实际情况修改）
GITHUB_REPO="username/mvm"

# 解析参数
ONLINE=false
for arg in "$@"; do
  case "$arg" in
    --online) ONLINE=true ;;
    *) echo "未知参数：$arg"; exit 1 ;;
  esac
done

# 确定 MVM_HOME 目录
MVM_HOME="${MVM_HOME:-$HOME}/.mvm"

# 确定 bin 目录
BIN_DIR="${MVM_HOME}/bin"
rm -rf "${BIN_DIR}"
mkdir -p "${BIN_DIR}"

# 本机测试时，增加f前缀，用于与系统已经安装好的node区分开，避免重名
# --online 模式下 PREFIX 为空，正式发布无需前缀
PREFIX=""
if [ "$ONLINE" != true ]; then
  PREFIX="f"
fi

# 支持的工具列表
TOOLS=("node" "npm" "npx" "corepack" "zig")

# 构建显示用的工具名列表
DISPLAY_TOOLS=()
for tool in "${TOOLS[@]}"; do
  DISPLAY_TOOLS+=("${PREFIX}${tool}")
done

# 创建工具软连接（动态拼接 PREFIX）
for tool in "${DISPLAY_TOOLS[@]}"; do
  ln -sf "${BIN_DIR}/mvm-exe" "${BIN_DIR}/${tool}"
done

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

  # 确定压缩包名称和格式
  case "$OS" in
    macos|linux) EXT="tar.gz" ;;
    *) EXT="zip" ;;
  esac

  ARCHIVE="mvm-${OS}-${ARCH}.${EXT}"

  # 获取最新 release 的 tag
  LATEST_TAG=$(curl -sL "https://github.com/${GITHUB_REPO}/releases/latest" \
    | grep -oP '"tag_name":"\K[^"]+' || true)
  if [ -z "$LATEST_TAG" ]; then
    echo "无法获取最新 release 版本号"
    exit 1
  fi
  echo "最新版本：${LATEST_TAG}"

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
  echo "正在构建 mvm..."
  moon build --release

  # 复制可执行文件
  BUILD_DIR="_build/native/release/build/cmd"
  cp "${BUILD_DIR}/main/main.exe" "${BIN_DIR}/mvm"
  cp "${BUILD_DIR}/exe/exe.exe" "${BIN_DIR}/mvm-exe"
fi

echo "构建完成！可执行文件已安装到 ${BIN_DIR}"
echo "  - mvm     (主命令)"
echo "  - mvm-exe (工具执行器)"
echo "  工具软连接：${DISPLAY_TOOLS[*]}"
