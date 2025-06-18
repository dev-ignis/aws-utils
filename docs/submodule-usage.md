# Using AWS Docker Deployment as a Git Submodule

## Overview

When this repository is used as a git submodule in your parent project, you need to follow specific procedures to update and manage it properly. This guide covers all aspects of submodule management.

## Initial Setup

### Adding as a Submodule

```bash
# In your parent repository
# Option 1: Use short name 'infra'
git submodule add https://github.com/dev-ignis/aws-docker-deployment.git infra
git commit -m "Add AWS infrastructure as submodule"

# Option 2: Use descriptive name 'infrastructure'
git submodule add https://github.com/dev-ignis/aws-docker-deployment.git infrastructure
git commit -m "Add AWS infrastructure as submodule"
```

### Cloning a Project with Submodules

```bash
# Clone with submodules initialized
git clone --recurse-submodules https://github.com/yourorg/yourproject.git

# Or if already cloned without submodules
git submodule init
git submodule update
```

## Updating the Submodule

### Method 1: Update to Latest Commit on Default Branch

```bash
# Navigate to parent project root
cd /path/to/parent-project

# Update submodule to latest commit
cd infra  # or 'infrastructure', wherever the submodule is located
git fetch origin
git checkout main  # or master, depending on default branch
git pull origin main

# Go back to parent project
cd ..

# Commit the submodule update in parent project
git add infra
git commit -m "Update infrastructure submodule to latest version"
git push
```

### Method 2: Update Using Submodule Commands

```bash
# From parent project root
# Update all submodules to latest
git submodule update --remote --merge

# Or update specific submodule
git submodule update --remote --merge infrastructure

# Commit the changes
git add infrastructure
git commit -m "Update infrastructure submodule"
git push
```

### Method 3: Update to Specific Version/Tag

```bash
cd infrastructure
git fetch --all --tags
git checkout v1.2.3  # or specific commit SHA

cd ..
git add infrastructure
git commit -m "Update infrastructure to version v1.2.3"
git push
```

## Common Workflows

### 1. Checking Current Submodule Version

```bash
# See current commit of submodule
git submodule status

# More detailed info
cd infrastructure
git log -1 --oneline
git describe --tags
```

### 2. Making Local Changes to Submodule

**Warning**: Making changes directly in a submodule can be risky. Consider these approaches:

#### Option A: Fork and Use Your Fork
```bash
# Fork the original repo on GitHub first, then:
cd infrastructure
git remote add myfork https://github.com/yourusername/aws-docker-deployment.git
git checkout -b my-feature
# Make changes
git push myfork my-feature
# Create PR to original repo if desired

# Update parent project to use your fork
cd ..
git config -f .gitmodules submodule.infrastructure.url https://github.com/yourusername/aws-docker-deployment.git
git add .gitmodules
git commit -m "Use forked infrastructure repo"
```

#### Option B: Override with Local Files
Create override files in your parent project:
```
parent-project/
├── infrastructure/          # Submodule
├── infrastructure-overrides/
│   ├── variables.tf        # Override variables
│   └── custom.tf          # Additional resources
```

### 3. Handling Submodule Conflicts

When pulling parent project updates that include submodule changes:

```bash
# If you see submodule conflicts after pull/merge
git status  # Shows modified: infrastructure (new commits)

# Option 1: Keep their version (from remote)
git checkout --theirs infrastructure
git add infrastructure

# Option 2: Keep your version
git checkout --ours infrastructure
git add infrastructure

# Option 3: Manually choose specific commit
cd infrastructure
git checkout <desired-commit-sha>
cd ..
git add infrastructure

# Complete the merge
git commit
```

### 4. Updating Team Members

After updating a submodule, team members need to sync:

```bash
# Team member pulls parent project updates
git pull

# Sync submodule to correct commit
git submodule update --init --recursive

# Or force update to match parent project
git submodule sync
git submodule update --init --recursive --force
```

## Best Practices

### 1. Version Pinning

Pin to specific tags/releases for stability:

```bash
cd infrastructure
git checkout v1.0.0
cd ..
git add infrastructure
git commit -m "Pin infrastructure to v1.0.0"
```

