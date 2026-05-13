#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

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

# 运行：./executor.sh node -v
if [ $# -eq 0 ]; then
  echo "错误：缺少参数。示例：./executor.sh node -v"
  exit 1
fi
run_mvm executor "$@"
exit_code=$?

exit $exit_code