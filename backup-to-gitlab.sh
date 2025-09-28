#!/bin/bash

set -e
set -o pipefail

# 从环境变量读取配置
GITLAB_HOST="${GITLAB_HOST:-gitlab.com}"
GITLAB_TOKEN="${GITLAB_TOKEN:-YOUR_GITLAB_TOKEN}"
GITLAB_OWNER="${GITLAB_OWNER:-your-gitlab-username-or-group}"  # 设置目标群组名或用户名
VISIBILITY="${VISIBILITY:-private}"

BASE_DIR="${BASE_DIR:-/root/ghorg/repos}"

for repo in "$HOME/ghorg/${BASE_DIR}"/*/; do
  repo_name=$(basename "$repo")
  echo "=====> Processing repository: $repo_name"

  cd "$repo"

  if [ ! -d ".git" ]; then
    echo "⚠️  Warning: Skipping $repo_name, not a valid Git repository."
    continue
  fi

  # 创建 GitLab 项目
  echo "Creating project $repo_name on GitLab..."
  create_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://${GITLAB_HOST}/api/v4/projects" \
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
          \"name\": \"${repo_name}\",
          \"visibility\": \"${VISIBILITY}\",
          \"initialize_with_readme\": false
        }")
  [[ "$create_code" -ne 201 && "$create_code" -ne 400 ]] \
    && echo "❌ Create project failed: HTTP $create_code" && continue

  # 设置带 token 的远程地址，避免每次推送都输入用户名密码
  git_url="https://token:${GITLAB_TOKEN}@${GITLAB_HOST}/${GITLAB_OWNER}/${repo_name}.git"
  if git remote | grep -q "^gitlab$"; then
    echo "Updating remote 'gitlab' for $repo_name."
    git remote set-url gitlab "$git_url"
  else
    echo "Adding remote 'gitlab' for $repo_name."
    git remote add gitlab "$git_url"
  fi

# 推送所有分支和标签到 GitLab的函数，包含重试机制
  push_with_retry() {
    local remote=$1
    local args=$2
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
      if git push $remote $args; then
        echo "✅ Successfully pushed $args to $remote"
        return 0
      else
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
          echo "⚠️ Push failed, retrying in 5 seconds... (Attempt $retry_count/$max_retries)"
          sleep 5
        else
          echo "❌ Failed to push $args to $remote after $max_retries attempts"
          return 1
        fi
      fi
    done
  }

  echo "Pushing local branches to GitLab for $repo_name..."
  push_with_retry gitlab "--all --force"
  push_with_retry gitlab "--tags --force"

  echo "✅ Successfully pushed $repo_name to GitLab."
  cd ..
done

echo "🎉 All repositories have been processed."