#!/bin/sh

# 从 moonbitlang/skills 仓库同步内容到本地 .claude 目录
# 不使用 git submodule，避免 .git 目录冲突，确保可以正常提交

SKILLS_REPO="https://github.com/moonbitlang/skills.git"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR="${SCRIPT_DIR}/.."
CLAUDE_DIR="${PROJECT_DIR}/.claude"
TEMP_DIR=$(mktemp -d)

echo "=== 同步 moonbitlang/skills 到本地 .claude 目录 ==="
echo ""

# 克隆 skills 仓库到临时目录
echo "[1/4] 正在克隆仓库到临时目录..."
if ! git clone "$SKILLS_REPO" "$TEMP_DIR/skills" 2>/dev/null; then
    echo "错误：克隆失败，请检查网络连接或仓库地址"
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo "      克隆完成"

# 移除所有 .git 目录和 .gitmodules 文件，避免子模块残留
echo "[2/4] 正在清理 .git 相关文件..."
find "$TEMP_DIR/skills" -name ".git" -type f -delete
find "$TEMP_DIR/skills" -name ".git" -type d -exec rm -rf {} + 2>/dev/null
find "$TEMP_DIR/skills" -name ".gitmodules" -type f -delete
echo "      清理完成"

# 确保 .claude 目录存在
if [ ! -d "$CLAUDE_DIR" ]; then
    mkdir -p "$CLAUDE_DIR"
fi

# 使用 rsync 同步内容（不删除本地新增的内容）
# --exclude 排除不需要同步的内容
echo "[3/4] 正在同步内容到 .claude 目录..."
if command -v rsync >/dev/null 2>&1; then
    rsync -av \
        --exclude='.git' \
        --exclude='.gitmodules' \
        "$TEMP_DIR/skills/" "$CLAUDE_DIR/"
else
    # 没有 rsync 时使用 cp
    cp -r "$TEMP_DIR/skills/"* "$CLAUDE_DIR/"
fi
echo "      同步完成"

# 清理临时目录
echo "[4/4] 正在清理临时目录..."
rm -rf "$TEMP_DIR"
echo "      清理完成"

echo ""
echo "=== 同步完成 ==="
echo "提示：本地新增的文件（如自定义技能）不会被删除"
echo "提示：如有冲突文件，上游版本会覆盖本地版本"
