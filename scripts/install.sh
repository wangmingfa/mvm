#!/bin/bash

set -e

# ---------------------------------------------------------------------------
# OpenSSL 运行时依赖检查（仅 Linux）
# mvm 通过 MoonBit @http 发起 HTTPS 请求时，会在运行时动态加载系统的
# libssl.so（见 moonbitlang/async 的 openssl_loader，依次尝试
#   libssl.so.3 -> libssl.so.1.1 -> libssl.so）。
# 若系统缺少该共享库（例如 Fedora 上只装了 openssl CLI 而缺 openssl-libs），
# 执行 mvm use / mvm install 会报错：TlsError("failed to load OpenSSL")。
# 因此在安装前探测，缺失时尝试自动安装。
# 可用环境变量 MVM_SKIP_OPENSSL_CHECK=1 跳过本检查。
# ---------------------------------------------------------------------------
# 文件是否被动态链接器索引到（ldconfig -p；无 ldconfig 时 find 兜底）
openssl_file_present() {
  if command -v ldconfig >/dev/null 2>&1; then
    ldconfig -p 2>/dev/null | grep -qE 'libssl\.so(\.[0-9]+)?'
  else
    find /usr/lib /usr/lib64 /lib /lib64 -name 'libssl.so*' 2>/dev/null | grep -q .
  fi
}

# 是否可真实加载：用 python3 ctypes 做 dlopen，与 mvm 运行时的加载行为等价。
# 仅靠 ldconfig 索引不可靠——文件可能被索引到但实际加载失败
# （如 libcrypto 依赖缺失、ldconfig 缓存过期、库损坏）。
has_openssl() {
  if command -v python3 >/dev/null 2>&1; then
    for lib in libssl.so.3 libssl.so.1.1 libssl.so; do
      if python3 -c "import ctypes; ctypes.CDLL('$lib')" 2>/dev/null; then
        return 0
      fi
    done
    return 1
  fi
  openssl_file_present
}

# 是否"系统只有 OpenSSL 4.x"：libssl.so.4 可加载，但 MoonBit 识别的
# libssl.so.3 / libssl.so.1.1 / libssl.so 都不可用。
# 典型场景：Fedora 45+ 默认 OpenSSL 4.0（SONAME 变为 libssl.so.4）。
openssl_4_only() {
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - <<'PY'
import ctypes
def can(lib):
    try:
        ctypes.CDLL(lib)
        return True
    except Exception:
        return False
if can('libssl.so.4') and not (can('libssl.so.3') or can('libssl.so.1.1') or can('libssl.so')):
    raise SystemExit(0)
raise SystemExit(1)
PY
}

# 针对 OpenSSL 4.x：创建 libssl.so.3 -> libssl.so.4 兼容符号链接（临时应急）。
# 注意：OpenSSL 4 与 3 的 ABI 并不保证兼容，此为应急方案，建议升级支持 OpenSSL 4 的 mvm。
handle_openssl4() {
  echo ""
  echo "⚠️  检测到系统使用 OpenSSL 4.x（libssl.so.4），而当前 mvm 二进制的 MoonBit TLS"
  echo "    仅识别 libssl.so.3 / libssl.so.1.1 / libssl.so，因此运行时无法加载。"
  echo "    （Fedora 45 起默认使用 OpenSSL 4.0，SONAME 已变为 libssl.so.4）"
  echo ""
  local ssl4_path=""
  ssl4_path=$(ldconfig -p 2>/dev/null | grep -oE '/[^ ]*libssl\.so\.4' | head -1)
  if [ -z "$ssl4_path" ] || [ ! -f "$ssl4_path" ]; then
    ssl4_path=$(find /usr/lib /usr/lib64 /lib /lib64 -name 'libssl.so.4' 2>/dev/null | head -1)
  fi
  if [ -z "$ssl4_path" ] || [ ! -f "$ssl4_path" ]; then
    echo "❌ 未找到 libssl.so.4 实际文件，无法自动创建兼容链接。"
    echo "    请手动执行：sudo ln -sf \$(ldconfig -p | grep -oE '/[^ ]*libssl\.so\.4' | head -1) /usr/lib64/libssl.so.3 && sudo ldconfig"
    return 1
  fi
  local sudo_cmd=""
  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo_cmd="sudo"
    else
      echo "    需要 root 权限但未找到 sudo，无法自动创建兼容链接。"
      echo "    请手动执行：sudo ln -sf $ssl4_path /usr/lib64/libssl.so.3 && sudo ldconfig"
      return 1
    fi
  fi
  echo ""
  echo "    即将创建兼容符号链接：libssl.so.3 -> $ssl4_path"
  if [ -n "$sudo_cmd" ]; then
    echo "    需要 root 权限，执行 sudo 时可能会提示输入密码。"
  fi
  echo ""
  echo "    正在创建兼容符号链接并刷新链接器缓存 ..."
  $sudo_cmd ln -sf "$ssl4_path" /usr/lib64/libssl.so.3
  $sudo_cmd ldconfig
  if has_openssl; then
    echo "✅ 已创建兼容链接，mvm 现可正常加载 OpenSSL。"
    echo ""
    echo "⚠️  注意：OpenSSL 4 与 3 的 ABI 并不保证兼容，此链接为临时应急方案。"
    echo "    建议关注 mvm / MoonBit 发布支持 OpenSSL 4 的版本，升级后移除："
    echo "    sudo rm -f /usr/lib64/libssl.so.3 && sudo ldconfig"
  else
    echo "❌ 创建兼容链接后仍无法加载 libssl.so.3，请手动检查。"
    echo "    sudo ln -sf $ssl4_path /usr/lib64/libssl.so.3 && sudo ldconfig"
  fi
}

