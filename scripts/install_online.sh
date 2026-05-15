#!/bin/bash

# install_online.sh —— 在线安装 mvm 的快捷脚本
# 自动下载 install.sh 并以 --online 模式执行，简化一行命令安装体验

set -e

REPO="wangmingfa/mvm"
BRANCH="main"
URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/scripts/install.sh"

echo "正在下载 mvm 安装脚本..."
curl -fsSL "${URL}" | bash -s -- --online
