#!/bin/bash

set -e  # 碰到错误中止脚本执行
set -o pipefail  # 捕获管道中的错误

# 从环境变量读取配置
GITEA_URL="${GITEA_URL:-https://your-gitea.example.com}"
GITEA_TOKEN="${GITEA_TOKEN:-YOUR_GITEA_TOKEN}"
GITEA_OWNER="${GITEA_OWNER:-your-gitea-username}"  # 设置目标组织名或用户名
VISIBILITY="${VISIBILITY:-public}"        # 可改成 private

BASE_DIR="${BASE_DIR:-/root/ghorg/repos}"  # 克隆的本地仓库目录

# 遍历克隆目录下的每个子目录
for repo in "${BASE_DIR}"/*/; do
  repo_name=$(basename "$repo")  # 获取仓库目录名作为仓库名称
  echo "=====> Processing repository: $repo_name"

  cd "$repo"

  # 确保目录是个有效的 Git 仓库
  if [ ! -d ".git" ]; then
    echo "⚠️  Warning: Skipping $repo_name, not a valid Git repository."
    continue
  fi

  # 创建 Gitea 远程仓库
  echo "Creating repository $repo_name on Gitea..."
  create_repo_response=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$GITEA_URL/api/v1/orgs/$GITEA_OWNER/repos" \
    -H "Authorization: token $GITEA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
          \"name\": \"$repo_name\",
          \"private\": $( [[ "$VISIBILITY" == "private" ]] && echo true || echo false ),
          \"autoinit\": false
        }")

  # 检查 API 响应状态码
  if [[ "$create_repo_response" -eq 409 ]]; then
    echo "⚠️  Repository $repo_name already exists on Gitea, skipping creation."
  elif [[ "$create_repo_response" -ne 201 ]]; then
    echo "❌ Error: Failed to create repository $repo_name on Gitea. HTTP status code: $create_repo_response"
    continue
  else
    echo "✅ Repository $repo_name successfully created on Gitea."
  fi

  # 检查是否已存在 'gitea' 远程
  if git remote | grep -q "^gitea$"; then
    echo "Updating remote 'gitea' for $repo_name."
    git remote set-url gitea "$GITEA_URL/$GITEA_OWNER/$repo_name.git"
  else
    echo "Adding remote 'gitea' for $repo_name."
    git remote add gitea "$GITEA_URL/$GITEA_OWNER/$repo_name.git"
  fi

  # 推送所有分支和标签到 Gitea
  echo "Pushing local branches to Gitea for $repo_name..."
  git push gitea --all --force
  git push gitea --tags --force

  echo "✅ Successfully pushed $repo_name to Gitea."
  cd ..
done

echo "🎉 All repositories have been processed."