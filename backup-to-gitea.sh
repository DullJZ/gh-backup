#!/bin/bash

# 不使用 set -e，以便在错误时继续处理下一个仓库
set -o pipefail  # 捕获管道中的错误

# 从环境变量读取配置
GITEA_HOST="${GITEA_HOST:-gitea.example.com}"
GITEA_TOKEN="${GITEA_TOKEN:-YOUR_GITEA_TOKEN}"
GITEA_OWNER="${GITEA_OWNER:-your-gitea-username}"  # 设置目标组织名或用户名
VISIBILITY="${VISIBILITY:-private}"

BASE_DIR="${BASE_DIR:-/root/ghorg/repos}"  # 克隆的本地仓库目录

# 遍历克隆目录下的每个子目录
for repo in "$HOME/ghorg/${BASE_DIR}"/*/; do
  repo_name=$(basename "$repo")  # 获取仓库目录名作为仓库名称
  echo "=====> Processing repository: $repo_name"

  cd "$repo"

  # 确保目录是个有效的 Git 仓库
  if [ ! -d ".git" ]; then
    echo "⚠️  Warning: Skipping $repo_name, not a valid Git repository."
    continue
  fi

  # 创建 Gitea 远程仓库
  # 首先尝试创建个人仓库
  echo "Creating repository $repo_name on Gitea..."
  create_repo_response=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://${GITEA_HOST}/api/v1/user/repos" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
          \"name\": \"${repo_name}\",
          \"private\": $( [[ "${VISIBILITY}" == "private" ]] && echo true || echo false ),
          \"autoinit\": false
        }")

  # 检查 API 响应状态码
  if [[ "$create_repo_response" -eq 409 ]]; then
    echo "⚠️  Repository $repo_name already exists on Gitea, skipping creation."
  elif [[ "$create_repo_response" -eq 403 ]]; then
    echo "⚠️  Permission denied, trying to create as organization..."
    # 尝试作为组织仓库创建
    create_org_response=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "https://${GITEA_HOST}/api/v1/orgs/${GITEA_OWNER}/repos" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
            \"name\": \"${repo_name}\",
            \"private\": $( [[ "${VISIBILITY}" == "private" ]] && echo true || echo false ),
            \"autoinit\": false
          }")
    if [[ "$create_org_response" -eq 201 ]]; then
      echo "✅ Repository $repo_name successfully created on Gitea organization."
    elif [[ "$create_org_response" -eq 409 ]]; then
      echo "⚠️  Repository $repo_name already exists on Gitea organization, skipping creation."
    else
      echo "❌ Error: Failed to create repository $repo_name on Gitea organization. HTTP status code: $create_org_response"
      continue
    fi
  elif [[ "$create_repo_response" -ne 201 ]]; then
    echo "❌ Error: Failed to create repository $repo_name on Gitea. HTTP status code: $create_repo_response"
    continue
  else
    echo "✅ Repository $repo_name successfully created on Gitea."
  fi

  # 设置带 token 的远程地址，避免每次推送都输入用户名密码
  git_url="https://${GITEA_OWNER}:${GITEA_TOKEN}@${GITEA_HOST}/${GITEA_OWNER}/${repo_name}.git"
  if git remote | grep -q "^gitea$"; then
    echo "Updating remote 'gitea' for $repo_name."
    git remote set-url gitea "$git_url"
  else
    echo "Adding remote 'gitea' for $repo_name."
    git remote add gitea "$git_url"
  fi

  # 推送所有分支和标签到 Gitea的函数，包含重试机制
  push_with_retry() {
    local remote=$1
    local args=$2
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
      if git push $remote $args 2>&1; then
        echo "✅ Successfully pushed $args to $remote"
        return 0
      else
        local push_exit_code=$?
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
          echo "⚠️ Push failed (exit code: $push_exit_code), retrying in 5 seconds... (Attempt $retry_count/$max_retries)"
          sleep 5
        else
          echo "⚠️ Failed to push $args to $remote after $max_retries attempts (exit code: $push_exit_code), continuing to next repository"
          return 1
        fi
      fi
    done
  }

  # 推送所有分支和标签到 Gitea
  echo "Pushing local branches to Gitea for $repo_name..."
  push_with_retry gitea "--all --force"
  if [ $? -eq 0 ]; then
    push_with_retry gitea "--tags --force"
  fi

  if [ $? -eq 0 ]; then
    echo "✅ Successfully pushed $repo_name to Gitea."
  else
    echo "⚠️ Skipped pushing some branches/tags for $repo_name due to errors, continuing to next repository."
  fi
  cd .. || true
done

echo "🎉 All repositories have been processed."