### 2. Documentation

Always document the submodule version in your parent project:

```markdown
# In parent project README.md
## Infrastructure Version
Currently using aws-docker-deployment v1.0.0
Last updated: 2024-01-15
```

### 3. CI/CD Considerations

Update your CI/CD pipelines to handle submodules:

```yaml
# GitHub Actions example
- name: Checkout with submodules
  uses: actions/checkout@v3
  with:
    submodules: recursive

# GitLab CI example
variables:
  GIT_SUBMODULE_STRATEGY: recursive

# Jenkins example
checkout scm: [
  $class: 'GitSCM',
  submoduleCfg: [
    $class: 'SubmoduleOption',
    recursiveSubmodules: true
  ]
]
```

### 4. Terraform State Management

When using as a submodule, configure backend in parent project:

```hcl
# parent-project/backend-config.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-west-2"
  }
}
```

## Automation Scripts

### Update Script

The repository includes a convenient update script that can be run from anywhere:

```bash
# From anywhere in your system
./path/to/infra/scripts/update-submodule.sh

# Or if you're in the parent project
./infra/scripts/update-submodule.sh
```

This script:
- Auto-detects the submodule location
- Shows what changes will be pulled
- Asks for confirmation before updating
- Creates detailed commit messages
- Handles detached HEAD states properly

### Check Updates Script (check-infrastructure-updates.sh)

```bash
#!/bin/bash
# Check if infrastructure updates are available

cd infrastructure
git fetch origin

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "Infrastructure is up to date"
else
    echo "Updates available for infrastructure"
    echo "Current: ${LOCAL:0:7}"
    echo "Latest:  ${REMOTE:0:7}"
    echo "Run update script to update"
    
    # Show changelog
    echo -e "\nChanges:"
    git log --oneline HEAD..origin/main
fi
```

## Troubleshooting

### Issue: Detached HEAD in Submodule

```bash
cd infrastructure
git checkout main  # or appropriate branch
git pull origin main
cd ..
git add infrastructure
git commit -m "Fix detached HEAD in infrastructure"
```

### Issue: Submodule Not Initialized

```bash
git submodule init
git submodule update
```

### Issue: Permission Denied

```bash
# Check remote URL
git config --get submodule.infrastructure.url

# Update to use SSH if needed
git config submodule.infrastructure.url git@github.com:dev-ignis/aws-docker-deployment.git
git submodule sync
```

### Issue: Dirty Submodule

```bash
cd infrastructure
git status  # Check what's changed
git stash  # Save changes temporarily
git checkout main
git pull
# Apply changes back if needed
git stash pop
```

## Migration from Direct Clone to Submodule

If you previously cloned this repo directly and want to convert to submodule:

```bash
# 1. Backup your terraform.tfvars and any custom files
cp infrastructure/terraform.tfvars ~/backup-tfvars

# 2. Remove the existing directory
rm -rf infrastructure

# 3. Add as submodule
git submodule add https://github.com/dev-ignis/aws-docker-deployment.git infrastructure

# 4. Restore your configuration
cp ~/backup-tfvars infrastructure/terraform.tfvars

# 5. Commit
git add .
git commit -m "Convert infrastructure to submodule"
```

## Quick Reference for 'infra' Submodule

If your submodule is named `infra` (as shown in your example):

```bash
# Check current status
git submodule status
# Output: 779cee852d01105bedf002ad6b0c312012d3ac88 infra (heads/main-48-g779cee8)

# Update to latest version
cd infra
git fetch origin
git checkout main
git pull origin main
cd ..
git add infra
git commit -m "Update infra to latest"

# Or use the update script
./infra/scripts/update-submodule.sh

# Quick one-liner update
git submodule update --remote --merge infra && git add infra && git commit -m "Update infra"
```

## Summary

Key commands for daily use:

```bash
# Update to latest (specify submodule name)
git submodule update --remote --merge infra

# Check status
git submodule status

# Force sync with parent project
git submodule update --init --recursive --force
```

Remember: Always commit submodule changes in the parent project after updating!