#!/bin/bash

# gtdiff.sh - Git laTex DIFF - Compare LaTeX files between git revisions
# Usage: gtdiff.sh [options] [file.tex]

# Add TeX binaries to PATH if they exist
if [ -d "/usr/local/texlive/2025/bin/universal-darwin" ]; then
    export PATH="/usr/local/texlive/2025/bin/universal-darwin:$PATH"
elif [ -d "/usr/local/texlive/2024/bin/universal-darwin" ]; then
    export PATH="/usr/local/texlive/2024/bin/universal-darwin:$PATH"
elif [ -d "/usr/local/texlive/2023/bin/universal-darwin" ]; then
    export PATH="/usr/local/texlive/2023/bin/universal-darwin:$PATH"
fi

# Default values
REVISION=""
GENERATE_PDF=true
USE_TMP=true
CLEANUP=false
FILE=""

# Handle git alias execution from repo root
if [ -n "$GIT_PREFIX" ]; then
    cd "$GIT_PREFIX"
fi

# Simple usage function
show_usage() {
    echo "Usage: git gtdiff [file.tex] [revision] [options]"
    echo ""
    echo "Examples:"
    echo "  git gtdiff intro.tex              # Compare intro.tex with HEAD and open PDF"
    echo "  git gtdiff intro.tex HEAD~1       # Compare with previous commit" 
    echo "  git gtdiff main.tex               # Compare entire document"
    echo "  git gtdiff                        # Show modified .tex files to choose from"
    echo ""
    echo "Options:"
    echo "  --no-pdf    Don't generate PDF, only create diff file"
    echo "  --no-tmp    Generate files in current directory (not in tmp)"
    echo "  --clean     Clean up temporary files after"
    echo "  --help      Show this help message"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            ;;
        --no-pdf)
            GENERATE_PDF=false
            shift
            ;;
        --no-tmp)
            USE_TMP=false
            shift
            ;;
        --clean)
            CLEANUP=true
            shift
            ;;
        *)
            if [ -z "$FILE" ] && [[ "$1" == *.tex ]] && [ -f "$1" ]; then
                FILE="$1"
            elif [ -z "$FILE" ] && [ -f "$1.tex" ]; then
                FILE="$1.tex"
            elif [ -z "$FILE" ] && [ -f "$1" ]; then
                FILE="$1"
            elif [ -n "$FILE" ] && [ -z "$REVISION" ]; then
                REVISION="$1"
            else
                echo "Unknown argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Set default revision if not specified
if [ -z "$REVISION" ]; then
    REVISION="HEAD"
fi

# If no file specified, show list of modified tex files
if [ -z "$FILE" ]; then
    echo "Modified LaTeX files:"
    git diff --name-only HEAD | grep "\.tex$" || echo "No modified .tex files found"
    echo ""
    echo "Usage: git gtdiff [file.tex] [revision]"
    exit 0
fi

# Get absolute path of the file
FILE_ABS=$(realpath "$FILE" 2>/dev/null || python3 -c "import os,sys; print(os.path.abspath(sys.argv[1]))" "$FILE")

# Check if file exists
if [ ! -f "$FILE_ABS" ]; then
    echo "Error: File '$FILE' not found"
    exit 1
fi

