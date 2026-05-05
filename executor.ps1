$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$mvmPath = Join-Path $ScriptDir "mvm.exe"

# 构建命令参数
$cmdArgs = @("executor") + $args

if (Test-Path $mvmPath) {
    & $mvmPath @cmdArgs 2>&1 | Out-Host
} else {
    moon run cmd/main -- executor @args 2>&1 | Out-Host
}

exit $LASTEXITCODE