#!/usr/bin/env bash
set -euo pipefail

# 获取最新 tag（按版本号排序）
LATEST_TAG=$(git tag --sort=-version:refname | head -n 1)

if [[ -z "$LATEST_TAG" ]]; then
  echo "没有找到任何 tag，退出。"
  exit 1
fi

echo "最新 tag：$LATEST_TAG"
echo ""
read -r -p "确认删除该 tag？输入 y 并按回车继续，其它操作将取消：" CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
  echo "已取消。"
  exit 0
fi

# 删除本地 tag
git tag -d "$LATEST_TAG"
echo "已删除本地 tag：$LATEST_TAG"

# 删除远程 tag（若远程存在）
if git ls-remote --tags origin "$LATEST_TAG" | grep -q "$LATEST_TAG"; then
  git push origin ":refs/tags/$LATEST_TAG"
  echo "已删除远程 tag：$LATEST_TAG"
else
  echo "远程不存在该 tag，跳过远程删除。"
fi
