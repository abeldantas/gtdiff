#!/bin/bash

# setup.sh - Install gtdiff alias

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GTDIFF_SCRIPT="$SCRIPT_DIR/gtdiff.sh"

echo "Setting up gtdiff (Git laTex DIFF)..."

# Check if script exists
if [ ! -f "$GTDIFF_SCRIPT" ]; then
    echo "Error: gtdiff.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Make script executable
chmod +x "$GTDIFF_SCRIPT"

# Remove old aliases if they exist
git config --global --unset alias.gtd 2>/dev/null
git config --global --unset alias.gtdr 2>/dev/null
git config --global --unset alias.gtdm 2>/dev/null
git config --global --unset alias.texdiff 2>/dev/null
git config --global --unset alias.texdiff-pdf 2>/dev/null
git config --global --unset alias.texdiff-rev 2>/dev/null
git config --global --unset alias.texdiff-main 2>/dev/null

# Set up single git alias
git config --global alias.gtdiff "!$GTDIFF_SCRIPT"

echo "✓ Git alias configured successfully!"
echo ""
echo "Usage:"
echo "  git gtdiff file.tex              # Compare with HEAD and open PDF"
echo "  git gtdiff file.tex HEAD~1       # Compare with previous commit"
echo "  git gtdiff file.tex --no-pdf     # Only create diff file"
echo "  git gtdiff                       # Show modified files"
echo ""
echo "Run 'git gtdiff --help' for more information"
