#!/bin/sh

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 工具名前缀（与 install.sh、executor.mbt 保持一致）
PREFIX="f_"

run_mvm() {
  if [ -f "${SCRIPT_DIR}/mvm" ]; then
    CMD="${SCRIPT_DIR}/mvm"
  else
    CMD="moon run cmd/main --"
  fi
  LOG_LEVEL=$(echo "${MVM_LOG_LEVEL}" | tr 'A-Z' 'a-z')
  if [ "${LOG_LEVEL}" = "debug" ]; then
    echo "运行: $CMD $*"
  fi
  $CMD "$@"
}

# 判断是否为npm全局卸载命令
is_npm_global_uninstall() {
  has_uninstall=false
  has_global=false
  for arg in "$@"; do
    case "$arg" in
      uninstall|un) has_uninstall=true ;;
      --global|-g) has_global=true ;;
    esac
  done
  [ "$has_uninstall" = true ] && [ "$has_global" = true ]
}

if [ "$SCRIPT_NAME" = "executor.sh" ]; then
  # 直接运行：./executor.sh node -v
  if [ $# -eq 0 ]; then
    echo "错误：缺少参数。示例：./executor.sh node -v"
    exit 1
  fi
  run_mvm executor "$@"
  exit_code=$?
else
  # 兼容软连接的方式（软连接到当前文件），比如：node -v
  # node实际上是软连接到当前文件的
  run_mvm executor "$SCRIPT_NAME" "$@"
  exit_code=$?
fi

# 如果是npm全局卸载且执行成功，清除hash表以便shell重新查找命令路径
is_npm=false
if [ "$SCRIPT_NAME" = "npm" ] || [ "$SCRIPT_NAME" = "${PREFIX}npm" ]; then
  is_npm=true
elif [ "$SCRIPT_NAME" = "executor.sh" ] && ([ "$1" = "npm" ] || [ "$1" = "${PREFIX}npm" ]); then
  is_npm=true
fi

LOG_LEVEL=$(echo "${MVM_LOG_LEVEL}" | tr 'A-Z' 'a-z')
if [ "${LOG_LEVEL}" = "debug" ]; then
  echo "hash-r检查: SCRIPT_NAME=${SCRIPT_NAME}, is_npm=${is_npm}, exit_code=${exit_code}, args=$*"
fi

is_uninstall=false
if is_npm_global_uninstall "$@"; then
  is_uninstall=true
fi

if [ "${LOG_LEVEL}" = "debug" ]; then
  echo "hash-r检查: is_npm_global_uninstall=${is_uninstall}"
fi

if [ "$is_npm" = true ] && [ "$is_uninstall" = true ] && [ $exit_code -eq 0 ]; then
  if [ "${LOG_LEVEL}" = "debug" ]; then
    echo "清除shell hash表: hash -r"
  fi
  hash -r
elif [ "${LOG_LEVEL}" = "debug" ]; then
  echo "hash-r跳过: is_npm=${is_npm}, is_uninstall=${is_uninstall}, exit_code=${exit_code}"
fi

exit $exit_code
