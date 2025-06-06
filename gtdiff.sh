#!/bin/bash

# gtdiff.sh - Git laTex DIFF - Compare LaTeX files between git revisions
# Usage: gtdiff.sh [options] [file.tex]
#
# Options:
#   -r REV    Compare with revision REV (default: HEAD)
#   -p        Generate PDF output
#   -m        Use main.tex with --flatten (for comparing entire document)
#   -c        Clean up temporary files after
#   -h        Show this help message

# Default values
REVISION="HEAD"
GENERATE_PDF=true  # Default to generating PDF
NO_PDF=false
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
    echo "  --clean     Clean up temporary files after"
    echo "  --help      Show this help message"
    exit 0
}

# Parse arguments more intuitively
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            ;;
        --no-pdf)
            NO_PDF=true
            GENERATE_PDF=false
            shift
            ;;
        --clean)
            CLEANUP=true
            shift
            ;;
        *.tex)
            FILE="$1"
            shift
            ;;
        HEAD*|@*|main|master|origin/*|[0-9a-f]*)
            # This looks like a revision
            REVISION="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            ;;
    esac
done

# If no file specified, show modified files and help
if [ -z "$FILE" ]; then
    echo "Modified LaTeX files:"
    git status --porcelain | grep '\.tex$' | grep -v diff | awk '{print "  " $2}' | sed "s|^  $GIT_PREFIX||"
    echo ""
    echo "Usage: git gtdiff [file.tex] [revision]"
    echo "Example: git gtdiff intro.tex"
    exit 1
fi

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Extract base filename without extension
BASENAME=$(basename "$FILE" .tex)
DIFFFILE="${BASENAME}-diff${REVISION}.tex"
PDFFILE="${BASENAME}-diff${REVISION}.pdf"

echo "Generating LaTeX diff for $FILE comparing with $REVISION..."

# Run latexdiff-vc
if [ "$FILE" = "main.tex" ]; then
    # For main document, use --flatten to include all \input files
    latexdiff-vc --git -r "$REVISION" "$FILE" --flatten 2>/dev/null || {
        echo "Error: Failed to create diff for main.tex"
        echo "This might happen if main.tex hasn't been modified."
        echo "Try specifying a specific section file instead."
        exit 1
    }
else
    # For individual files
    latexdiff-vc --git -r "$REVISION" "$FILE" 2>/dev/null || {
        echo "Error: Failed to create diff"
        exit 1
    }
fi

# Check if diff file was created
if [ ! -f "$DIFFFILE" ]; then
    echo "Error: Failed to create diff file"
    exit 1
fi

echo "Created diff file: $DIFFFILE"

# Generate PDF if requested
if [ "$GENERATE_PDF" = true ]; then
    echo "Generating PDF..."
    
    # If it's not main.tex, we need to create a wrapper document
    if [ "$FILE" != "main.tex" ]; then
        # Create a minimal wrapper document
        WRAPPER="${BASENAME}-wrapper.tex"
        cat > "$WRAPPER" << 'EOF'
\documentclass[11pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage{soul}
\usepackage{color}
\usepackage{ulem}
\normalem

% latexdiff preamble
\providecommand{\DIFadd}[1]{{\protect\color{blue}\uwave{#1}}}
\providecommand{\DIFdel}[1]{{\protect\color{red}\sout{#1}}}
\providecommand{\DIFaddbegin}{}
\providecommand{\DIFaddend}{}
\providecommand{\DIFdelbegin}{}
\providecommand{\DIFdelend}{}
\providecommand{\DIFmodbegin}{}
\providecommand{\DIFmodend}{}

\begin{document}
\input{DIFFFILE}
\end{document}
EOF
        # Replace DIFFFILE with actual filename (without .tex extension)
        sed -i '' "s/DIFFFILE/${BASENAME}-diff${REVISION}/" "$WRAPPER"
        
        # Compile the wrapper
        pdflatex -interaction=nonstopmode "$WRAPPER" > /dev/null 2>&1
        
        # Rename output
        if [ -f "${BASENAME}-wrapper.pdf" ]; then
            mv "${BASENAME}-wrapper.pdf" "$PDFFILE"
        fi
        
        # Clean up wrapper files
        rm -f "$WRAPPER" "${BASENAME}-wrapper.aux" "${BASENAME}-wrapper.log"
    else
        # For main.tex, compile directly
        pdflatex -interaction=nonstopmode "$DIFFFILE" > /dev/null 2>&1
        # Run twice for references
        pdflatex -interaction=nonstopmode "$DIFFFILE" > /dev/null 2>&1
    fi
    
    if [ -f "$PDFFILE" ]; then
        echo "Generated PDF: $PDFFILE"
        # Open PDF on macOS
        if command -v open &> /dev/null; then
            open "$PDFFILE"
        fi
    else
        echo "Warning: PDF generation failed"
        echo "The diff file '$DIFFFILE' was created successfully."
        echo "You may need to compile it manually or check for LaTeX errors."
    fi
fi

# Clean up if requested
if [ "$CLEANUP" = true ]; then
    echo "Cleaning up temporary files..."
    rm -f "$DIFFFILE" "${BASENAME}-diff${REVISION}.aux" "${BASENAME}-diff${REVISION}.log" "${BASENAME}-diff${REVISION}.out"
    rm -f "${BASENAME}-oldtmp-"*.tex
fi

echo "Done!"
