# Report & Analytics Commands

## Summary

```bash
# Revenue summary — invoiced and paid in the period, a breakdown, and what is owed today
bookipi report summary
bookipi report summary --start 2026-01-01 --end 2026-03-31
bookipi report summary --start 2026-07-01 --end 2026-09-30 --cycle quarter   # "last quarter"
bookipi report summary --cycle year                                          # week | month | quarter | year
```

How to read it, and what to say to the user:
- **Invoiced** is invoices *sent* and *dated* in the period, by the date on the invoice. Drafts never sent are not invoiced: they show on their own line ("Unsent drafts"), and in the digest as "Drafts". Mention them separately, never add them in. The same goes for top customers and items, and for every collection rate and revenue share in `report insights`, `report suggest` and the dashboard. **Paid** is payments *received* in the period, by payment date — so it can include payments on older invoices.
- **Currencies.** Every figure is in the company's currency. Invoices in another currency can't be converted (Bookipi stores no exchange rate), so they're left out and listed per currency ("In USD: …"). Relay them as their own line; never add them to the totals.
- **Unpaid / Overdue** are *as of today*, across every invoice, by balance. They are not for the period, and they match `report digest`, `report insights`, `report suggest` and the dashboard. A draft the customer was never sent is in neither: nothing is owed on it yet.

## Top Customers

```bash
bookipi report customers
bookipi report customers --start 2026-01-01 --end 2026-03-31 --limit 20
bookipi report customers --page 2
```

## Top Items

```bash
bookipi report items
bookipi report items --start 2026-01-01 --end 2026-03-31 --limit 20
bookipi report items --page 2
```

## Largest Invoices

Single invoices ranked by total, highest first. Sent invoices only, by the date on the invoice, in the company's currency.

```bash
bookipi report invoices
bookipi report invoices --start 2026-01-01 --end 2026-03-31 --limit 5
bookipi report invoices --page 2
bookipi report invoices --type estimate      # or credit-note, delivery-note, purchase-order
bookipi report invoices --smallest           # lowest total first
bookipi report invoices --min 1000 --max 5000
bookipi report invoices --item "hosting"     # only invoices with a line naming that item
```

## Who Owes You

What is owed right now, as of today (not for a period): invoices the customer was sent that still have a balance.

```bash
bookipi report owed                          # customers ranked by what they owe
bookipi report owed --by invoice             # unpaid invoices, soonest due first
bookipi report owed --by invoice --due-from 2026-12-01 --due-to 2026-12-07
```

## Payments Received

Payments across every customer, newest first, with the split by payment method. By the day the payment was recorded.

```bash
bookipi report payments
bookipi report payments --start 2026-11-01 --end 2026-11-30
bookipi report payments --method card
```

## Largest Proposals

Proposals ranked by value, highest first. Proposals the customer was sent only (no drafts), by the day they were created. Value is the service lines added up, before tax, discount and shipping.

```bash
bookipi report proposals
bookipi report proposals --start 2026-01-01 --end 2026-03-31 --limit 5
```

## Visual Dashboard

Generates an interactive HTML dashboard with charts, filters, and tabs (Overview, Customers, Items).

```bash
bookipi report dashboard                        # generates bookipi-report.html, opens in browser
bookipi report dashboard --start 2026-01-01     # custom date range
bookipi report dashboard -o my-report.html      # custom output path
bookipi report dashboard --no-open              # don't auto-open browser
```

The dashboard includes interactive date filters (This month, Last month, 3m, 6m, 12m, quarters, financial year, custom range) that work client-side — all data is fetched once and filtered instantly in the browser.

### Also offer the full Reports page in the web app

The dashboard/insights/digest above render **locally**. Some users would rather
see the full, always-current **Reports** section in the Bookipi web app. So
after you show a report, **offer a one-click link to open it there**:

```bash
bookipi report open        # prints an authenticated 🔗 link to <web>/reports
```

Surface that `🔗` link as an **inline clickable link on its own line at the
end of the message** — never reference-style, some clients render those as
dead text (see SKILL.md § User-Facing Presentation Rules) — e.g. *"Want the
full interactive version?"* closing with `[Open Reports in Bookipi](<url>)`.
The link signs the user in automatically (short-lived). Offer it as a light,
optional add-on — don't replace the local render with it unless the user asks.

## AI-Powered Insights

