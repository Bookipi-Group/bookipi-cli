#!/usr/bin/env bash
# Chase overdue invoices: preview who would get a reminder, confirm, then send.
#
#   ./chase-overdue.sh                      # 7–90 days overdue, up to 20
#   ./chase-overdue.sh --min-days 30 --limit 5
#   ./chase-overdue.sh --yes                # no prompt (for cron)
#
# Sends exactly the invoices it previewed, one by one, so nothing new can slip
# in between the preview and the send.
set -euo pipefail

BOOKIPI="${BOOKIPI:-bookipi}"   # or BOOKIPI="node /path/to/bookipi.js"
command -v jq >/dev/null || { echo "This script needs jq." >&2; exit 1; }

min_days=7
max_days=90
limit=20
yes=0
while [ $# -gt 0 ]; do
  case "$1" in
    --min-days) min_days="$2"; shift 2 ;;
    --max-days) max_days="$2"; shift 2 ;;
    --limit)    limit="$2"; shift 2 ;;
    --yes)      yes=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# `invoice remind` is a dry run unless --send is passed.
plan=$($BOOKIPI invoice remind --min-days "$min_days" --max-days "$max_days" \
  --limit "$limit" --json)
planned=$(jq '[.plan[] | select(.status == "planned")]' <<<"$plan")
count=$(jq 'length' <<<"$planned")

if [ "$count" -eq 0 ]; then
  echo "Nothing to chase: no invoices ${min_days}–${max_days} days overdue."
  exit 0
fi

currency=$($BOOKIPI company list --json | jq -r '.default.currency // ""')

echo "Reminders to send ($count):"
echo
jq -r --arg cur "$currency" \
  '(["INVOICE", "CUSTOMER", "EMAIL", "AMOUNT DUE", "DAYS LATE"] | @tsv),
   (.[] | [.invoiceNo, .customerName, .customerEmail, "\($cur) \(.amountDue)", .daysOverdue] | @tsv)' \
  <<<"$planned" | column -t -s $'\t'
echo

if [ "$yes" -ne 1 ]; then
  read -r -p "Send these $count reminders? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Nothing sent."; exit 0; }
fi

sent=0
while read -r id; do
  if $BOOKIPI invoice remind --invoice "$id" --send --json >/dev/null; then
    sent=$((sent + 1))
  else
    echo "Failed to remind invoice $id" >&2
  fi
done < <(jq -r '.[].invoiceId' <<<"$planned")

echo "Sent $sent of $count reminders."
