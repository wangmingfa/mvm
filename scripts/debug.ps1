# Debug 模式运行脚本：临时设置 MVM_LOG_LEVEL=debug，运行完成后恢复原值

# 保存原始 MVM_LOG_LEVEL
$oldLevel = $env:MVM_LOG_LEVEL
$env:MVM_LOG_LEVEL = "debug"

moon run cmd/main @args
$exitCode = $LASTEXITCODE

# 恢复原始 MVM_LOG_LEVEL
if ($oldLevel) {
    $env:MVM_LOG_LEVEL = $oldLevel
} else {
    Remove-Item Env:MVM_LOG_LEVEL -ErrorAction SilentlyContinue
}

exit $exitCode
