# install_online.ps1 —— 在线安装 mvm 的快捷脚本
# 自动下载 install.ps1 并以 -online 模式执行，简化一行命令安装体验

$ErrorActionPreference = "Stop"

$REPO = "wangmingfa/mvm"
$BRANCH = "main"
$URL = "https://raw.githubusercontent.com/${REPO}/${BRANCH}/scripts/install.ps1"

Write-Host "正在下载 mvm 安装脚本..."
& ([scriptblock]::Create((Invoke-RestMethod -Uri $URL))) -online
