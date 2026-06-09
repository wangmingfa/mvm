# install_online.ps1 - Quick script for installing mvm online
# Automatically downloads install.ps1 and runs it in -online mode, simplifying one-line install experience

$ErrorActionPreference = "Stop"

$REPO = "wangmingfa/mvm"
$BRANCH = "main"
$URL = "https://raw.githubusercontent.com/${REPO}/${BRANCH}/scripts/install.ps1"

Write-Host "Downloading mvm install script..."
& ([scriptblock]::Create((Invoke-RestMethod -Uri $URL))) -online
