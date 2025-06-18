#!/bin/bash
# Script to update this repository when used as a git submodule
# Can be called from anywhere: ./path/to/infra/update-submodule.sh

set -e

# Get the directory where this script is located (scripts folder)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the submodule directory (parent of scripts)
SUBMODULE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
SUBMODULE_NAME=$(basename "$SUBMODULE_DIR")

# Get parent directory (where the parent git repo is)
PARENT_DIR="$( cd "$SUBMODULE_DIR/.." && pwd )"

# Change to parent directory
cd "$PARENT_DIR"

# Verify we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Verify the submodule exists
if ! git submodule status | grep -q "$SUBMODULE_NAME"; then
    echo "Error: '$SUBMODULE_NAME' is not a git submodule"
    exit 1
fi

echo "Updating submodule: $SUBMODULE_NAME"
echo "Current status:"
git submodule status | grep "$SUBMODULE_NAME"

# Update the submodule
cd "$SUBMODULE_NAME"
echo -e "\nFetching latest changes..."
git fetch origin

# Get current and latest commits
CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
LATEST_COMMIT=$(git rev-parse origin/main)

if [ "$CURRENT_COMMIT" = "$LATEST_COMMIT" ]; then
    echo "✓ Submodule is already up to date"
    exit 0
fi

echo -e "\nCurrent commit: ${CURRENT_COMMIT:0:7}"
echo "Latest commit:  ${LATEST_COMMIT:0:7}"

# Show summary of changes
echo -e "\nChanges summary:"
CHANGES=$(git log --oneline "${CURRENT_COMMIT}..${LATEST_COMMIT}" | wc -l)
echo "- $CHANGES new commits"
git log --oneline "${CURRENT_COMMIT}..${LATEST_COMMIT}" | head -5
if [ "$CHANGES" -gt 5 ]; then
    echo "... and $((CHANGES - 5)) more"
fi

# Ask for confirmation
echo
read -p "Update to latest version? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled"
    exit 0
fi

# Perform update
if [ "$CURRENT_BRANCH" = "HEAD" ]; then
    # Detached HEAD state
    git checkout main
fi
git pull origin main
NEW_COMMIT=$(git rev-parse HEAD)

# Go back to parent project
cd ..

# Stage and commit the change
git add "$SUBMODULE_NAME"

# Create detailed commit message
COMMIT_MSG="Update $SUBMODULE_NAME to latest version

Updated from ${CURRENT_COMMIT:0:7} to ${NEW_COMMIT:0:7}
$CHANGES commits added

Latest changes:
$(cd "$SUBMODULE_NAME" && git log --oneline "${CURRENT_COMMIT}..${NEW_COMMIT}" | head -5)"

git commit -m "$COMMIT_MSG"

echo -e "\n✓ Submodule updated successfully"
echo "✓ Changes committed to parent repository"
echo -e "\nTo push changes: git push"