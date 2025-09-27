#!/bin/bash

set -e
set -o pipefail

# 从环境变量读取配置
GITLAB_URL="${GITLAB_URL:-https://your-gitlab.example.com}"
GITLAB_TOKEN="${GITLAB_TOKEN:-YOUR_GITLAB_TOKEN}"
GITLAB_NAMESPACE="${GITLAB_NAMESPACE:-your-gitlab-namespace}"  # 设置目标群组名或用户名
VISIBILITY="${VISIBILITY:-public}"

BASE_DIR="${BASE_DIR:-/root/ghorg/repos}"

for repo in "${BASE_DIR}"/*/; do
  repo_name=$(basename "$repo")
  echo "=====> Processing repository: $repo_name"

  cd "$repo"

  if [ ! -d ".git" ]; then
    echo "⚠️  Warning: Skipping $repo_name, not a valid Git repository."
    continue
  fi

  # 创建 GitLab 项目
  echo "Creating project $repo_name on GitLab..."
  create_project_response=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$GITLAB_URL/api/v4/projects" \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
          \"name\": \"$repo_name\",
          \"namespace_id\": \"$GITLAB_NAMESPACE\",
          \"visibility\": \"$VISIBILITY\",
          \"initialize_with_readme\": false
        }")

  if [[ "$create_project_response" -eq 400 ]]; then
    echo "⚠️  Project $repo_name already exists on GitLab, skipping creation."
  elif [[ "$create_project_response" -ne 201 ]]; then
    echo "❌ Error: Failed to create project $repo_name on GitLab. HTTP status code: $create_project_response"
    continue
  else
    echo "✅ Project $repo_name successfully created on GitLab."
  fi

  if git remote | grep -q "^gitlab$"; then
    echo "Updating remote 'gitlab' for $repo_name."
    git remote set-url gitlab "$GITLAB_URL/$GITLAB_NAMESPACE/$repo_name.git"
  else
    echo "Adding remote 'gitlab' for $repo_name."
    git remote add gitlab "$GITLAB_URL/$GITLAB_NAMESPACE/$repo_name.git"
  fi

  echo "Pushing local branches to GitLab for $repo_name..."
  git push gitlab --all --force
  git push gitlab --tags --force

  echo "✅ Successfully pushed $repo_name to GitLab."
  cd ..
done

echo "🎉 All repositories have been processed."