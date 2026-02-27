#!/bin/bash
# Extract URLs from PDF files and create a mapping

cd "$(dirname "$0")/references" || exit 1

echo "# PDF Source URLs"
echo "# Extracted from PDF content (browser print headers/footers)"
echo "# Generated: $(date)"
echo ""
echo "| PDF File | Source URL |"
echo "|----------|------------|"

for pdf in *.pdf; do
    # Extract first page and look for URLs
    url=$(pdftotext -l 1 "$pdf" - 2>/dev/null | grep -oE "https?://[^ ]+" | head -1)

    if [ -n "$url" ]; then
        # Clean up truncated URLs (ending with ...)
        url_clean=$(echo "$url" | sed 's/\.\.\.$//')
        echo "| $pdf | $url_clean |"
    else
        echo "| $pdf | (No URL found in PDF) |"
    fi
done
