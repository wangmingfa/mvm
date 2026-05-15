#!/usr/bin/env bash
set -euo pipefail

# =============================
# 删除 Git Tags 的交互式脚本
# 支持：↑↓导航、空格切换、a全选、i反选、回车确认、q退出
# =============================

# 拉取远程最新 tags
git fetch --tags 2>/dev/null

# 获取所有 tags，按名称排序
mapfile -t tags < <(git tag --list | sort)
total=${#tags[@]}

if [[ $total -eq 0 ]]; then
  echo "没有找到任何 tag"
  exit 0
fi

# 选中状态数组：0=未选，1=选中
selected=()
for ((i = 0; i < total; i++)); do
  selected[i]=0
done

cursor=0

# =============================
# 渲染菜单
# =============================
render_menu() {
  clear
  echo "🗑️  Git Tags 管理（共 $total 个）"
  echo
  echo "操作：↑↓导航 | 空格切换 | a全选 | i反选 | 回车确认删除 | q退出"
  echo

  for i in "${!tags[@]}"; do
    local mark
    if [[ ${selected[i]} -eq 1 ]]; then
      mark="\033[1;32m✓\033[0m"
    else
      mark="\033[2m☐\033[0m"
    fi

    if [[ $i -eq $cursor ]]; then
      printf "  \033[1;36m❯\033[0m [%s] %s\n" "$mark" "${tags[i]}"
    else
      printf "    [%s] %s\n" "$mark" "${tags[i]}"
    fi
  done

  # 底部状态栏
  local count=0
  for s in "${selected[@]}"; do
    [[ $s -eq 1 ]] && ((count++))
  done
  echo
  echo "已选中：$count / $total"
}

# =============================
# 读取按键
# =============================
read_key() {
  local key
  IFS= read -rsn1 key
  # 处理多字节序列（方向键等）
  if [[ $key == $'\x1b' ]]; then
    IFS= read -rsn2 -t0.01 key
    key="$'\x1b'$key"
  fi
  echo "$key"
}

# =============================
# 交互主循环
# =============================
while true; do
  render_menu
  key=$(read_key)

  case "$key" in
    $'\x1b[A') # ↑
      ((cursor--))
      ((cursor < 0)) && cursor=$((total - 1))
      ;;
    $'\x1b[B') # ↓
      ((cursor++))
      ((cursor >= total)) && cursor=0
      ;;
    ' ') # 空格：切换当前项
      selected[cursor]=$((1 - selected[cursor]))
      ;;
    'a') # 全选
      for ((i = 0; i < total; i++)); do
        selected[i]=1
      done
      ;;
    'i') # 反选
      for ((i = 0; i < total; i++)); do
        selected[i]=$((1 - selected[i]))
      done
      ;;
    '') # 回车：确认
      break
      ;;
    'q') # 退出
      echo
      echo "已取消"
      exit 0
      ;;
    $'\x03') # Ctrl+C
      echo
      echo "已取消"
      exit 0
      ;;
  esac
done

# =============================
# 收集选中的 tags
# =============================
to_delete=()
for i in "${!tags[@]}"; do
  if [[ ${selected[i]} -eq 1 ]]; then
    to_delete+=("${tags[i]}")
  fi
done

if [[ ${#to_delete[@]} -eq 0 ]]; then
  clear
  echo "没有选中任何 tag，已取消"
  exit 0
fi

# =============================
# 最终确认
# =============================
clear
echo "⚠️  将删除以下 ${#to_delete[@]} 个 tag（本地 + 远程）："
echo
for t in "${to_delete[@]}"; do
  printf "  \033[1;31m✗\033[0m %s\n" "$t"
done
echo
read -rp "确认删除？(y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "已取消"
  exit 0
fi

# =============================
# 执行删除
# =============================
echo
success=0
fail=0

for t in "${to_delete[@]}"; do
  # 删除本地 tag
  if git tag -d "$t" 2>/dev/null; then
    # 删除远程 tag
    if git push origin --delete "$t" 2>/dev/null; then
      echo "  ✅ 已删除: $t"
      ((success++))
    else
      echo "  ⚠️  本地已删除，远程删除失败: $t（可能远程不存在）"
      ((success++))
    fi
  else
    echo "  ❌ 删除失败: $t"
    ((fail++))
  fi
done

echo
echo "🎉 完成！成功删除 $success 个，失败 $fail 个"
