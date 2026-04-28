#!/bin/bash

set -e

# 确定 MVM_HOME 目录
MVM_HOME="${MVM_HOME:-$HOME}/.mvm"

# 构建
echo "正在构建 mvm..."
moon build --release

# 确定 bin 目录
BIN_DIR="${MVM_HOME}/bin"
rm -rf "${BIN_DIR}"
mkdir -p "${BIN_DIR}"

# 复制可执行文件
BUILD_DIR="_build/native/release/build/cmd"

cp "${BUILD_DIR}/main/main.exe" "${BIN_DIR}/mvm"
cp "${BUILD_DIR}/exe/exe.exe" "${BIN_DIR}/mvm-exe"

# 支持的工具列表
TOOLS=("node" "npm" "npx" "corepack" "zig")

# 本机测试时，增加f前缀，用于与系统已经安装好的node区分开，避免重名
PREFIX="f"

# 创建工具软连接
for tool in "${TOOLS[@]}"; do
  ln -sf "${BIN_DIR}/mvm-exe" "${BIN_DIR}/${PREFIX}${tool}"
done

echo "构建完成！可执行文件已安装到 ${BIN_DIR}"
echo "  - mvm     (主命令)"
echo "  - mvm-exe (工具执行器)"
echo "  工具软连接：${TOOLS[*]}"
