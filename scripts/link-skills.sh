#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CLAUDE_SKILLS="${SCRIPT_DIR}/.claude/skills"
AICODE_SKILLS="${SCRIPT_DIR}/.aicode/skills"

if [ ! -d "$CLAUDE_SKILLS" ]; then
  echo "错误：未找到 .claude/skills 目录，请先初始化 git submodule"
  exit 1
fi

mkdir -p "$AICODE_SKILLS"

cleaned=0
linked=0
skipped=0

# 清理失效的软连接
for link in "$AICODE_SKILLS"/*; do
  [ ! -L "$link" ] && continue
  if [ ! -e "$link" ]; then
    skill_name=$(basename "$link")
    rm "$link"
    echo "已清理失效链接: $skill_name"
    cleaned=$((cleaned + 1))
  fi
done

if [ $cleaned -gt 0 ]; then
  echo ""
fi

for skill_dir in "$CLAUDE_SKILLS"/*/; do
  [ ! -d "$skill_dir" ] && continue
  skill_name=$(basename "$skill_dir")
  link_path="${AICODE_SKILLS}/${skill_name}"

  if [ -L "$link_path" ]; then
    echo "跳过（已存在）: $skill_name"
    skipped=$((skipped + 1))
    continue
  fi

  if [ -e "$link_path" ]; then
    echo "跳过（存在同名非链接文件）: $skill_name"
    skipped=$((skipped + 1))
    continue
  fi

  ln -s "../../.claude/skills/${skill_name}" "$link_path"
  echo "已链接: $skill_name"
  linked=$((linked + 1))
done

echo ""
echo "完成：清理 ${cleaned} 个失效链接，新建 ${linked} 个链接，跳过 ${skipped} 个"
