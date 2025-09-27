# GitHub 到 Gitea/GitLab 自动备份

使用 GitHub Actions 每天自动将 GitHub 仓库备份到 Gitea 或 GitLab。

## 功能特点

- 🔧 支持 Gitea 和 GitLab 双平台备份
- ⏰ 每天凌晨 2 点自动执行
- 🚀 支持手动触发备份
- 📦 使用 ghorg 高效克隆所有仓库
- 🔒 支持公开和私有仓库备份

## 快速开始

### 1. 准备工作

#### Github 备份配置：
- （可选）自定义 GitHub 访问令牌（需要有repo权限）

如果不设置，脚本将使用 GitHub Actions 默认的 `GITHUB_TOKEN`。但是经过测试，默认令牌获取到的仓库数量有限（40个），建议创建一个新的个人访问令牌。

#### Gitea 备份配置：
- Gitea 服务器地址
- Gitea 访问令牌（需要有repo、user权限）
- 目标组织或用户名

#### GitLab 备份配置：
- GitLab 服务器地址
- GitLab 访问令牌（需要有创建项目、读写权限）
- 目标群组或用户名

### 2. 配置 GitHub Secrets

在 GitHub 仓库设置中，添加以下 Secrets：

#### 基础配置：
- `BACKUP_GITEA`: `true` 或 `false`
- `BACKUP_GITLAB`: `true` 或 `false`
- `VISIBILITY`: `public` 或 `private`

#### Github 配置：
- `CUSTOM_GITHUB_TOKEN`: GitHub 访问令牌（需要有repo权限）（可选）

#### Gitea 配置：
- `GITEA_HOST`: Gitea 服务器主机名，如 `git.example.com`
- `GITEA_TOKEN`: Gitea 访问令牌
- `GITEA_OWNER`: 目标组织或用户名

#### GitLab 配置：
- `GITLAB_HOST`: GitLab 服务器主机名，如 `gitlab.com`
- `GITLAB_TOKEN`: GitLab 访问令牌
- `GITLAB_OWNER`: 目标群组或用户名

### 3. 手动测试运行

在 GitHub Actions 页面，手动触发工作流以确保配置正确。

## 文件说明

- `backup-to-gitea.sh` - 备份到 Gitea 的脚本
- `backup-to-gitlab.sh` - 备份到 GitLab 的脚本
- `.github/workflows/backup.yml` - GitHub Actions 工作流配置

## 自定义配置

### 修改备份时间

编辑 `.github/workflows/backup.yml` 中的 cron 表达式：

```yaml
schedule:
  - cron: '0 2 * * *'  # 每天凌晨 2 点
```

### 备份到 Gitea

设置 GitHub Secrets：`BACKUP_GITEA=true`

### 备份到 GitLab

设置 GitHub Secrets：`BACKUP_GITLAB=true`

## 注意事项

- Gitea/GitLab 用户需要有足够的权限创建仓库
- 运行可能需要较长时间，取决于仓库数量
- 建议先在测试环境验证配置正确性
- 备份过程会强制推送所有分支和标签