ensure_openssl() {
  # 仅 Linux 需要（macOS 用系统自带 dylib，Windows 走 schannel）
  [ "$(uname -s)" = "Linux" ] || return 0
  [ "${MVM_SKIP_OPENSSL_CHECK:-0}" = "1" ] && return 0

  has_openssl && return 0

  # OpenSSL 4.x（Fedora 45+）：MoonBit 不识别 libssl.so.4，走兼容链接处理
  if openssl_4_only; then
    handle_openssl4
    return
  fi

  if openssl_file_present; then
    echo "⚠️  系统存在 libssl.so 但实际无法加载（可能是 libcrypto 依赖缺失、库损坏或 ldconfig 缓存过期）。"
    echo "    执行 mvm use / mvm install 会报错：TlsError(\"failed to load OpenSSL\")"
    echo "    建议先执行：sudo ldconfig"
  else
    echo "⚠️  检测到系统缺少 OpenSSL 共享库（libssl.so），mvm 运行时发起 HTTPS 请求需要它。"
    echo "    缺失时执行 mvm use / mvm install 会报错：TlsError(\"failed to load OpenSSL\")"
  fi

  if ! install_openssl; then
    echo ""
    echo "❌ 自动安装 OpenSSL 失败，请手动安装后重新运行本脚本。"
    echo "    各发行版手动安装命令："
    echo "      Fedora / RHEL / CentOS:  sudo dnf install -y openssl-libs"
    echo "      Debian / Ubuntu:         sudo apt-get install -y libssl3"
    echo "      Arch Linux:              sudo pacman -S --noconfirm openssl"
    echo "      openSUSE:                sudo zypper install -y openssl"
    echo "      Alpine:                  sudo apk add --no-cache openssl"
    echo ""
    echo "    如确认无需本检查，可用 MVM_SKIP_OPENSSL_CHECK=1 跳过。"
    exit 1
  fi

  # 安装后复检
  if has_openssl; then
    echo "✅ OpenSSL 共享库已就绪。"
  else
    if openssl_file_present; then
      echo "⚠️  libssl.so 仍无法加载，可能是依赖损坏或缓存过期，请执行 sudo dnf reinstall -y openssl-libs && sudo ldconfig 后重试。"
    else
      echo "⚠️  OpenSSL 已安装，但系统仍找不到 libssl.so，请执行 sudo ldconfig 后重试。"
    fi
  fi
}

install_openssl() {
  local pkg_mgr="" pkg="" sudo_cmd=""
  if command -v dnf >/dev/null 2>&1; then
    pkg_mgr="dnf"; pkg="openssl-libs"
  elif command -v yum >/dev/null 2>&1; then
    pkg_mgr="yum"; pkg="openssl-libs"
  elif command -v apt-get >/dev/null 2>&1; then
    pkg_mgr="apt-get"; pkg="libssl3"
  elif command -v pacman >/dev/null 2>&1; then
    pkg_mgr="pacman"; pkg="openssl"
  elif command -v zypper >/dev/null 2>&1; then
    pkg_mgr="zypper"; pkg="openssl"
  elif command -v apk >/dev/null 2>&1; then
    pkg_mgr="apk"; pkg="openssl"
  else
    echo "    未检测到受支持的包管理器（dnf / yum / apt-get / pacman / zypper / apk）。"
    return 1
  fi

  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo_cmd="sudo"
    else
      echo "    需要 root 权限，但未找到 sudo。"
      return 1
    fi
  fi

  echo ""
  echo "    即将安装系统包：${pkg}（通过 ${pkg_mgr}）"
  if [ -n "$sudo_cmd" ]; then
    echo "    需要 root 权限，执行 sudo 时可能会提示输入密码。"
  fi
  echo ""
  echo "    正在通过 ${pkg_mgr} 安装 ${pkg} ..."
  case "$pkg_mgr" in
    apt-get)
      # Debian/Ubuntu 新版为 libssl3，旧版为 libssl1.1，逐个回退
      if ! $sudo_cmd apt-get install -y "$pkg"; then
        $sudo_cmd apt-get install -y libssl1.1
      fi
      ;;
    pacman)
      $sudo_cmd pacman -S --noconfirm "$pkg"
      ;;
    apk)
      $sudo_cmd apk add --no-cache "$pkg"
      ;;
    *)
      $sudo_cmd "$pkg_mgr" install -y "$pkg"
      ;;
  esac
}

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

# 安装前检查 mvm 运行所需的 OpenSSL 运行时依赖（仅 Linux，缺失时自动安装）
ensure_openssl

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

  # 复制可执行文件（用 cat 重建以避免继承 com.apple.provenance 属性导致 Killed: 9）
  BUILD_DIR="_build/native/release/build/cmd"
  cat "${BUILD_DIR}/main/main.exe" > "${BIN_DIR}/mvm"
  chmod +x "${BIN_DIR}/mvm"
fi

# macOS 下清除扩展属性并 ad-hoc 签名，防止 Killed: 9
if [ "$(uname -s)" = "Darwin" ]; then
  xattr -cr "${BIN_DIR}/mvm" 2>/dev/null || true
  codesign --force --sign - "${BIN_DIR}/mvm" 2>/dev/null || true
fi

# 执行 setup（创建工具软连接、配置 PATH 等）
# 默认无前缀；本地构建模式（非 --online 且非 --no-prefix）使用 f_ 前缀
# prefix 模式下自动管理所有工具（--tools all），因为加了前缀不影响原有工具
if [ "$ONLINE" = true ] || [ "$NO_PREFIX" = true ]; then
  "${BIN_DIR}/mvm" setup
else
  "${BIN_DIR}/mvm" setup -p --tools all
fi
