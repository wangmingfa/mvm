param(
    [switch]$online,
    [alias("np")][switch]$noPrefix
)

$ErrorActionPreference = "Stop"

$GITHUB_REPO = "wangmingfa/mvm"

$ONLINE = $online.IsPresent -or ("--online" -in $args)
$NO_PREFIX = $noPrefix.IsPresent -or ("--no-prefix" -in $args) -or ("-np" -in $args)

# Determine whether setup uses prefix mode (default no prefix; local build mode uses f_ prefix)
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
    Write-Host "Downloading latest release from GitHub..."

    # Check operating system (Windows only)
    if (-not ($IsWindows -or [Environment]::OSVersion.Platform -eq "Win32NT")) {
        Write-Error "Unsupported operating system, install.ps1 only supports Windows"
        exit 1
    }

    $OS = "windows"
    $ARCH = "x86_64"
    $EXT = "zip"

    # Determine target version: MVM_VERSION env var takes priority, otherwise fetch latest from GitHub API
    if ($env:MVM_VERSION) {
        $LATEST_TAG = $env:MVM_VERSION
        Write-Host "Specified version: ${LATEST_TAG}"
    } else {
        try {
            $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" -ErrorAction Stop
            $LATEST_TAG = $releaseInfo.tag_name
            Write-Host "Latest version: ${LATEST_TAG}"
        } catch {
            Write-Error "Failed to get latest release version: $_"
            exit 1
        }
    }

    $ARCHIVE = "mvm-${LATEST_TAG}-${OS}-${ARCH}.${EXT}"

    $DOWNLOAD_URL = "https://github.com/${GITHUB_REPO}/releases/download/${LATEST_TAG}/${ARCHIVE}"
    Write-Host "Downloading: ${DOWNLOAD_URL}"

    $TMP_DIR = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Force -Path $TMP_DIR | Out-Null
    $ARCHIVE_PATH = Join-Path $TMP_DIR $ARCHIVE

    try {
        Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $ARCHIVE_PATH -ErrorAction Stop
    } catch {
        Write-Error "Download failed: $_"
        exit 1
    }

    if (-not (Test-Path $ARCHIVE_PATH)) {
        Write-Error "Download failed"
        exit 1
    }

    Write-Host "Extracting..."
    $EXTRACT_DIR = Join-Path $TMP_DIR "extract"
    New-Item -ItemType Directory -Force -Path $EXTRACT_DIR | Out-Null
    Expand-Archive -Path $ARCHIVE_PATH -DestinationPath $EXTRACT_DIR -Force

    $MVM_DEST = Join-Path $BIN_DIR "mvm.exe"
    $MVM_SRC  = Join-Path $EXTRACT_DIR "mvm.exe"

    # Generate update.bat: handles file copy, setup, and cleanup
    # Fresh install: mvm.exe doesn't exist -> copy directly
    # Upgrade: mvm.exe is locked -> check every 100ms, prompt user after 3 seconds
    $SETUP_CMD = if ($USE_PREFIX) { "`"$MVM_DEST`" setup -p --tools all" } else { "`"$MVM_DEST`" setup" }
    $UPDATE_BAT = Join-Path $TMP_DIR "update.bat"
    $batLines = @(
        "@echo off",
        "chcp 65001 >nul",
        "if not exist `"$MVM_DEST`" (",
        "    echo Installing mvm...",
        "    copy /Y `"$MVM_SRC`" `"$MVM_DEST`"",
        "    if errorlevel 1 (",
        "        echo Installation failed, please retry",
        "        pause",
        "        exit /b 1",
        "    )",
        "    goto setup",
        ")",
        "echo Upgrading mvm, waiting for process to exit...",
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
        "echo mvm process is still running, please close it manually and retry",
        "pause",
        "exit /b 1",
        ":setup",
        $SETUP_CMD,
        "if errorlevel 1 echo setup unavailable, please retry later to update shims",
        "rmdir /s /q `"$TMP_DIR`"",
        "echo Done!",
        "pause"
    )
    $batLines -join "`r`n" | Set-Content -Path $UPDATE_BAT -Encoding UTF8

    Write-Host "Starting installer..."
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$UPDATE_BAT`""
} else {
    # Local build mode
    moon build --release
    $exit = $LASTEXITCODE

    if ($exit -eq 0) {
        # Clear previous logs
        Clear-Host
    }
    else {
        exit $exit
    }

    $BUILD_DIR = "_build/native/release/build/cmd/main"
    $MVM_EXE = Join-Path $BUILD_DIR "main.exe"
    
    if (-not (Test-Path $MVM_EXE)) {
        Write-Error "Build failed, executable not found: $MVM_EXE"
        exit 1
    }
    
    Copy-Item -Path $MVM_EXE -Destination (Join-Path $BIN_DIR "mvm.exe") -Force

    # Run setup (create tool scripts, configure PATH, etc.)
    # In prefix mode, automatically manage all tools (--tools all) since prefix doesn't affect existing tools
    if ($USE_PREFIX) { & (Join-Path $BIN_DIR "mvm.exe") setup '-p' '--tools' 'all' } else { & (Join-Path $BIN_DIR "mvm.exe") setup }
}