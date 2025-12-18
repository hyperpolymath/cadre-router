# cadre-router

Hub-and-spoke Git repository mirroring infrastructure. Automatically mirrors repositories from GitHub to GitLab, Codeberg, and Bitbucket.

## Overview

This repository provides a GitHub Actions workflow that enables one-way mirroring of your repository to multiple Git hosting platforms. This ensures your code is available across platforms for redundancy, accessibility, and community reach.

## Supported Mirrors

| Platform   | URL Pattern                                    |
|------------|------------------------------------------------|
| GitLab     | `git@gitlab.com:hyperpolymath/<repo>.git`      |
| Codeberg   | `git@codeberg.org:hyperpolymath/<repo>.git`    |
| Bitbucket  | `git@bitbucket.org:hyperpolymath/<repo>.git`   |

## Setup

### 1. Configure Repository Variables

Enable mirrors by setting these repository variables (Settings > Secrets and variables > Actions > Variables):

| Variable                   | Value  | Description              |
|----------------------------|--------|--------------------------|
| `GITLAB_MIRROR_ENABLED`    | `true` | Enable GitLab mirroring  |
| `CODEBERG_MIRROR_ENABLED`  | `true` | Enable Codeberg mirroring|
| `BITBUCKET_MIRROR_ENABLED` | `true` | Enable Bitbucket mirroring|

### 2. Configure SSH Keys

Add SSH private keys as organization or repository secrets (Settings > Secrets and variables > Actions > Secrets):

| Secret             | Description                           |
|--------------------|---------------------------------------|
| `GITLAB_SSH_KEY`   | SSH private key for GitLab access     |
| `CODEBERG_SSH_KEY` | SSH private key for Codeberg access   |
| `BITBUCKET_SSH_KEY`| SSH private key for Bitbucket access  |

**Generating SSH keys:**

```bash
# Generate a dedicated key for each platform
ssh-keygen -t ed25519 -C "github-mirror@example.com" -f gitlab_mirror_key
ssh-keygen -t ed25519 -C "github-mirror@example.com" -f codeberg_mirror_key
ssh-keygen -t ed25519 -C "github-mirror@example.com" -f bitbucket_mirror_key
```

Add the public keys (`.pub` files) to each platform's SSH key settings.

### 3. Create Target Repositories

Create empty repositories on each target platform with the same name as your GitHub repository.

## How It Works

1. **Trigger**: Workflow runs on push to `main`/`master` or manual dispatch
2. **Checkout**: Fetches full repository history
3. **SSH Setup**: Loads platform-specific SSH keys securely
4. **Host Verification**: Configures known_hosts to prevent MITM attacks
5. **Mirror**: Force-pushes all branches and tags to target platform

## Security Features

- **Pinned Actions**: All GitHub Actions pinned to commit SHA
- **Least Privilege**: Workflow uses `contents: read` permission only
- **Concurrency Control**: Prevents race conditions during parallel pushes
- **SSH Known Hosts**: Validates host keys to prevent MITM attacks
- **Secret Management**: SSH keys stored in GitHub encrypted secrets

## License

SPDX-License-Identifier: AGPL-3.0-or-later
