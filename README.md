# Git LaTeX Diff Tool

Compare LaTeX documents between different revisions.

```bash
git gtdiff intro.tex
```

## What it does

`gtdiff` visualizes changes in LaTeX documents by:
- Comparing files between your working copy and any git revision
- Automatically generating and opening PDF with changes highlighted
- Blue underwave for additions, red strikethrough for deletions
- Smart handling of both individual files and complete documents

## Installation

```bash
git clone git@github.com:abeldantas/gtdiff.git
cd gtdiff
./setup.sh
```

## Usage

```bash
# Compare file with HEAD (default, most common)
git gtdiff intro.tex

# Compare with previous commit
git gtdiff intro.tex HEAD~1

# Compare with 3 commits ago
git gtdiff intro.tex HEAD~3

# Compare with another branch
git gtdiff chapter.tex origin/main

# Show modified .tex files
git gtdiff

# Only create diff file, don't open PDF
git gtdiff intro.tex --no-pdf

# Clean up temporary files after
git gtdiff intro.tex --clean
```

## How it works

1. Uses `latexdiff-vc` to generate a visual diff
2. Automatically compiles to PDF and opens it (macOS)
3. For section files, creates a minimal wrapper document
4. Handles main.tex with `--flatten` to include all `\input` files

## Requirements

- `latexdiff` and `latexdiff-vc` (included in most TeX distributions)
- `pdflatex`
- Git repository with LaTeX files

## Manual Setup

If you prefer a custom location:

```bash
git config --global alias.gtdiff '!/path/to/gtdiff/gtdiff.sh'
```

## License

MIT License - see LICENSE file for details.
