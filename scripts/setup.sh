#!/usr/bin/env bash
# Setup script for Ubuntu users to make scripts executable
# Run this once after cloning/updating the submodule

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🔧 Setting up AWS Infrastructure scripts for Ubuntu..."

# Make scripts executable
chmod +x "$SCRIPT_DIR/update-submodule.sh"
echo "✅ Made update-submodule.sh executable"

# Check if git is installed
if ! command -v git >/dev/null 2>&1; then
    echo "⚠️  Git is not installed. Installing git..."
    sudo apt update && sudo apt install -y git
    echo "✅ Git installed successfully"
else
    echo "✅ Git is already installed"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Usage:"
echo "  ./infra/scripts/update-submodule.sh  # Update submodule to latest"
echo ""
echo "💡 Run this from your parent project root directory"