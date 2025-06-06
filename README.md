# gtdiff

Git laTex DIFF - A fast git integration tool for comparing LaTeX documents between different revisions using `latexdiff`.

## What it does

`gtdiff` allows you to quickly visualize changes in LaTeX documents by:
- Comparing files between your working copy and any git revision
- Generating PDF outputs with visual diff highlighting (additions in blue, deletions in red)
- Handling both individual section files and complete documents
- Creating proper wrapper documents for section files that need context

## Installation

### Prerequisites
- `latexdiff` and `latexdiff-vc` installed (usually comes with TeX distributions)
- `pdflatex` for PDF generation
- Git repository containing LaTeX files

### Quick Setup

```bash
git clone git@github.com:abeldantas/gtdiff.git
cd gtdiff
./setup.sh
```

### Manual Setup

If you prefer to set up manually or use a custom location:

```bash
# Basic gtdiff command with all options
git config --global alias.gtdiff '!/path/to/gtdiff/gtdiff.sh'

# Quick PDF generation (most common use case)
git config --global alias.gtd '!/path/to/gtdiff/gtdiff.sh -p'

# Compare with specific revision
git config --global alias.gtdr '!/path/to/gtdiff/gtdiff.sh -r'

# Compare entire document via main.tex
git config --global alias.gtdm '!/path/to/gtdiff/gtdiff.sh -m -p'
```

## Usage

### Quick Commands

```bash
# Compare a file with HEAD and view PDF (most common)
git gtd chapter1.tex

# Compare with previous commit
git gtdr HEAD~1 -p chapter1.tex

# Compare entire document
git gtdm
```

### All Commands

| Alias | Description | Example |
|-------|-------------|---------|
| `git gtdiff` | Base command with all options | `git gtdiff -r HEAD~2 -p -c file.tex` |
| `git gtd` | Quick PDF diff | `git gtd intro.tex` |
| `git gtdr` | Compare with revision | `git gtdr HEAD~1 -p chapter.tex` |
| `git gtdm` | Diff entire document | `git gtdm` |

### Command Options

```bash
git gtdiff [options] [file.tex]

Options:
  -r REV    Compare with revision REV (default: HEAD)
  -p        Generate PDF output
  -m        Use main.tex with --flatten (for comparing entire document)
  -c        Clean up temporary files after
  -h        Show this help message
```

### Examples

```bash
# Quick diff with PDF
git gtd section.tex

# Compare with 3 commits ago
git gtdr HEAD~3 -p chapter.tex

# Compare with a branch
git gtdr origin/main -p file.tex

# Compare entire document
git gtdm

# Clean up after
git gtdiff -p -c section.tex

# See what changed since yesterday
git gtdr "@{yesterday}" -p main.tex
```

## How It Works

1. Uses `latexdiff-vc` with git support to generate a diff file
2. For individual section files, creates a minimal LaTeX wrapper with proper preamble
3. Compiles the diff to PDF using `pdflatex`
4. On macOS, automatically opens the generated PDF
5. Optionally cleans up temporary files

## Output

- **Additions** are highlighted in blue with underwave
- **Deletions** are highlighted in red with strikethrough
- Generated files follow the pattern: `filename-diffREVISION.pdf`

## License

MIT License - feel free to use and modify as needed.
