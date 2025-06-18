#!/usr/bin/env bash
# Script to update this repository when used as a git submodule
# Optimized for Ubuntu/Linux environments
# Usage: ./infra/scripts/update-submodule.sh (from parent project root)

set -euo pipefail

# Get the directory where this script is located (scripts folder)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the submodule directory (parent of scripts)
SUBMODULE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
SUBMODULE_NAME=$(basename "$SUBMODULE_DIR")

# Check for required commands
command -v git >/dev/null 2>&1 || { echo "Error: git is not installed. Please install git first: sudo apt update && sudo apt install git" >&2; exit 1; }

# Ensure we're working from the parent directory
echo "🔧 AWS Infrastructure Submodule Updater"
echo "📁 Script location: $SCRIPT_DIR"
echo "📂 Submodule directory: $SUBMODULE_DIR"
echo "🏷️  Submodule name: $SUBMODULE_NAME"

# Check if we're already in the parent directory
if [ -f ".gitmodules" ] && git submodule status 2>/dev/null | grep -q "$SUBMODULE_NAME"; then
    # We're in the parent directory
    PARENT_DIR="$(pwd)"
    echo "✅ Already in parent directory: $PARENT_DIR"
else
    # Navigate to parent directory
    PARENT_DIR="$( cd "$SUBMODULE_DIR/.." && pwd )"
    echo "📁 Changing to parent directory: $PARENT_DIR"
    cd "$PARENT_DIR"
fi

# Verify we're in a git repository with submodules
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    echo "💡 Make sure you're running this from your parent project root"
    exit 1
fi

if [ ! -f ".gitmodules" ]; then
    echo "❌ Error: No .gitmodules file found. This doesn't appear to be a repository with submodules."
    echo "💡 Make sure this repository uses git submodules"
    exit 1
fi

# Verify the submodule exists
if ! git submodule status | grep -q "$SUBMODULE_NAME"; then
    echo "❌ Error: '$SUBMODULE_NAME' is not a git submodule in this repository"
    echo "📋 Available submodules:"
    git submodule status || echo "No submodules found"
    exit 1
fi

echo ""
echo "🔄 Updating submodule: $SUBMODULE_NAME"
echo "📁 Working directory: $(pwd)"
echo "📊 Current status:"
git submodule status | grep "$SUBMODULE_NAME"

# Update the submodule
echo ""
echo "📁 Entering submodule directory: $SUBMODULE_NAME"
cd "$SUBMODULE_NAME"
echo "🌐 Fetching latest changes..."

# Check network connectivity before fetching
if ! git ls-remote origin >/dev/null 2>&1; then
    echo "❌ Error: Cannot connect to remote repository"
    echo "💡 Check your internet connection and git credentials"
    exit 1
fi

git fetch origin

# Get current and latest commits
CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
LATEST_COMMIT=$(git rev-parse origin/main)

if [ "$CURRENT_COMMIT" = "$LATEST_COMMIT" ]; then
    echo "✅ Submodule is already up to date"
    exit 0
fi

echo ""
echo "📊 Current commit: ${CURRENT_COMMIT:0:7}"
echo "🆕 Latest commit:  ${LATEST_COMMIT:0:7}"

# Show summary of changes
echo ""
echo "📋 Changes summary:"
CHANGES=$(git log --oneline "${CURRENT_COMMIT}..${LATEST_COMMIT}" | wc -l)
echo "   📦 $CHANGES new commits"
git log --oneline "${CURRENT_COMMIT}..${LATEST_COMMIT}" | head -5 | sed 's/^/   ├─ /'
if [ "$CHANGES" -gt 5 ]; then
    echo "   └─ ... and $((CHANGES - 5)) more commits"
fi

# Ask for confirmation
echo ""
echo -n "❓ Update to latest version? [y/N]: "
read -r REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Update cancelled"
    exit 0
fi

# Perform update
echo ""
echo "🔄 Performing update..."
if [ "$CURRENT_BRANCH" = "HEAD" ]; then
    # Detached HEAD state
    echo "🔀 Checking out main branch (was in detached HEAD state)"
    git checkout main
fi

echo "⬇️  Pulling latest changes..."
git pull origin main
NEW_COMMIT=$(git rev-parse HEAD)

# Go back to parent project
echo "🔙 Returning to parent directory..."
cd "$PARENT_DIR"

# Stage and commit the change
echo "📝 Staging submodule update..."
git add "$SUBMODULE_NAME"

# Create detailed commit message
COMMIT_MSG="Update $SUBMODULE_NAME to latest version

Updated from ${CURRENT_COMMIT:0:7} to ${NEW_COMMIT:0:7}
$CHANGES commits added

Latest changes:
$(cd "$SUBMODULE_NAME" && git log --oneline "${CURRENT_COMMIT}..${NEW_COMMIT}" | head -5)"

echo "💾 Committing changes..."
git commit -m "$COMMIT_MSG"

echo ""
echo "✅ Submodule updated successfully!"
echo "✅ Changes committed to parent repository"
echo ""
echo "🚀 Next step: git push"
echo "💡 Run: git push origin $(git rev-parse --abbrev-ref HEAD)"