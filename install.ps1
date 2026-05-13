param(
    [switch]$online,
    [alias("np")][switch]$noPrefix
)

$ErrorActionPreference = "Stop"

$GITHUB_REPO = "wangmingfa/mvm"

$ONLINE = $online.IsPresent -or ("--online" -in $args)
$NO_PREFIX = $noPrefix.IsPresent -or ("--no-prefix" -in $args) -or ("-np" -in $args)

# 确定 setup 是否使用前缀模式（默认无前缀；本地构建模式使用 f_ 前缀）
$USE_PREFIX = -not ($ONLINE -or $NO_PREFIX)

if ($env:MVM_HOME) {
    $MVM_HOME = $env:MVM_HOME
} else {
    $HOME_DIR = $env:USERPROFILE
    $MVM_HOME = Join-Path $HOME_DIR ".mvm"
}
$BIN_DIR = Join-Path $MVM_HOME "bin"

New-Item -ItemType Directory -Force -Path $BIN_DIR | Out-Null

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

    try {
        $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" -ErrorAction Stop
        $LATEST_TAG = $releaseInfo.tag_name
        Write-Host "最新版本：${LATEST_TAG}"
    } catch {
        Write-Error "无法获取最新 release 版本号: $_"
        exit 1
    }

    $ARCHIVE = "mvm-${LATEST_TAG}-${OS}-${ARCH}.${EXT}"

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
    $EXTRACT_DIR = Join-Path $TMP_DIR "extract"
    New-Item -ItemType Directory -Force -Path $EXTRACT_DIR | Out-Null
    Expand-Archive -Path $ARCHIVE_PATH -DestinationPath $EXTRACT_DIR -Force

    $MVM_DEST = Join-Path $BIN_DIR "mvm.exe"
    $MVM_SRC  = Join-Path $EXTRACT_DIR "mvm.exe"

    # 尝试直接复制（新安装时 mvm.exe 不存在，不会被锁）
    $copySuccess = $false
    try {
        Copy-Item -Path $MVM_SRC -Destination $MVM_DEST -Force -ErrorAction Stop
        $executorSrc = Join-Path $EXTRACT_DIR "executor.ps1"
        if (Test-Path $executorSrc) {
            Copy-Item -Path $executorSrc -Destination (Join-Path $BIN_DIR "executor.ps1") -Force
        }
        $copySuccess = $true
    } catch {
        # mvm.exe 正在运行（文件锁），需要通过 update.bat 替换
    }

    if ($copySuccess) {
        # 新安装，直接复制成功，清理临时文件并执行 setup
        Remove-Item -Path $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
        if ($USE_PREFIX) { & "$MVM_DEST" setup '-p' } else { & "$MVM_DEST" setup }
    } else {
        # mvm.exe 被锁，生成 update.bat：等 mvm.exe 退出后再执行文件替换和 setup
        $UPDATE_BAT = Join-Path $TMP_DIR "update.bat"
        $SETUP_CMD = if ($USE_PREFIX) { "`"$MVM_DEST`" setup -p" } else { "`"$MVM_DEST`" setup" }
        $batLines = @(
            "@echo off",
            "timeout /t 2 /nobreak >nul",
            "copy /Y `"$MVM_SRC`" `"$MVM_DEST`"",
            "if exist `"$(Join-Path $EXTRACT_DIR 'executor.ps1')`" copy /Y `"$(Join-Path $EXTRACT_DIR 'executor.ps1')`" `"$(Join-Path $BIN_DIR 'executor.ps1')`"",
            $SETUP_CMD,
            "rmdir /s /q `"$TMP_DIR`"",
            "echo 升级完成！"
        )
        $batLines -join "`r`n" | Set-Content -Path $UPDATE_BAT -Encoding ASCII

        Write-Host "正在后台启动更新程序，mvm 退出后将自动完成替换和设置..."
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$UPDATE_BAT`"" -WindowStyle Hidden
    }
} else {
    # 本地构建模式
    moon build --release
    $exit = $LASTEXITCODE

    if ($exit -eq 0) {
        # 清空前面的日志
        Clear-Host
    }
    else {
        exit $exit
    }

    $BUILD_DIR = "_build/native/release/build/cmd/main"
    $MVM_EXE = Join-Path $BUILD_DIR "main.exe"
    
    if (-not (Test-Path $MVM_EXE)) {
        Write-Error "构建失败，未找到可执行文件: $MVM_EXE"
        exit 1
    }
    
    $executorPath = Join-Path $BIN_DIR "executor.ps1"
    Copy-Item -Path $MVM_EXE -Destination (Join-Path $BIN_DIR "mvm.exe") -Force
    Copy-Item -Path "executor.ps1" -Destination $executorPath -Force

    # 执行 setup（创建工具脚本、配置 PATH 等）
    if ($USE_PREFIX) { & (Join-Path $BIN_DIR "mvm.exe") setup '-p' } else { & (Join-Path $BIN_DIR "mvm.exe") setup }
}
