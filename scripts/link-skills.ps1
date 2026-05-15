$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ClaudeSkills = Join-Path $ScriptDir ".claude\skills"
$AicodeSkills = Join-Path $ScriptDir ".aicode\skills"

if (-not (Test-Path $ClaudeSkills)) {
    Write-Host "错误：未找到 .claude/skills 目录，请先初始化 git submodule"
    exit 1
}

if (-not (Test-Path $AicodeSkills)) {
    New-Item -ItemType Directory -Path $AicodeSkills -Force | Out-Null
}

$cleaned = 0
$linked = 0
$skipped = 0

# 清理失效的软连接
Get-ChildItem -Path $AicodeSkills | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } | ForEach-Object {
  if (-not (Test-Path $_.FullName)) {
    Write-Host "已清理失效链接: $($_.Name)"
    Remove-Item $_.FullName -Force
    $cleaned++
  }
}

if ($cleaned -gt 0) {
  Write-Host ""
}

Get-ChildItem -Path $ClaudeSkills -Directory | ForEach-Object {
    $skillName = $_.Name
    $linkPath = Join-Path $AicodeSkills $skillName

    if (Test-Path -Path $linkPath) {
        $item = Get-Item $linkPath
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "跳过（已存在）: $skillName"
        } else {
            Write-Host "跳过（存在同名非链接文件）: $skillName"
        }
        $skipped++
        return
    }

    $targetPath = Join-Path "..\..\.claude\skills" $skillName
    New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath -Force | Out-Null
    Write-Host "已链接: $skillName"
    $linked++
}

Write-Host ""
Write-Host "完成：清理 $cleaned 个失效链接，新建 $linked 个链接，跳过 $skipped 个"
