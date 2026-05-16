#!/bin/sh
# Debug 模式运行脚本：临时设置 MVM_LOG_LEVEL=debug，运行完成后恢复原值

# 保存原始 MVM_LOG_LEVEL
OLD_MVM_LOG_LEVEL="${MVM_LOG_LEVEL}"
export MVM_LOG_LEVEL=debug

moon run cmd/main "$@"
EXIT_CODE=$?

# 恢复原始 MVM_LOG_LEVEL
if [ -n "${OLD_MVM_LOG_LEVEL}" ]; then
  export MVM_LOG_LEVEL="${OLD_MVM_LOG_LEVEL}"
else
  unset MVM_LOG_LEVEL
fi

exit $EXIT_CODE
