#!/bin/bash

set -e

# 确定 MVM_HOME 目录
MVM_HOME="${MVM_HOME:-$HOME}/.mvm"

# 构建
echo "正在构建 mvm..."
moon build --release

# 确定 bin 目录
BIN_DIR="${MVM_HOME}/bin"
mkdir -p "${BIN_DIR}"

# 复制可执行文件
BUILD_DIR="_build/native/release/build/cmd"

cp "${BUILD_DIR}/main/main.exe" "${BIN_DIR}/mvm"
cp "${BUILD_DIR}/exe/exe.exe" "${BIN_DIR}/mvm-exe"

echo "构建完成！可执行文件已安装到 ${BIN_DIR}"
echo "  - mvm     (主命令)"
echo "  - mvm-exe (工具执行器)"
