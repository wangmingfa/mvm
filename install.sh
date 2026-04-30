#!/bin/bash

set -e

# GitHub 仓库地址（请根据实际情况修改）
GITHUB_REPO="username/mvm"

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

# 工具名前缀（与 executor.sh、executor.mbt 保持一致）
PREFIX="f_"

# 确定 PREFIX（--online 或 --no-prefix 时清空前缀）
if [ "$ONLINE" = true ]; then
  PREFIX=""
elif [ "$NO_PREFIX" = true ]; then
  PREFIX=""
fi

# 确定 MVM_HOME 目录
MVM_HOME="${MVM_HOME:-$HOME}/.mvm"

# 确定 bin 目录
BIN_DIR="${MVM_HOME}/bin"
mkdir -p "${BIN_DIR}"

# 支持的工具列表
TOOLS=("node" "npm" "npx" "corepack" "zig" "bun")

# 清理旧的工具软连接（原始名和带当前前缀的）
for tool in "${TOOLS[@]}"; do
  rm -f "${BIN_DIR}/${tool}"
  rm -f "${BIN_DIR}/${PREFIX}${tool}"
done

# 构建显示用的工具名列表
DISPLAY_TOOLS=()
for tool in "${TOOLS[@]}"; do
  DISPLAY_TOOLS+=("${PREFIX}${tool}")
done

# 创建工具软连接（动态拼接 PREFIX）
for tool in "${DISPLAY_TOOLS[@]}"; do
  ln -sf "${BIN_DIR}/executor.sh" "${BIN_DIR}/${tool}"
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
  cp "executor.sh" "${BIN_DIR}/executor.sh"
fi

# 配置 PATH：自动识别 shell 配置文件，避免重复添加
detect_shell_profile() {
  case "$SHELL" in
    */zsh)  echo "$HOME/.zshrc" ;;
    */bash)
      if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    *)      echo "$HOME/.profile" ;;
  esac
}

NPM_DIR="${BIN_DIR}/npm-pkg"
mkdir -p "${NPM_DIR}"

SHELL_PROFILE=$(detect_shell_profile)
touch "$SHELL_PROFILE"

PATH_ENTRIES=("${BIN_DIR}" "${NPM_DIR}")
PROFILE_MODIFIED=false
for entry in "${PATH_ENTRIES[@]}"; do
  if ! grep -qF "export PATH=\"${entry}:" "$SHELL_PROFILE" 2>/dev/null && \
     ! grep -qF ":${entry}:" "$SHELL_PROFILE" 2>/dev/null; then
    echo "" >> "$SHELL_PROFILE"
    echo "export PATH=\"${entry}:\$PATH\"" >> "$SHELL_PROFILE"
    echo "已将 ${entry} 添加到 PATH（写入 ${SHELL_PROFILE}）"
    PROFILE_MODIFIED=true
  else
    echo "${entry} 已存在于 PATH（${SHELL_PROFILE}），跳过"
  fi
done

# 如果有新内容加入shell profile，提示用户手动执行source以便生效
if [ "$PROFILE_MODIFIED" = true ]; then
  GREEN_BOLD='\033[1;32m'
  RESET='\033[0m'
  echo ""
  echo "PATH 配置已更新，请执行以下命令使其生效："
  echo -e "  ${GREEN_BOLD}source ${SHELL_PROFILE}${RESET}"
fi

echo ""
echo "安装完成！可执行文件已安装到 ${BIN_DIR}"
echo "  - mvm         (主命令)"
echo "  - executor.sh (工具执行脚本)"
echo "  - npm-pkg 目录    (npm 全局包安装路径：${NPM_DIR})"
echo "  工具软连接：${DISPLAY_TOOLS[*]}"
