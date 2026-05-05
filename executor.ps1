$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$mvmPath = Join-Path $ScriptDir "mvm.exe"

# 构建命令参数
$cmdArgs = @("executor") + $args

if (Test-Path $mvmPath) {
    & $mvmPath @cmdArgs
} else {
    moon run cmd/main -- executor @args
}

exit $LASTEXITCODE
