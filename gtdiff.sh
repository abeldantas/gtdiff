#!/bin/bash

# gtdiff.sh - Git laTex DIFF - Compare LaTeX files between git revisions
# Usage: gtdiff.sh [options] [file.tex]

# Default values
REVISION="HEAD"
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

# If no file specified, show list of modified tex files
if [ -z "$FILE" ]; then
    echo "Modified LaTeX files:"
    git diff --name-only HEAD | grep "\.tex$" || echo "No modified .tex files found"
    echo ""
    echo "Usage: git gtdiff [file.tex] [revision]"
    exit 0
fi

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found"
    exit 1
fi

# Get the directory of the file
FILEDIR=$(dirname "$FILE")
BASENAME=$(basename "$FILE" .tex)

# Create output directory
if [ "$USE_TMP" = true ]; then
    TMPDIR=".gtdiff-tmp"
    mkdir -p "$TMPDIR"
    OUTPUT_DIR="$TMPDIR"
else
    OUTPUT_DIR="$FILEDIR"
fi

echo "Generating LaTeX diff for $FILE comparing with $REVISION..."

# Save current directory
ORIG_DIR=$(pwd)

# Change to file directory for latexdiff-vc
cd "$FILEDIR"

# Run latexdiff-vc
if [ "$(basename "$FILE")" = "main.tex" ]; then
    latexdiff-vc --git -r "$REVISION" "$(basename "$FILE")" --flatten 2>/dev/null || {
        echo "Error: Failed to create diff"
        cd "$ORIG_DIR"
        exit 1
    }
else
    latexdiff-vc --git -r "$REVISION" "$(basename "$FILE")" 2>/dev/null || {
        echo "Error: Failed to create diff"  
        cd "$ORIG_DIR"
        exit 1
    }
fi

# Go back to original directory
cd "$ORIG_DIR"

# Move generated files to output directory
GENERATED_DIFF="${FILEDIR}/${BASENAME}-diff${REVISION}.tex"
DIFFFILE="${OUTPUT_DIR}/${BASENAME}-diff${REVISION}.tex"

if [ -f "$GENERATED_DIFF" ]; then
    if [ "$USE_TMP" = true ]; then
        mv "$GENERATED_DIFF" "$DIFFFILE"
        # Also move oldtmp files
        mv "${FILEDIR}/${BASENAME}-oldtmp-"*.tex "$OUTPUT_DIR/" 2>/dev/null || true
    else
        DIFFFILE="$GENERATED_DIFF"
    fi
else
    echo "Error: Diff file was not created"
    exit 1
fi

echo "Created diff file: $DIFFFILE"

# Generate PDF if requested
if [ "$GENERATE_PDF" = true ]; then
    echo "Generating PDF..."
    
    PDFFILE="${OUTPUT_DIR}/${BASENAME}-diff${REVISION}.pdf"
    
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
        # Replace placeholders
        sed -i '' "s/BASENAME/${BASENAME}/g" "$WRAPPER"
        sed -i '' "s/REVISION/${REVISION}/g" "$WRAPPER"
        
        # Compile in output directory
        cd "$OUTPUT_DIR"
        pdflatex -interaction=nonstopmode "$(basename "$WRAPPER")" > /dev/null 2>&1
        cd "$ORIG_DIR"
        
        # Check for output
        if [ -f "${OUTPUT_DIR}/${BASENAME}-wrapper.pdf" ]; then
            mv "${OUTPUT_DIR}/${BASENAME}-wrapper.pdf" "$PDFFILE"
            rm -f "$WRAPPER" "${OUTPUT_DIR}/${BASENAME}-wrapper.aux" "${OUTPUT_DIR}/${BASENAME}-wrapper.log"
        fi
    else
        # Compile main.tex directly
        cd "$OUTPUT_DIR"
        pdflatex -interaction=nonstopmode "$(basename "$DIFFFILE")" > /dev/null 2>&1
        pdflatex -interaction=nonstopmode "$(basename "$DIFFFILE")" > /dev/null 2>&1
        cd "$ORIG_DIR"
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
        rm -f "${OUTPUT_DIR}/${BASENAME}-diff${REVISION}".{aux,log,out}
        rm -f "${OUTPUT_DIR}/${BASENAME}-oldtmp-"*.tex
    fi
elif [ "$USE_TMP" = true ]; then
    echo ""
    echo "Files generated in: $OUTPUT_DIR"
    echo "To clean up: rm -rf $OUTPUT_DIR"
fi

echo "Done!"
