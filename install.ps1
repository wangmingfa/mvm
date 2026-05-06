param(
    [switch]$online,
    [alias("np")][switch]$noPrefix
)

$ErrorActionPreference = "Stop"

$GITHUB_REPO = "wangmingfa/mvm"

$ONLINE = $online.IsPresent
$NO_PREFIX = $noPrefix.IsPresent

# === CONFIG_START ===
# 工具名前缀
$PREFIX = "f_"

# 支持的工具列表
$TOOLS = @(node npm npx corepack zig bun)
# === CONFIG_END ===

if ($ONLINE -or $NO_PREFIX) {
    $PREFIX = ""
}

if ($env:MVM_HOME) {
    $MVM_HOME = $env:MVM_HOME
} else {
    $HOME_DIR = $env:USERPROFILE
    $MVM_HOME = Join-Path $HOME_DIR ".mvm"
}
$BIN_DIR = Join-Path $MVM_HOME "bin"

New-Item -ItemType Directory -Force -Path $BIN_DIR | Out-Null

foreach ($tool in $TOOLS) {
    $toolPath = Join-Path $BIN_DIR $tool
    $prefixedToolPath = Join-Path $BIN_DIR ($PREFIX + $tool)
    if (Test-Path $toolPath) { Remove-Item $toolPath -Force }
    if (Test-Path $prefixedToolPath) { Remove-Item $prefixedToolPath -Force }
}

$DISPLAY_TOOLS = @()
foreach ($tool in $TOOLS) {
    $DISPLAY_TOOLS += $PREFIX + $tool
}

$executorPath = Join-Path $BIN_DIR "executor.ps1"

foreach ($tool in $DISPLAY_TOOLS) {
    $toolScriptPath = Join-Path $BIN_DIR ($tool + ".ps1")
    $content = @"
#!/usr/bin/env pwsh
& "$executorPath" $tool `$args
"@
    Set-Content -Path $toolScriptPath -Value $content -Encoding UTF8
}

if ($ONLINE) {
    Write-Host "正在从 GitHub 下载最新 release..."

    # 检测操作系统（仅支持 Windows）
    if (-not ($IsWindows -or [Environment]::OSVersion.Platform -eq "Win32NT")) {
        Write-Error "不支持的操作系统，install.ps1 仅支持 Windows"
        exit 1
    }

    $OS = "windows"
    $ARCH = "x86_64"
    $EXT = "zip"
    $ARCHIVE = "mvm-${OS}-${ARCH}.${EXT}"

    try {
        $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" -ErrorAction Stop
        $LATEST_TAG = $releaseInfo.tag_name
        Write-Host "最新版本：${LATEST_TAG}"
    } catch {
        Write-Error "无法获取最新 release 版本号: $_"
        exit 1
    }

    $DOWNLOAD_URL = "https://github.com/${GITHUB_REPO}/releases/download/${LATEST_TAG}/${ARCHIVE}"
    Write-Host "正在下载：${DOWNLOAD_URL}"

    $TMP_DIR = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Force -Path $TMP_DIR | Out-Null
    $ARCHIVE_PATH = Join-Path $TMP_DIR $ARCHIVE

    try {
        Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $ARCHIVE_PATH -ErrorAction Stop
    } catch {
        Write-Error "下载失败: $_"
        exit 1
    }

    if (-not (Test-Path $ARCHIVE_PATH)) {
        Write-Error "下载失败"
        exit 1
    }

    Write-Host "正在解压..."
    Expand-Archive -Path $ARCHIVE_PATH -DestinationPath $BIN_DIR -Force

    Remove-Item -Recurse -Force $TMP_DIR
} else {
    Write-Host "正在构建 mvm..."
    & moon build --release

    $BUILD_DIR = "_build/native/release/build/cmd/main"
    $MVM_EXE = Join-Path $BUILD_DIR "main.exe"
    
    if (-not (Test-Path $MVM_EXE)) {
        Write-Error "构建失败，未找到可执行文件: $MVM_EXE"
        exit 1
    }
    
    Copy-Item -Path $MVM_EXE -Destination (Join-Path $BIN_DIR "mvm.exe") -Force
    Copy-Item -Path "executor.ps1" -Destination $executorPath -Force
}

$NPM_DIR = Join-Path $BIN_DIR "npm-pkg"
New-Item -ItemType Directory -Force -Path $NPM_DIR | Out-Null

$PATH_ENTRIES = @($BIN_DIR, $NPM_DIR)
$CURRENT_PATH = [Environment]::GetEnvironmentVariable("PATH", "User")
$PATH_MODIFIED = $false

foreach ($entry in $PATH_ENTRIES) {
    $escapedEntry = [regex]::Escape($entry)
    if ($CURRENT_PATH -notmatch $escapedEntry) {
        $CURRENT_PATH = "$entry;$CURRENT_PATH"
        Write-Host "已将 $entry 添加到用户 PATH 环境变量"
        $PATH_MODIFIED = $true
    } else {
        Write-Host "$entry 已存在于用户 PATH 环境变量，跳过"
    }
}

if ($PATH_MODIFIED) {
    [Environment]::SetEnvironmentVariable("PATH", $CURRENT_PATH, "User")
    Write-Host ""
    Write-Host "PATH 环境变量已更新，请重新启动 PowerShell 使其生效"
}

Write-Host ""
Write-Host "安装完成！可执行文件已安装到 $BIN_DIR"
Write-Host "  - mvm.exe         (主命令)"
Write-Host "  - executor.ps1    (工具执行脚本)"
Write-Host "  - npm-pkg 目录    (npm 全局包安装路径：$NPM_DIR)"
Write-Host "  工具脚本：$($DISPLAY_TOOLS -join ', ')"
