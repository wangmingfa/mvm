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

exit $exit_code
