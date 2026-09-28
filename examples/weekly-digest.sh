#!/usr/bin/env bash
# A short business digest in Markdown: invoiced, collected, overdue, who owes
# the most, and deals that went quiet. Prints it, and posts it to Slack when
# SLACK_WEBHOOK_URL is set.
#
#   ./weekly-digest.sh                 # this week
#   ./weekly-digest.sh month           # today | yesterday | week | month
#   SLACK_WEBHOOK_URL=https://hooks.slack.com/... ./weekly-digest.sh
#
# Read-only: it never changes anything in Bookipi.
set -euo pipefail

BOOKIPI="${BOOKIPI:-bookipi}"   # or BOOKIPI="node /path/to/bookipi.js"
command -v jq >/dev/null || { echo "This script needs jq." >&2; exit 1; }

period="${1:-week}"

digest=$($BOOKIPI report digest --period "$period" --json)
currency=$($BOOKIPI company list --json | jq -r '.default.currency // ""')

report=$(jq -r --arg cur "$currency" '
  def group: tostring | split("") | reverse | [_nwise(3) | reverse | join("")] | reverse | join(",");
  def money: (. * 100 | round) as $c
    | "\($cur) \(($c / 100 | floor) | group).\(($c % 100) | tostring | if length == 1 then "0" + . else . end)";
  [
    "*Bookipi digest: \(.period.label)*",
    "",
    "• Invoiced: \(.summary.invoiced | money)",
    "• Collected: \(.summary.collected | money) (\(.summary.collectionRate)% collection rate)",
    "• Unpaid: \(.summary.unpaid.amount | money) across \(.summary.unpaid.count) invoices",
    "• Overdue: \(.summary.overdue.amount | money) across \(.summary.overdue.count) invoices",
    "",
    "*Most overdue*",
    ((.overdueBreakdown.severe90plus + .overdueBreakdown.moderate30to89)
      | sort_by(-.amount) | .[0:5][]
      | "• \(.invoiceNo): \(.customerName), \(.amount | money), \(.daysOverdue) days"),
    "",
    "*Deals gone quiet*",
    (.pipeline.stalled[0:3][]
      | "• \(.name) (\(.stage), \(.daysSinceUpdate) days since update)")
  ] | join("\n")' <<<"$digest")

echo "$report"

if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  jq -n --arg text "$report" '{text: $text}' \
    | curl -fsS -X POST -H 'Content-Type: application/json' -d @- "$SLACK_WEBHOOK_URL" >/dev/null
  echo "(posted to Slack)" >&2
fi
