# 从 moonbitlang/skills 仓库同步内容到本地 .claude 目录
# 不使用 git submodule，避免 .git 目录冲突，确保可以正常提交

$SkillsRepo = "https://github.com/moonbitlang/skills.git"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectDir = Resolve-Path (Join-Path $ScriptDir "..")
$ClaudeDir = Join-Path $ProjectDir ".claude"
$TempDir = Join-Path $env:TEMP "mvm-skills-sync-$(Get-Random)"

Write-Host "=== 同步 moonbitlang/skills 到本地 .claude 目录 ==="
Write-Host ""

# 克隆 skills 仓库到临时目录
Write-Host "[1/4] 正在克隆仓库到临时目录..."
git clone $SkillsRepo "$TempDir\skills" 2>$null
if (-not $?) {
    Write-Host "错误：克隆失败，请检查网络连接或仓库地址"
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "      克隆完成"

# 移除所有 .git 目录和 .gitmodules 文件
Write-Host "[2/4] 正在清理 .git 相关文件..."
Get-ChildItem -Path "$TempDir\skills" -Recurse -Filter ".git" -Force | ForEach-Object {
    Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
}
Get-ChildItem -Path "$TempDir\skills" -Recurse -Filter ".gitmodules" -Force | ForEach-Object {
    Remove-Item -Force $_.FullName -ErrorAction SilentlyContinue
}
Write-Host "      清理完成"

# 确保 .claude 目录存在
if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
}

# 复制内容到 .claude 目录（保留本地新增的内容）
Write-Host "[3/4] 正在同步内容到 .claude 目录..."
# 使用 robocopy 进行增量同步（/MIR 会删除目标中多余的文件，所以使用 /E + /XC /XO 保留本地文件）
robocopy "$TempDir\skills" $ClaudeDir /E /XC /XO /XD .git /XF .gitmodules /NFL /NDL /NJH /NJS /NC /NS /NP
Write-Host "      同步完成"

# 清理临时目录
Write-Host "[4/4] 正在清理临时目录..."
Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
Write-Host "      清理完成"

Write-Host ""
Write-Host "=== 同步完成 ==="
Write-Host "提示：本地新增的文件（如自定义技能）不会被删除"
Write-Host "提示：如有冲突文件，上游版本会覆盖本地版本"
