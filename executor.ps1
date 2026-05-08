# 检查 PowerShell 版本（必须 >= 7）
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "错误：此脚本需要 PowerShell 7 或更高版本。当前版本：$($PSVersionTable.PSVersion)。请访问 https://aka.ms/powershell 升级。" -ForegroundColor Red
    exit 1
}

$ScriptName = Split-Path -Leaf $MyInvocation.MyCommand.Definition
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$mvmPath = Join-Path $ScriptDir "mvm.exe"

# 构建命令参数
if ($ScriptName -eq "executor.ps1") {
    # 直接运行：.\executor.ps1 node -v
    if ($args.Count -eq 0) {
        Write-Host "错误：缺少参数。示例：.\executor.ps1 node -v"
        exit 1
    }
    $cmdArgs = @("executor") + $args
} else {
    # 兼容软连接/别名的方式，比如：f_node -v
    $cmdArgs = @("executor") + @($ScriptName) + $args
}

# debug 日志
$logLevel = if ($env:MVM_LOG_LEVEL) { $env:MVM_LOG_LEVEL.ToLower() } else { "" }
if ($logLevel -eq "debug") {
    if (Test-Path $mvmPath) {
        Write-Host "运行: $mvmPath $cmdArgs"
    } else {
        Write-Host "运行: moon run cmd/main -- $cmdArgs"
    }
}

if (Test-Path $mvmPath) {
    & $mvmPath @cmdArgs
} else {
    & moon run cmd/main -- @cmdArgs
}

exit $LASTEXITCODE
