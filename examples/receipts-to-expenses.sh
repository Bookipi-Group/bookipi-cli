#!/usr/bin/env bash
# Turn a folder of receipt photos and PDFs into Bookipi expenses.
#
#   ./receipts-to-expenses.sh ~/Receipts          # preview: read every receipt
#   ./receipts-to-expenses.sh ~/Receipts --save   # create the expenses
#
# Each receipt is read by Bookipi's OCR (amount, merchant, date, category).
# With --save, each one becomes an expense with the receipt attached, and the
# file moves to <folder>/saved/ so running it again never saves it twice.
set -euo pipefail

BOOKIPI="${BOOKIPI:-bookipi}"   # or BOOKIPI="node /path/to/bookipi.js"
command -v jq >/dev/null || { echo "This script needs jq." >&2; exit 1; }

folder="${1:?Usage: receipts-to-expenses.sh <folder> [--save]}"
save=0
[ "${2:-}" = "--save" ] && save=1

shopt -s nullglob nocaseglob
receipts=("$folder"/*.{png,jpg,jpeg,pdf,heic,webp})
if [ ${#receipts[@]} -eq 0 ]; then
  echo "No receipts (png, jpg, pdf, heic, webp) in $folder."
  exit 0
fi

[ "$save" -eq 1 ] && mkdir -p "$folder/saved"
saved=0

for file in "${receipts[@]}"; do
  name=$(basename "$file")
  if ! scan=$($BOOKIPI expense scan --file "$file" --json | jq '.scanned'); then
    echo "✗ $name: could not be read" >&2
    continue
  fi

  amount=$(jq -r '.amount // empty' <<<"$scan")
  merchant=$(jq -r '.merchantName // .vendorName // empty' <<<"$scan")
  date=$(jq -r '.purchaseDate // empty' <<<"$scan")
  category=$(jq -r '.categoryName // empty' <<<"$scan")
  number=$(jq -r '.invoiceNumber // empty' <<<"$scan")

  if [ -z "$amount" ]; then
    echo "✗ $name: no amount found — add this one by hand" >&2
    continue
  fi

  echo "• $name: ${merchant:-unknown merchant}, $amount, ${date:-no date}, ${category:-no category}"
  [ "$save" -eq 1 ] || continue

  args=(--file "$file" --amount "$amount")
  [ -n "$merchant" ] && args+=(--merchant "$merchant")
  [ -n "$date" ] && args+=(--date "$date")
  [ -n "$category" ] && args+=(--category "$category")
  [ -n "$number" ] && args+=(--invoice-number "$number")

  if $BOOKIPI expense create "${args[@]}" --json >/dev/null; then
    mv "$file" "$folder/saved/"
    saved=$((saved + 1))
  else
    echo "  ✗ could not save $name" >&2
  fi
done

if [ "$save" -eq 1 ]; then
  echo "Saved $saved expense(s)."
else
  echo
  echo "Preview only. Run again with --save to create these expenses."
fi
