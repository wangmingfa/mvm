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
    $EXECUTOR_SRC = Join-Path $EXTRACT_DIR "executor.ps1"
    $EXECUTOR_DEST = Join-Path $BIN_DIR "executor.ps1"

    # 生成 update.bat：统一处理文件复制、setup、清理
    # 新安装时 mvm.exe 不存在 → 直接复制
    # 升级时 mvm.exe 被锁 → 每 100ms 检测，超 3 秒提示用户手动关闭
    $SETUP_CMD = if ($USE_PREFIX) { "`"$MVM_DEST`" setup -p" } else { "`"$MVM_DEST`" setup" }
    $UPDATE_BAT = Join-Path $TMP_DIR "update.bat"
    $batLines = @(
        "@echo off",
        "if not exist `"$MVM_DEST`" (",
        "    echo 正在安装 mvm...",
        "    copy /Y `"$MVM_SRC`" `"$MVM_DEST`"",
        "    if errorlevel 1 (",
        "        echo 安装失败，请重试",
        "        pause",
        "        exit /b 1",
        "    )",
        "    goto setup",
        ")",
        "echo 正在升级 mvm，等待进程退出...",
        "setlocal enabledelayedexpansion",
        "set retries=0",
        ":retry",
        "copy /Y `"$MVM_SRC`" `"$MVM_DEST`" >nul 2>&1",
        "if !errorlevel! equ 0 goto copy_ok",
        "set /a retries+=1",
        "if !retries! GEQ 30 goto copy_fail",
        "ping -n 1 -w 100 127.0.0.1 >nul",
        "goto retry",
        ":copy_ok",
        "endlocal",
        "goto setup",
        ":copy_fail",
        "endlocal",
        "echo mvm 进程仍在运行，请手动关闭后重试",
        "pause",
        "exit /b 1",
        ":setup",
        "if exist `"$EXECUTOR_SRC`" copy /Y `"$EXECUTOR_SRC`" `"$EXECUTOR_DEST`"",
        $SETUP_CMD,
        "if errorlevel 1 echo setup 不可用，请稍后重试更新 shims",
        "rmdir /s /q `"$TMP_DIR`"",
        "echo 完成！",
        "pause"
    )
    $batLines -join "`r`n" | Set-Content -Path $UPDATE_BAT -Encoding ASCII

    Write-Host "正在启动安装程序..."
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$UPDATE_BAT`""
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