Analyzes your data and surfaces patterns you didn't think to ask about — across revenue, cash, customers, items, and expenses: revenue trends + **run-rate forecast** ("on track to finish the month at ~$X"), **QoQ/YoY growth**, collection rates, a **revenue-leakage roll-up + "chase today" list**, customer concentration + **at-risk-by-cadence** ("hasn't ordered in 67 days, usually every 28"), **cross-sell pairs** ("buyers of X also buy Y"), item sales/decline, overdue risk, seasonal patterns, and **expense trend + recurring-subscription detection**.

```bash
bookipi report insights                          # last 12 months (default)
bookipi report insights --start 2025-06-01       # custom start
bookipi report insights --json                   # structured JSON output
```

Insights are sorted by severity: critical (red), warning (yellow), info, positive (green), and grouped by category (Revenue, Forecast, Growth, Cash, Customers, Items, Expenses, Patterns, Risk). Example output includes things like:
- "On track to finish June around $42,000 — about +12% vs May" [INFO] (Forecast)
- "Q1 2026 revenue up 50.0% vs Q4 2025" [GOOD] (Growth)
- "$14,500 in revenue is sitting uncollected" + "Chase 3 invoices first today" [WARNING] (Cash)
- "Acme may be slipping away — no order in 67 days, usually every 28" [WARNING] (Customers)
- "Customers who buy logo design usually buy web design" [INFO] (Items)
- "Recurring: Figma ~$15/mo — cancel it if it's no longer used" [INFO] (Expenses)
- "Top 3 customers generate 93% of revenue" [WARNING]

## Business Digest

A concise "what happened" briefing — invoiced vs collected, overdue breakdown by severity, top customers, recent payments, and a pipeline-at-a-glance section (active deal value, stage breakdown, deals closed this period, deals stalling in proposal/contract stage). Proposals and contracts are surfaced via their parent deals to keep the digest short.

```bash
bookipi report digest                            # the last 7 days (default, --period week)
bookipi report digest --period last-week         # the 7 days before that
bookipi report digest --period today             # today only
bookipi report digest --period yesterday         # yesterday
bookipi report digest --period month             # month-to-date
bookipi report digest --period last-month        # the previous calendar month
bookipi report digest --start 2026-03-01 --end 2026-03-31  # custom range
bookipi report digest --json                     # structured JSON
```

**Two kinds of figure — keep them apart when you relay it.** *Invoiced*, *Collected*, top customers and recent payments are **for the period**. *Unpaid* and *Overdue* are **as of today**: everything still owed, whenever it was invoiced, by balance (what is left to pay), never-sent drafts left out. Never present unpaid or overdue as "this week's".

The digest is designed for both human presentation and scheduled automation (see Monday morning digest schedule).

## Smart Suggestions

Analyzes your account and recommends the most impactful actions right now — prioritized by urgency and potential recovery.

```bash
bookipi report suggest                           # top 5 recommendations (default)
bookipi report suggest --limit 3                 # fewer suggestions
bookipi report suggest --json                    # structured JSON
```

Use this when the user seems unsure what to do, says "what now?", or for the initial health check in open-ended sessions. The output includes `userPrompt` fields — plain-language phrases you can use to present suggestions naturally.

## Defaults & Notes

- All report commands default to the **last 12 months** if `--start`/`--end` are not specified
- Summary defaults to `--cycle month`
- Reports require a default company (stored in `~/.bookipi/credentials.json` after login)
- The API has a **24-month maximum** date range

## How to Handle Common Report Requests

### "Show me my revenue" / "How much did I invoice?" / "What are my numbers?"

Use `report summary` for an overview with monthly breakdown. Add `--start` and `--end` for a specific period. Use `--cycle quarter` or `--cycle year` for a coarser breakdown (`week` for a finer one).

### "Who are my top customers?" / "Who owes me the most?"

Use `report customers` to see customers ranked by revenue.

### "What is my biggest invoice?" / "My largest sale" / "Top 5 invoices this year"

Use `report invoices`: one command. Never page `invoice list` to compare totals; it cannot sort by amount. It covers the last 12 months unless you pass `--start`: for "ever" or an older period, pass an early `--start`, and tell the user which period the answer covers. Invoices in another currency are listed as "Not included"; mention them. For the biggest estimate or other document, add `--type`. For the biggest proposal, use `report proposals`, which has the same 12-month default.

