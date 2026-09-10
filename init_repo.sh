#!/usr/bin/env bash
# init_repo.sh — 关联你的 GitHub 仓库并推送（支持 whyx）
#
# 用法:
#   ./init_repo.sh                       # 交互询问
#   ./init_repo.sh whyx                  # 推送到 <你的用户名>/whyx
#   ./init_repo.sh owner/whyx            # 推送到指定 owner/whyx
#   PAT=ghp_xxx  ./init_repo.sh whyx     # 用 PAT 免交互直推（沙盒/CI 推荐）
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# 1) 目标仓库
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  read -r -p "目标仓库 (例如 whyx 或 owner/whyx): " TARGET
fi
if [[ "$TARGET" != */* ]]; then
  # 仅给了仓库名 -> 用当前 gh 认证用户
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    OWNER="$(gh api /user --jq .login)"
  else
    read -r -p "GitHub 用户名 (owner): " OWNER
  fi
  TARGET="$OWNER/$TARGET"
fi
echo "目标仓库: $TARGET"

# 2) 若提供了 PAT，走纯 git 推送（不依赖 gh CLI）
if [[ -n "$PAT" ]]; then
  echo "使用 PAT 推送..."
  REMOTE="https://x-access-token:${PAT}@github.com/${TARGET}.git"
  git init -b main >/dev/null 2>&1 || true
  git checkout -B main
  git config user.name "NetShooter Bot" 2>/dev/null || true
  git config user.email "netshooter@example.com" 2>/dev/null || true
  # 创建仓库（已存在则忽略）
  curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${PAT}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${TARGET##*/}\",\"private\":false,\"auto_init\":false}" \
    "https://api.github.com/user/repos" >/dev/null || true
  git remote remove origin 2>/dev/null || true
  git remote add origin "$REMOTE"
  git add -A
  git commit -m "feat: complete NetShooter project (Godot 4.3)" || true
  git push -u origin main --force
  git tag -f v1.0.0
  git push origin --tags --force
  # 移除令牌痕迹
  git remote set-url origin "https://github.com/${TARGET}.git"
  echo "完成: https://github.com/${TARGET}"
  exit 0
fi

# 3) 否则尝试 gh CLI
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo "使用 gh CLI..."
  gh repo create "${TARGET##*/}" --public --source=. --remote=origin --push 2>/dev/null || \
    git remote add origin "https://github.com/${TARGET}.git"
  git push -u origin main 2>/dev/null || true
  git tag v1.0.0 2>/dev/null || true
  git push origin --tags 2>/dev/null || true
  exit 0
fi

# 4) 兜底: SSH
echo "使用 SSH..."
git remote add origin "git@github.com:${TARGET}.git" 2>/dev/null || true
git push -u origin main
git tag v1.0.0
git push origin --tags