# Get git root directory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Get relative path from git root
FILE_RELATIVE=$(realpath --relative-to="$GIT_ROOT" "$FILE_ABS" 2>/dev/null || python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$FILE_ABS" "$GIT_ROOT")

# Get the directory of the file
FILEDIR=$(dirname "$FILE")
BASENAME=$(basename "$FILE" .tex)

# Create output directory
if [ "$USE_TMP" = true ]; then
    TMPDIR=".gtdiff-tmp"
    mkdir -p "$TMPDIR"
    OUTPUT_DIR="$(pwd)/$TMPDIR"
else
    OUTPUT_DIR="$FILEDIR"
fi

echo "Generating LaTeX diff for $FILE comparing with $REVISION..."

# Change to git root for git operations
cd "$GIT_ROOT"

# Create temporary file for old version
OLD_TMP="${OUTPUT_DIR}/${BASENAME}-old-${REVISION//\//-}.tex"

# Extract old version using git
git show "${REVISION}:${FILE_RELATIVE}" > "$OLD_TMP" || {
    echo "Error: Failed to extract old version from git"
    exit 1
}

# Run latexdiff directly
if [ "$(basename "$FILE")" = "main.tex" ]; then
    # For main.tex, we might need special handling
    latexdiff --flatten "$OLD_TMP" "$FILE_ABS" > "${OUTPUT_DIR}/${BASENAME}-diff${REVISION//\//-}.tex" || {
        echo "Error: Failed to create diff"
        rm -f "$OLD_TMP"
        exit 1
    }
else
    latexdiff "$OLD_TMP" "$FILE_ABS" > "${OUTPUT_DIR}/${BASENAME}-diff${REVISION//\//-}.tex" || {
        echo "Error: Failed to create diff"
        rm -f "$OLD_TMP"
        exit 1
    }
fi

# Clean up old tmp file
rm -f "$OLD_TMP"

# Update the diff file path
DIFFFILE="${OUTPUT_DIR}/${BASENAME}-diff${REVISION//\//-}.tex"

echo "Created diff file: $DIFFFILE"

# Generate PDF if requested
if [ "$GENERATE_PDF" = true ]; then
    echo "Generating PDF..."
    
    PDFFILE="${OUTPUT_DIR}/${BASENAME}-diff${REVISION//\//-}.pdf"
    
    # Create wrapper for non-main files
    if [ "$(basename "$FILE")" != "main.tex" ]; then
        WRAPPER="${OUTPUT_DIR}/${BASENAME}-wrapper.tex"
        cat > "$WRAPPER" << 'EOF'
\documentclass[11pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage{soul}
\usepackage{color}
\usepackage{ulem}
\normalem

\providecommand{\DIFadd}[1]{{\protect\color{blue}\uwave{#1}}}
\providecommand{\DIFdel}[1]{{\protect\color{red}\sout{#1}}}
\providecommand{\DIFaddbegin}{}
\providecommand{\DIFaddend}{}
\providecommand{\DIFdelbegin}{}
\providecommand{\DIFdelend}{}
\providecommand{\DIFmodbegin}{}
\providecommand{\DIFmodend}{}

\begin{document}
\input{BASENAME-diffREVISION}
\end{document}
EOF
        # Replace placeholders - sanitize revision for filename
        REVISION_SAFE="${REVISION//\//-}"
        sed -i '' "s/BASENAME/${BASENAME}/g" "$WRAPPER"
        sed -i '' "s/REVISION/${REVISION_SAFE}/g" "$WRAPPER"
        
        # Compile in output directory
        (cd "$OUTPUT_DIR" && pdflatex -interaction=nonstopmode "$(basename "$WRAPPER")" > /dev/null 2>&1)
        
        # Check for output
        if [ -f "${OUTPUT_DIR}/${BASENAME}-wrapper.pdf" ]; then
            mv "${OUTPUT_DIR}/${BASENAME}-wrapper.pdf" "$PDFFILE"
            rm -f "$WRAPPER" "${OUTPUT_DIR}/${BASENAME}-wrapper.aux" "${OUTPUT_DIR}/${BASENAME}-wrapper.log"
        fi
    else
        # Compile main.tex directly
        (cd "$OUTPUT_DIR" && pdflatex -interaction=nonstopmode "$(basename "$DIFFFILE")" > /dev/null 2>&1 && pdflatex -interaction=nonstopmode "$(basename "$DIFFFILE")" > /dev/null 2>&1)
    fi
    
    if [ -f "$PDFFILE" ]; then
        echo "Generated PDF: $PDFFILE"
        if command -v open &> /dev/null; then
            open "$PDFFILE"
        fi
    else
        echo "Warning: PDF generation failed. Try compiling manually."
    fi
fi

# Cleanup
if [ "$CLEANUP" = true ]; then
    echo "Cleaning up..."
    if [ "$USE_TMP" = true ]; then
        rm -rf "$OUTPUT_DIR"
    else
        REVISION_SAFE="${REVISION//\//-}"
        rm -f "${OUTPUT_DIR}/${BASENAME}-diff${REVISION_SAFE}".{aux,log,out}
    fi
elif [ "$USE_TMP" = true ]; then
    echo ""
    echo "Files generated in: $OUTPUT_DIR"
    echo "To clean up: rm -rf $OUTPUT_DIR"
fi

echo "Done!"