### "Which invoices include X?" / "Who bought X?" / "My smallest invoice" / "Invoices over 5,000"

Use `report invoices` with `--item`, `--smallest`, `--min` or `--max`. One command; never page `invoice list` with line items to look for them.

### "Who owes me the most?" / "What is due next week?" / "What fell due last month?"

Use `report owed` (ranked by customer), or `report owed --by invoice` with `--due-from` / `--due-to` for a due-date window. `invoice list` has no due-date filter.

### "Which invoices were paid by card?" / "How much came in as cash?" / "What was I paid last week?"

Use `report payments`, with `--method` for one method. For one customer's payment history, use `customer payments`.

### "What is my most expensive item?" / "Which items have no price?"

Use `item list --sort price-high` (or `price-low`, which puts items with no price first) and read the first rows. Other orders: `name`, `newest`, `oldest`.

### "What items sell the most?" / "Top products by revenue"

Use `report items` to see items/products ranked by revenue.

### "Give me the big picture" / "What should I focus on?"

Use `report insights` — it surfaces the most important patterns automatically. Follow up with `report digest` for a structured summary.

### CEO "ask your analyst" questions → `report insights`

`report insights` now answers most owner/CEO questions directly. **Run `bookipi report insights --json`, find the matching insight, and read it out — don't hand-compute from raw invoices.** Routing:

| The user asks… | Insight category to surface |
|---|---|
| "Will I finish the month strong?" | **Forecast** (run-rate) |
| "Why is revenue down this month?" | **Revenue** (driver attribution — biggest customer/item mover) + **Forecast** |
| "What changed vs last quarter / last year?" | **Growth** (QoQ/YoY) |
| "Which customers are growing fastest?" | **Customers** (fastest-growing) |
| "What should I chase today?" / "Where's my money stuck?" | **Cash** (chase list + leakage roll-up) |
| "Will I have enough cash next month?" | **Cash** (rough projection — collectible net of recurring expenses) |
| "Who might stop buying?" / "Who's slipping away?" | **Customers** (at-risk by cadence) |
| "Who should I contact this week?" | **Customers** (contact list — owed-money + at-risk, prioritized) |
| "Does this customer pay late?" / "Who's a reliable payer?" / "When will they pay?" | **Cash / Customers** (payment behavior & reliability — avg days-to-pay) |
| "Who can I upsell?" / "What sells together?" | **Items** (cross-sell) |
| "How's revenue split by segment / customer type?" | **Revenue** (by-segment — only if customers are tagged) |
| "Is next month usually busy or slow?" | **Patterns** (seasonal outlook — needs ~1.5+ yrs history) |
| "Where am I overspending?" / "Why did expenses go up?" / "Which subscriptions can I cancel?" | **Expenses** (trend + recurring) |

The cash-next-month answer is a **rough** projection (no bank balance) — present it as such. Payment timing is now answered as an **average** (the reliability insight: "pays ~N days late"); a precise per-invoice ETA would still need a model, so frame "when will *this one* be paid" as an estimate. Still genuinely **not** covered (don't promise): anything **profit/margin**-based ("most profitable item/customer") — needs item cost the API doesn't expose yet. If asked, answer what you can and say the rest isn't available.

### "What happened this week?"

Use `report digest --period week` for a concise briefing.

### "Show me my cashflow" / "Link to cashflow report" / "Open cashflow in Bookipi"

Bookipi hosts a cashflow view in the web app at the path `/cashflow/transactions`
on the web-app domain.

**⚠️ Never hardcode the domain — it differs per environment** (staging:
`ac-app.bkpi.co`; production: `web.bookipi.com`), and quoting the wrong one
sends users to a dead or wrong-environment page. Get the domain from a link
the CLI itself printed in this session (any `webUrl` from `invoice get --json`
or the 🔗 link on a create/finalize output — the CLI always uses the right
domain for its build), then append `/cashflow/transactions`.

When the user asks for a cashflow report, cashflow link, or wants to "view
cashflow in Bookipi", give them that URL directly — do NOT run
`bookipi report dashboard` or generate a local HTML file unless they
specifically ask for a local/offline dashboard.

If the user wants an analytical cashflow breakdown (inflows vs. outflows), combine `report summary` (paid invoices = inflows) with `expense list` (outflows) and present the monthly net — no dashboard needed for that either.
