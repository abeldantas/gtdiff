#!/bin/bash

# setup.sh - Install gtdiff aliases

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GTDIFF_SCRIPT="$SCRIPT_DIR/gtdiff.sh"

echo "Setting up gtdiff (Git laTex DIFF) aliases..."

# Check if script exists
if [ ! -f "$GTDIFF_SCRIPT" ]; then
    echo "Error: gtdiff.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Make script executable
chmod +x "$GTDIFF_SCRIPT"

# Set up git aliases
git config --global alias.gtdiff "!$GTDIFF_SCRIPT"
git config --global alias.gtd "!$GTDIFF_SCRIPT -p"
git config --global alias.gtdr "!$GTDIFF_SCRIPT -r"
git config --global alias.gtdm "!$GTDIFF_SCRIPT -m -p"

echo "✓ Git aliases configured successfully!"
echo ""
echo "You can now use:"
echo "  git gtdiff [options] file.tex    # Full command with options"
echo "  git gtd file.tex                  # Quick PDF diff (most common)"
echo "  git gtdr HEAD~1 -p file.tex       # Compare with specific revision"
echo "  git gtdm                          # Compare entire document"
echo ""
echo "Run 'git gtdiff -h' for help"
