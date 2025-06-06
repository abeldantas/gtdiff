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
GENERATE_PDF=false
USE_MAIN=false
CLEANUP=false
FILE=""

# Handle git alias execution from repo root
if [ -n "$GIT_PREFIX" ]; then
    cd "$GIT_PREFIX"
fi

# Parse command line options
while getopts "r:pmch" opt; do
    case $opt in
        r)
            REVISION="$OPTARG"
            ;;
        p)
            GENERATE_PDF=true
            ;;
        m)
            USE_MAIN=true
            ;;
        c)
            CLEANUP=true
            ;;
        h)
            echo "Usage: $0 [options] [file.tex]"
            echo ""
            echo "Options:"
            echo "  -r REV    Compare with revision REV (default: HEAD)"
            echo "  -p        Generate PDF output"
            echo "  -m        Use main.tex with --flatten (for comparing entire document)"
            echo "  -c        Clean up temporary files after"
            echo "  -h        Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 -p section.tex                  # Compare section.tex with HEAD and generate PDF"
            echo "  $0 -r HEAD~1 -p section.tex        # Compare with previous commit"
            echo "  $0 -m -p                           # Compare entire document via main.tex"
            echo "  $0 -p -c section.tex               # Compare and clean up after"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Shift to get the filename argument
shift $((OPTIND-1))

# Determine which file to use
if [ "$USE_MAIN" = true ]; then
    FILE="main.tex"
else
    FILE="${1:-main.tex}"
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
if [ "$USE_MAIN" = true ]; then
    # For main document, use --flatten to include all \input files
    latexdiff-vc --git -r "$REVISION" "$FILE" --flatten
else
    # For individual files
    latexdiff-vc --git -r "$REVISION" "$FILE"
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
    if [ "$FILE" != "main.tex" ] && [ "$USE_MAIN" = false ]; then
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
        # Replace DIFFFILE with actual filename
        sed -i '' "s/DIFFFILE/$DIFFFILE/" "$WRAPPER"
        
        # Compile the wrapper
        pdflatex -interaction=nonstopmode "$WRAPPER" > /dev/null 2>&1
        
        # Rename output
        mv "${BASENAME}-wrapper.pdf" "$PDFFILE"
        
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
    fi
fi

# Clean up if requested
if [ "$CLEANUP" = true ]; then
    echo "Cleaning up temporary files..."
    rm -f "$DIFFFILE" "${BASENAME}-diff${REVISION}.aux" "${BASENAME}-diff${REVISION}.log" "${BASENAME}-diff${REVISION}.out"
    rm -f "${BASENAME}-oldtmp-"*.tex
fi

echo "Done!"
