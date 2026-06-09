#!/usr/bin/env bash
set -euo pipefail

# =============================
# bump-tag.sh - Git 语义化版本 tag 管理工具
# =============================
#
# 用法:
#   ./bump-tag.sh              交互式选择版本升级类型（major/minor/patch），带确认提示
#   ./bump-tag.sh -y           交互式选择版本升级类型，跳过确认提示
#   ./bump-tag.sh major        自动升级主版本号（如 v1.2.3 → v2.0.0）
#   ./bump-tag.sh minor        自动升级次版本号（如 v1.2.3 → v1.3.0）
#   ./bump-tag.sh patch        自动升级补丁版本号（如 v1.2.3 → v1.2.4）
#   ./bump-tag.sh -d           删除并重新发布当前最新 tag，带确认提示
#   ./bump-tag.sh -d -y        删除并重新发布当前最新 tag，跳过确认提示
#   ./bump-tag.sh -dy          删除并重新发布当前最新 tag，跳过确认提示（合并选项）
#   ./bump-tag.sh -yd          删除并重新发布当前最新 tag，跳过确认提示（合并选项）
#   ./bump-tag.sh -h           显示帮助信息
#
# 选项:
#   -y    自动模式，跳过所有确认提示
#   -d    删除模式，删除并重新发布当前最新 tag（不升级版本号）
#
# 说明:
#   - 脚本会自动从远程拉取最新 tag 作为基准版本
#   - 如果没有 tag，默认从 v0.0.0 开始
#   - 指定版本类型（major/minor/patch）时自动进入自动模式（隐含 -y）
#   - 交互模式下使用 ↑ ↓ 方向键选择，回车确认
#
# =============================
# 解析参数
# =============================
auto_mode=false
delete_mode=false
selected=2

show_help() {
  echo "用法: $0 [-y] [-d] [major|minor|patch]"
  echo
  echo "Git 语义化版本 tag 管理工具"
  echo
  echo "选项:"
  echo "  -y    自动模式，跳过所有确认提示"
  echo "  -d    删除模式，删除并重新发布当前最新 tag"
  echo
  echo "版本类型:"
  echo "  major 升级主版本号 (v1.2.3 → v2.0.0)"
  echo "  minor 升级次版本号 (v1.2.3 → v1.3.0)"
  echo "  patch 升级补丁版本号 (v1.2.3 → v1.2.4)"
  echo
  echo "示例:"
  echo "  $0              交互式选择版本升级类型"
  echo "  $0 patch        自动升级补丁版本号"
  echo "  $0 -d -y        删除并重新发布当前 tag，跳过确认"
  exit 1
}

while getopts "ydh" opt; do
  case "$opt" in
    y) auto_mode=true ;;
    d) delete_mode=true ;;
    h) show_help ;;
    *) show_help ;;
  esac
done

# =============================
# 拉取远程最新 tags
# =============================
git fetch --tags

# =============================
# 获取最新 tag
# =============================
latest_tag=$(git tag --list 'v*' --sort=-v:refname | head -n 1)
[[ -z "$latest_tag" ]] && latest_tag="v0.0.0"

version="${latest_tag#v}"
IFS='.' read -r major minor patch <<< "$version"

# =============================
# 删除并重新发布模式
# =============================
if [[ "$delete_mode" == true ]]; then
  echo "⚠️  将删除并重新发布当前 tag: $latest_tag"
  echo

  if [[ "$auto_mode" == false ]]; then
    read -rp "确认删除并重新发布？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "已取消"
      exit 0
    fi
  fi

  git tag -d "$latest_tag"
  git push origin --delete "$latest_tag" 2>/dev/null || true
  echo "已删除远程 tag: $latest_tag"
  echo

  # 删除模式下直接重新发布同一个 tag
  echo "正在重新发布 tag: $latest_tag"
  git tag "$latest_tag"
  git push origin "$latest_tag"

  echo
  echo "✅ 已成功重新发布 tag: $latest_tag"
  exit 0
fi

# =============================
# 处理可选的位置参数（版本类型）
# =============================
shift $((OPTIND - 1))
if [[ $# -ge 1 ]]; then
  case "$1" in
    major) selected=0; auto_mode=true ;;
    minor) selected=1; auto_mode=true ;;
    patch) selected=2; auto_mode=true ;;
    *) echo "错误: 无效的版本类型 '$1'" && exit 1 ;;
  esac
fi

# =============================
# 菜单配置
# =============================
options=(
  "major  → $((major + 1)).0.0"
  "minor  → $major.$((minor + 1)).0"
  "patch  → $major.$minor.$((patch + 1))"
)

# =============================
# 渲染菜单
# =============================
render_menu() {
  clear
  echo "当前最新 tag: $latest_tag"
  echo
  echo "使用 ↑ ↓ 选择版本升级类型，回车确认"
  echo

  for i in "${!options[@]}"; do
    if [[ $i -eq $selected ]]; then
      printf "  \033[1;32m❯ %s\033[0m\n" "${options[$i]}"
    else
      printf "    %s\n" "${options[$i]}"
    fi
  done
}

# =============================
# 读取按键（稳定版）
# =============================
read_key() {
  local key
  IFS= read -rsn3 key
  echo "$key"
}

# =============================
# 交互主循环（非自动模式）
# =============================
if [[ "$auto_mode" == false ]]; then
  while true; do
    render_menu
    key=$(read_key)

    case "$key" in
      $'\x1b[A') # ↑
        ((selected--))
        ((selected < 0)) && selected=$((${#options[@]} - 1))
        ;;
      $'\x1b[B') # ↓
        ((selected++))
        ((selected >= ${#options[@]})) && selected=0
        ;;
      '') # Enter（read -n3 时回车是空串）
        break
        ;;
      $'\x03') # Ctrl+C
        echo
        echo "已取消"
        exit 0
        ;;
    esac
  done
fi

# =============================
# 计算新版本
# =============================
case "$selected" in
  0)
    major=$((major + 1)); minor=0; patch=0 ;;
  1)
    minor=$((minor + 1)); patch=0 ;;
  2)
    patch=$((patch + 1)) ;;
esac

new_tag="v$major.$minor.$patch"

# =============================
# 最终确认
# =============================
clear
echo "当前 tag : $latest_tag"
echo "新 tag   : $new_tag"
echo

if [[ "$auto_mode" == true ]]; then
  echo "自动模式：直接创建并推送 tag"
else
  read -rp "确认创建并推送该 tag？(y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
  fi
fi

# =============================
# 创建并推送 tag
# =============================
git tag "$new_tag"
git push origin "$new_tag"

echo
echo "✅ 已成功创建并推送 tag: $new_tag"
