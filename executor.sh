#!/bin/sh

SCRIPT_NAME=$(basename "$0")
if [ "$SCRIPT_NAME" = "executor.sh" ]; then
  # 直接运行：./executor.sh node -v
  moon run cmd/main -- executor "$@"
else
  # 兼容软连接的方式（软连接到当前文件），比如：node -v
  # node实际上是软连接到当前文件的
  moon run cmd/main -- executor "$SCRIPT_NAME" "$@"
fi
