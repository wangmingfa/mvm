#!/bin/sh
# Debug 模式运行脚本：临时设置 MVM_LOG_LEVEL=debug，运行完成后恢复原值

# 保存原始 MVM_LOG_LEVEL
OLD_MVM_LOG_LEVEL="${MVM_LOG_LEVEL}"
export MVM_LOG_LEVEL=debug

# 捕获 EXIT 信号，确保任何退出方式（包括 Ctrl+C）都能恢复环境变量
trap '
  if [ -n "${OLD_MVM_LOG_LEVEL}" ]; then
    export MVM_LOG_LEVEL="${OLD_MVM_LOG_LEVEL}"
  else
    unset MVM_LOG_LEVEL
  fi
' EXIT

# 获取脚本所在目录，并定位项目根目录（scripts/ 的上一级）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 使用绝对路径执行，保持用户当前工作目录不变
moon run "${PROJECT_ROOT}/cmd/main" "$@"
