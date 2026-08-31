# Invoice Commands

## Commands

```bash
# List invoices (returns formatted markdown with handles)
bookipi invoice list
bookipi invoice list --status sent,overdue --limit 10 --page 2
# Filters compose: by customer, date range, free-text — alongside --status / --type
bookipi invoice list --customer "Acme"           # name, @c1 handle, or ID
bookipi invoice list --from 2026-05-01 --to 2026-05-31
bookipi invoice list --search "INV-203"           # number or customer name
bookipi invoice list --customer @c1 --from 2026-01-01 --status paid

# Get a single invoice (by handle or ID)
bookipi invoice get @i1
bookipi invoice get 696f8a656eca5c6c312c9cfb

# Render a preview (HTML — same layout as the web app)
bookipi invoice preview @i1                             # self-contained HTML file
bookipi invoice preview @i1 -o inv.html --embed         # Artifact-ready fragment (wrapper dropped, images inlined) — use this for inline rendering
bookipi invoice preview @i1 --live                      # HTML that auto-refreshes — open once, updates as you edit
bookipi invoice preview @i1 --stdout > invoice.html     # raw HTML to stdout (don't pipe into an agent's context — see § Confirm visually)
# NOTE: --pdf (the htmlToPdf service) is intentionally NOT used by this skill for now — prefer HTML / the web link.

# Create an invoice — --customer and --item accept IDs, handles, or names
# If a name is given, the CLI searches existing records and creates if not found
bookipi invoice create \
  --company <company_id> \
  --number INV-001 \
  --date 2026-04-14 \
  --customer "Kelvin Santos" \
  --item "Consulting"

# Create with explicit item details (JSON) and multiple items
bookipi invoice create \
  --company <company_id> \
  --number INV-002 \
  --date 2026-04-14 \
  --customer @c1 \
  --item '{"name":"Design","price":200,"quantity":1}' \
  --item '{"name":"Development","price":150,"quantity":8}' \
  --due-date 2026-04-28 \
  --note "Net 14 payment terms"

# Use handles from previous list commands
bookipi invoice create \
  --company <company_id> \
  --number INV-003 \
  --date 2026-04-14 \
  --customer @c3 \
  --item @t2

# Create a different document TYPE on the same endpoint — estimate / credit-note /
# delivery-note / purchase-order (default is invoice). Numbering + labels adapt.
bookipi invoice create --type estimate --customer @c1 --date 2026-04-14 --item @t1
bookipi invoice create --type credit-note --customer "Acme" --date 2026-04-14 \
  --item '{"name":"Refund","price":50,"quantity":1}'
# List a specific document type (default invoice):
bookipi invoice list --type estimate
bookipi invoice list --type credit-note --status sent

# Recurring document — repeats on a schedule (day / week / month / year).
# Next-run date is auto-computed from --date + one interval (override with --next-run).
bookipi invoice create --customer @c1 --date 2026-04-14 --item @t1 --recurring month
bookipi invoice create --customer @c1 --date 2026-04-14 --item @t1 --recurring week --next-run 2026-04-21

# Duplicate an invoice — makes a fresh editable DRAFT copy (same customer/items/totals)
bookipi invoice duplicate @i1
bookipi invoice duplicate 696f8a656eca5c6c312c9cfb --timezone "Europe/Dublin"
bookipi invoice duplicate @i1 --customer "Acme Corp"   # reissue the copy to a different customer
# Duplicate AND convert to another document type — "duplicate this invoice into an
# estimate" → --type (alias --as). The copy is renumbered with the new prefix (EST-…).
bookipi invoice duplicate @i1 --type estimate          # invoice → estimate (aka a quote document)
bookipi invoice duplicate @i1 --as credit-note         # invoice → credit note
# Copy into a DIFFERENT company you own (customer re-created there, numbered in
# that company's sequence, original untouched). Company = an ID or @co handle —
# resolve the name to an ID via `company list` / `whoami` first if needed.
bookipi invoice duplicate @i1 --to-company @co2         # "duplicate this into my other company"

# Update an invoice (use named options for common fields)
bookipi invoice update @i1 --note "Payment received" --due-date 2026-05-01

# Mark an invoice paid (RECORDS a payment — the real "mark as paid") / void it
bookipi invoice mark-paid @i1                         # full balance, cash
bookipi invoice mark-paid @i1 --amount 500 --method transfer
bookipi invoice void @i1                              # clear payments → back to unpaid

# Due dates — absolute, relative, or removed (dueIn stays in sync automatically)
bookipi invoice update @i1 --due-date 2026-06-30   # set an exact date
bookipi invoice update @i1 --due-in 14             # 14 days after the invoice date (0 = due on receipt)
bookipi invoice update @i1 --remove-due-date       # no due date at all

# Deposits — request part of the total up front (doesn't change amountDue)
bookipi invoice create --customer @c1 --date 2026-06-10 --item @t1 --deposit 10%   # 10% of the total
bookipi invoice update @i1 --deposit 50 --deposit-due 2026-06-20                   # fixed ₱50, due June 20
bookipi invoice update @i1 --deposit-due 2026-06-25                                # retarget an existing deposit
bookipi invoice update @i1 --remove-deposit                                        # withdraw the request

# Edit line items — totals (subtotal/total/amountDue) recompute automatically
bookipi invoice update @i1 --add-item '{"name":"Rush fee","price":50,"quantity":1}'   # append a line
bookipi invoice update @i1 --set-item '{"name":"Consulting","quantity":5}'            # patch a line by exact name (or "_id")
bookipi invoice update @i1 --remove-item "Rush fee"                                   # remove by name, _id, or 1-based position
bookipi invoice update @i1 --item '{"name":"Design","price":200,"quantity":1}' \
  --item '{"name":"Dev","price":150,"quantity":8}'                                    # REPLACE the whole item list (same formats as create: JSON, name, @t1, ID)

# Update with --data for advanced/bulk fields
bookipi invoice update @i1 --data '{"discount":10,"taxPercentage":8}'

# Attach an image AT CREATION (invoice-level, separate from line-item photos):
bookipi invoice create --customer @c1 --date 2026-04-14 --item @t1 --photo ./site.jpg
bookipi invoice create --customer @c1 --date 2026-04-14 --item @t1 --photo ./a.jpg --photo ./b.jpg  # repeatable
# Or attach to an EXISTING invoice — appends to existing photos; --replace swaps them all.
# Shows on the invoice in the web app and the customer-facing document.
bookipi invoice attach-photo @i1 -f ./site-photo.jpg
bookipi invoice attach-photo @i1 -f ./before.jpg --title "Before" --description "Kitchen before the reno"
bookipi invoice attach-photo @i1 -f ./final.jpg --replace     # replace ALL existing photos
# Remove all photos: bookipi invoice update @i1 --data '{"photos":[]}'

# Send an invoice by email
bookipi invoice send @i1 -r customer@example.com
bookipi invoice send @i1 -r a@test.com,b@test.com -b bcc@test.com -s "Your invoice" -m "Please find attached"

# Email a PAYMENT RECEIPT for a paid invoice (amount defaults to the invoice total)
bookipi invoice send-receipt @i1
bookipi invoice send-receipt @i1 --amount 111 --date 2026-05-04 --brand Visa --last4 4242

# Delete an invoice
bookipi invoice delete @i1
```

### 🔴 "Estimate" / "quote" — an invoice-family document, NOT a proposal

This is a common mis-route. Bookipi has **two different things** people call a "quote":

- **Estimate** (aka a **quote / quotation document**) — a priced document built from
  line items, in the **same family as invoices** and handled by the **`invoice`
  command** with `--type estimate`. It has its own numbering (`EST-…`), lists via
  `invoice list --type estimate`, converts from an invoice via `invoice duplicate
  … --type estimate`, and is sent with `invoice send`. Credit notes, delivery
  notes, and purchase orders are the same family (`--type credit-note` / etc.).
- **Proposal** — an **AI-generated sales document** (a pitch/scope write-up) handled
  by the separate **`proposal`** command and the `quick-quote.md` flow.

Route by what the user means:

| The user says… | Use |
|---|---|
| "create an estimate", "make a **quote document**", "duplicate this invoice **into an estimate**", "convert INV-… to a credit note", "list my estimates" | `invoice` + `--type` (estimate/credit-note/delivery-note/purchase-order) |
| "**quote** Acme **for** the website redesign", "draft/send a **proposal**", "write up a pitch" | `proposal` — see `quick-quote.md` |

⚠️ **Never produce a proposal when the user asked for an estimate** (the T-10 bug).
"Duplicate an invoice into an estimate" is `invoice duplicate <id> --type estimate` —
it must stay in the invoice family, keeping the same line items and totals.

## Bulk Reminders (`bookipi invoice remind`)

Send reminder emails to overdue invoice customers in bulk. **This command is destructive (sends real emails), so always follow this flow:**

1. **Run a dry-run first** (the default): `bookipi invoice remind --min-days 7` — shows exactly who would be emailed, what subject/body would be sent (preview is included in the output), and lists skipped invoices with reasons.
2. **Present the plan to the user in plain language** — invoice numbers, customer names, amounts, days overdue. Do NOT show handles or raw commands.
3. **Ask the user to confirm via `AskUserQuestion`** (see `common.md` § Confirmation Style — never use a free-text "ready to send?" prompt for a destructive bulk action). Example:

   - **Question:** *"This would email 4 reminders totaling $34,877 to Kelvin Bookipi. Send them?"*
   - **Choices:** `["Send all 4", "Review individually first", "Cancel"]`
4. **Only when confirmed**, re-run with `--send`: `bookipi invoice remind --send --min-days 7`.
5. **Log it**: one dated line in the assistant-memory action log — how many reminders, total chased, user-approved (`docs/assistant.md`).

```bash
bookipi invoice remind                                 # preview all overdue (dry-run)
bookipi invoice remind --min-days 7                    # only 7+ days overdue
bookipi invoice remind --min-days 7 --max-days 90      # window: skip ancient write-offs
bookipi invoice remind --customer "Acme"               # match customer by name/email substring
bookipi invoice remind --invoice @i3                   # remind ONE specific invoice (even if not overdue yet)
bookipi invoice remind --send --invoice @i3            # ...and actually send it
bookipi invoice remind --limit 10                      # cap per run (default 50)
bookipi invoice remind --send --min-days 30            # ACTUALLY send reminders
bookipi invoice remind --send --subject "URGENT: {amount} due {days}d" \
  --message "Invoice {no} for {amount} was due {dueDate}. Please pay now."
```

Template placeholders for `--subject`/`--message`: `{no}`, `{amount}`, `{days}`, `{dueDate}`

**Language:** the built-in reminder templates are English. If the company's
language isn't English (check the company record / how the user writes),
compose translated `--subject`/`--message` text yourself — keep the
placeholders intact; they substitute regardless of language.

Key flags:

- `--min-days <n>` / `--max-days <n>` — overdue window (recommend `--min-days 7` so you don't nag on invoices that just became overdue yesterday)
- `--customer <substring>` — target a single customer
- `--invoice <id|@handle>` — remind **one specific invoice** ("remind them about INV-203"). Bypasses the overdue scan + day/customer filters, so it works even on an unpaid invoice that isn't overdue yet (it uses gentler "outstanding" wording in that case). A paid invoice is skipped ("no amount due").
- `--limit <n>` — cap sends per run (default 50)
- `--subject` / `--message` — override defaults with placeholders
- `--json` — programmatic output

The command skips invoices with no email on file, no amount due, or that fall outside the day window — check the "Skipped" summary in the output to understand coverage.

> **Want escalating pressure, not one flat blast?** `invoice remind` sends the
> *same* reminder to everyone in a window. For a **staged collections ladder** —
> gentle nudge → firm follow-up → final notice, each with its own tone (the later
> stages re-send the invoice and point the customer at its own pay link) — use
> `bookipi invoice collections` instead. See `docs/collections.md`. Rule of thumb:
> single nudge → `remind`; "run/work my collections" or a recurring daily chase →
> `collections`.

## How to Handle Common Invoice Requests

### Always confirm the invoice visually after create or edit

After you successfully **create** an invoice — or make any change that affects how it looks (line items, due date, deposit, number, note) — show the user the result without waiting for "show me."

**🔴 The inline preview + a one-line text summary ARE the confirmation. Do NOT surface the web link by default.** Render the invoice inline (path A) as the hero, and keep it updated **in place** every time the user edits it through you — add/change line items, due date, deposit, etc. Alongside the preview, **state a one-line summary in chat** — *"Created INV-001 for Wayne — ₱1,500, due Jul 31."* That text is the reliable "it worked" signal. **Don't add the web link on top of a rendered preview — under a full preview it's just clutter.** Surface the link **only** when: (a) the user asks to open / share / edit it; (b) there's no visual surface (path B — the link is then the only way to see it); or (c) the render **stalls** (stuck "Creating…", needs a click you can't make) — then the text summary already proves it's saved, so don't loop on the render; just say it's saved and offer the link so the user isn't left staring at a spinner (field report T-14). The invoice is **saved the moment `create` returns** (it hands back the record + a `webUrl`, so you always *have* the link ready — you just don't show it unless one of a/b/c applies).

**Decide the visual method by the surface that's actually available, NOT by the product name** — check your current tools, the same way the launcher does (see `SKILL.md` § Session-Start Launcher): is a visual/inline tool (`show_widget` / Artifact / any `mcp__visualize__*`) present? It **is** in Cowork **and in Claude Code running inside the Claude desktop or web app**; it is **not** in a bare terminal CLI, over SSH, or some IDE shells. (A `file://` link only opens on the user's own machine — never in a hosted chat.)

**A. A visual surface is available (Cowork, or Claude Code in the Claude desktop/web app) — render the invoice inline (the default, preferred experience), with a one-line text summary as the confirmation.**
1. **🔴 Write a self-contained file directly — NEVER pipe the HTML through your context.** Run `bookipi invoice preview <handle> -o <file>.html --embed` (write it into your scratch dir). `--embed` makes the **CLI** do all the prep: it drops the `<!doctype>/<html>/<head>/<body>` wrapper (the Artifact host adds its own), keeps the `<style>` blocks, **and inlines any product/line-item photos as `data:` URIs**. So do **NOT** use `--stdout` — that dumps **~40k+ tokens of HTML into your context on every render** and is the T-21 quota-killer — and do **NOT** hand-edit the HTML or base64 the images yourself; the CLI already did. **You never read the file's contents.** (If a photo's host is network-blocked the CLI can't inline it and prints a one-line stderr note; that image just shows broken in the sandbox — nothing for you to fix or retry.)
2. Render that **file** as an **Artifact** (the Artifact tool reads from the file path). The full invoice renders — styles and product photos included — and **none of it passes through your context**.
3. **This preview is a living surface — the primary way the user iterates.** On each later edit *made through you* (add items, change due date, deposit, note), re-run the **same** `invoice preview <handle> -o <same-file> --embed` and redeploy the **same Artifact path** so it updates **in place** — the new total / line items appear without a fresh link. Keep reusing that same file + Artifact path for the whole conversation. (Edits the user makes **directly in the web app** via the link are out-of-band and will **not** auto-refresh this preview — that's expected for now; just re-render it when they mention they changed it there.)
4. **Don't show the web link by default** — the preview + your one-line summary are the confirmation. As of 0.33.2 `invoice create` **no longer prints the link** in normal output, precisely so it can't be echoed by reflex; it's still in `--json` as `webUrl`, and `bookipi invoice get <handle>` (or `invoice create --link`) prints it on demand. Surface it **only on request** ("open it", "share the link", "let me edit it in Bookipi") or as the stall fallback in step 5. Present it as a tidy clickable Markdown link when you do.

   **🔴 That URL carries a live `authToken` JWT — it is a working credential, not just a deep link.** Pasting it into chat puts the user's Bookipi session into the transcript, into any screenshot they share, and into anything that indexes the conversation. Never print it "just in case", never include it in a summary, and never show the raw URL as text.
5. If the inline render doesn't complete (stuck "Creating…", needs a click, oversized payload), **don't loop on it** — your one-line summary already confirms the draft exists. Say it's saved and, since the render didn't show, *offer* the link so the user isn't stuck.

**B. No visual surface (a bare terminal — plain CLI, SSH, some IDE shells) — give a self-refreshing browser preview.**
- Surface `bookipi invoice preview <handle> --live`: it writes a local self-contained HTML file and prints a `file://` path. Tell the user to **open it once** — the `--live` auto-refresh updates that tab (~every 2s), so they watch line-item changes live as you edit. This works because the file is on the user's own machine (the `file://` "nothing happens" failure is hosted-chat-only, not here).
- Also offer the `invoice get` web link for opening / sharing / editing in the web app.

**Both environments:**
- **Also state the change in chat** so the update is legible without opening anything — e.g. *"Added rush fee → total $750 → $800."*
- **One visual per turn, not per sub-step** — apply all edits, then render/refresh once. Skip it for changes that don't alter the render (e.g. a status-only `--status paid`) unless asked.
- `--pdf` (the PDF service) stays **disabled for now** — don't use it.
- Never paste the (large) raw HTML into chat.

### "List my invoices" / "Show unpaid invoices" / "What's overdue?" / "Acme's invoices last month"

Run `invoice list` with the filters that match the request — they **compose**:
- `--status sent,overdue,paid,…` — payment/send state
- `--type estimate|credit-note|…` — document type (default invoice)
- `--customer <name|@c1|id>` — one customer (resolved to its ID)
- `--from <date> --to <date>` — date range (YYYY-MM-DD or ISO; bounds are inclusive)
- `--search <text>` — free-text on number / customer name

E.g. *"Acme's paid invoices this year"* → `invoice list --customer "Acme" --status paid --from 2026-01-01`. Add `--json` and extract when the user wants specific data points. (Note: the formatted header shows the returned page's item count, not the grand total — raise `--limit` if you need more than 15 in one page.)

### "Give me the link to invoice X" / "Open / share invoice X" / "Where can I view or edit it?"

Run `bookipi invoice get <handle-or-id>` and surface the `🔗` link it prints as a **clickable Markdown link**. The CLI picks the destination automatically and signs the URL with one-click auth (the user is auto-logged-in on click):

- An **editable draft** (status `saved`/`draft`, not yet paid) → opens the **editor** (`/documents/doc1/edit/<id>`).
- A **sent** or **paid** invoice → opens the read-only **preview** (`/documents/doc1/preview/<id>`).

**Never hand-build this URL or guess `/edit/` vs `/preview/`.** The CLI computes it from the invoice's status *and* payment state (a paid invoice can still carry status `saved`, so payment wins) and appends the auth params — you can't reproduce the auth signing yourself. In `--json` mode the same link comes back as a `webUrl` field. Don't show the raw URL with its `authToken=…` query string verbatim in a way that looks like a command — present it as a tidy clickable link (e.g. *"[View INV-696](…)"*).

### "Is INV-203 paid?" / "Did they view it?" / "What's the status?"

`invoice get <id>` leads with a single **Status** — the lifecycle badge: Draft → Sent → **Viewed** → Paid (or Overdue / Partially Paid). It's collapsed from the backend's `computedStatus`, so a paid invoice correctly reads **Paid** even when its raw document status is still "saved". **"Viewed" = the customer opened it** (raw status `read`). Read that one line for the answer; the **Payment Status** line adds paid/partial detail. To find a set: `invoice list --status read` (viewed, unpaid), `--status overdue`, `--status paid`, etc. If the invoice has status-change history, `invoice get` also prints an **Activity** timeline (sent → viewed → paid with dates).

### "Create an estimate / quote / credit note / delivery note / purchase order"

All of these are the **same** `invoice create` command with `--type` — they share one backend endpoint, differentiated by the document type:

| User says… | `--type` value |
|---|---|
| estimate / quote / quotation | `estimate` |
| invoice (default) | `invoice` |
| credit note / refund note | `credit-note` |
| delivery note | `delivery-note` |
| purchase order / PO | `purchase-order` |

`bookipi invoice create --type credit-note --customer @c1 --date <date> --item …`

Numbering and the document label adapt to the type (e.g. it continues that type's own number sequence, and `invoice get`/`list` show "Credit Note", "Estimate", etc.). To **view** non-invoice docs, pass the same `--type` to `invoice list` (e.g. `bookipi invoice list --type estimate`) — a plain `invoice list` only shows invoices. Everything else (send, duplicate, delete, preview, convert) works the same regardless of type.

### "Set up a recurring invoice" / "Bill them every month" / "Weekly invoice"

Add `--recurring <day|week|month|year>` to `invoice create`. The CLI sets the document's `schedule` and the backend repeats it on that cadence (it assigns a Recurring ID). The first recurrence (`nextRunDateUtc`) is auto-computed as the document `--date` + one interval; override with `--next-run <YYYY-MM-DD>`.

`bookipi invoice create --customer @c1 --date 2026-04-14 --item @t1 --recurring month`

Works with any document type too (`--type estimate --recurring month`, etc.). For exotic cadences (e.g. every 2 weeks), the backend supports multiples but the CLI exposes the four base intervals — use `--data '{"schedule":{"interval":"<exact>","nextRunDateUtc":"<iso>"}}'` if you need one. `invoice get` shows the schedule under a **Recurring** section.

### "Preview / print invoice X" / "Show me what INV-696 looks like"

> ⚠️ **PDF (`--pdf` / the htmlToPdf service) is disabled in this skill for now — do not use it.** Use HTML rendering or the web link instead. (Re-enable the `--pdf` guidance here once the PDF service is back in scope.)

Use `bookipi invoice preview <handle-or-id>` — it renders the invoice (same layout the web app uses) as a **self-contained HTML file** and prints a `file://` path.

> ⚠️ **`file://` paths are not clickable in a chat/Cowork session** — the file lives on the CLI's host and chat clients block local-file links, so clicking does nothing. Only present a `file://` path as a clickable link when the CLI runs on the **user's own machine in a terminal**. In a hosted/chat context, render the HTML **inline** (visualization widget) instead, or — if the user just wants to *view* or *share* the invoice — give them the `invoice get` **web** link, which opens in the browser everywhere.

- **Want a PDF?** Don't call `--pdf`. Give the `invoice get` web link and tell the user to *Print → Save as PDF* from the browser (or hand over the HTML file on a local-terminal session).

**View / share — pick by intent:**
- *"open it / view in Bookipi / edit it / share a link"* → `invoice get` (returns an authenticated web-app `🔗` link — live and editable).
- *"preview / what does it look like"* → `invoice preview` (HTML — render inline in chat, or `file://` on a local terminal).

Options: `--output <path>` to choose where the file is written; `--embed` to write an Artifact-ready, self-contained fragment (wrapper dropped, images inlined — use this for inline rendering, see § Confirm visually); `--stdout` to pipe raw HTML; `--json` returns `{ file, no, _id }`. **Don't paste the (large) HTML into the conversation**, and remember the `file://` caveat above — only offer it as a clickable link on a local-terminal session; otherwise render inline or give the `invoice get` web link.

### "Duplicate / copy invoice X" / "Make another one like INV-696" / "Reissue this invoice"

Use `bookipi invoice duplicate <handle-or-id>`. The server creates a **fresh editable draft** copy — same customer, line items, totals, and settings — with its own new `_id` (the duplicate starts unsent and not paid, even if the source was sent or paid). The command registers a handle for the new draft and prints its `🔗 Edit invoice` link (always `/edit/`, since a copy is always an editable draft).

**Copy into a different company** — *"duplicate this into my other company"*, *"move/transfer INV-696 to <Company>"* → `invoice duplicate <id> --to-company <company>`. The copy is created in the **target** company (the customer is re-resolved/created there, and it's numbered in that company's sequence); the **original is left untouched** (this is a copy, not a move — if the user truly wants the original gone, delete it after, and confirm first). `--to-company` takes a company **ID or `@co` handle** — if the user names the company, resolve it to an ID via `company list` / `whoami` first. Combine with `--type` to also convert the copy (e.g. copy an invoice into another company *as an estimate*).

**"Duplicate it for <other customer>" / "send the same invoice to X":** pass `--customer <name|@c1|id>` on the duplicate itself — it reassigns the copy AND its recipient email in one step. Do NOT duplicate and then patch the customer via `--data` (that leaves `recipientEmail` pointing at the old customer, so a later send goes to the wrong person). Customer resolution happens before the copy is created, so an ambiguous name fails cleanly with no stray draft.

Typical follow-ups after duplicating:
- *"change the amount / date / items"* → `bookipi invoice update <new-handle> …` (or open the edit link).
- *"send it"* → `bookipi invoice send <new-handle> -r <email>`.

The duplicate inherits the source invoice's number — that's expected; the user renumbers it on edit/send if they want. Timezone defaults to the host's zone; pass `--timezone <IANA>` only if the user wants the draft dated in a specific zone.

### "Send a receipt" / "Email a payment confirmation" / "They paid — send their receipt"

Use `bookipi invoice send-receipt <handle-or-id>`. It emails a **payment receipt** to the invoice's recipient. The amount defaults to the invoice total (override with `--amount`); date defaults to now (`--date` for the actual payment date); optionally include card `--brand` / `--last4`.

**This sends a real email — confirm first via `AskUserQuestion`** (recipient + amount), exactly like `invoice send`. Use it on invoices that are actually **paid**; if the invoice's payment status isn't paid the command prints a warning but still sends, so double-check before confirming. Don't confuse it with `invoice send` (sends the invoice itself) — `send-receipt` sends the *payment confirmation* after money is in.

### "Send invoice X to someone"

Use `invoice send @handle -r email@example.com`. If the user hasn't specified a recipient, ask for one — it's required. You can also add `-s` for subject and `-m` for a message body.

### "Create an invoice for..."

Use explicit options: `--company`, `--number`, `--date`, `--customer`, and one or more `--item` flags. Both `--customer` and `--item` accept names — the CLI will search for existing records and create them if not found. If the user gives partial info, ask for the rest. Use `--data` only for advanced fields not covered by named options.

**Dragged / pasted photos + "create an invoice" → attach them with `--photo`.**
When the user drops one or more images into the chat and asks to create an
invoice, attach them **at creation** with `--photo` (repeatable, so single or
multiple images work in one command):

```bash
bookipi invoice create --customer @c1 --date 2026-04-14 --item @t1 \
  --photo /path/one.jpg --photo /path/two.jpg
```

Steps: first **recover each image to a file on disk** — work the recovery
ladder in `docs/customers-and-items.md` § Product photos (file attachment →
session-transcript extraction → macOS clipboard → ask). The uploader accepts
**png / jpg / jpeg / webp / heic**; still convert **heic** (and webp if it
doesn't render cleanly on the customer-facing document) to jpg to be safe
(`sips -s format jpeg in.heic --out out.jpg`). Then pass each path as a
`--photo`. These are **invoice-level** attachments (they show on the invoice +
the customer-facing document), separate from line-item photos.

⚠️ **Disambiguate first — three different intents look identical:**
- *"Attach these images to the invoice"* → `create --photo` (this flow).
- *"These are products I'm selling → make line items"* → create/resolve the
  **items** and attach the photos to the ITEMS (see `docs/customers-and-items.md`),
  not the invoice.
- *"Here's a photo of a receipt / handwritten invoice — make an invoice from
  it"* → that's reading the image to extract data. We do OCR extraction for
  **expenses**, not invoice creation — read what you can by vision, fill the
  fields, and confirm with the user; don't claim an OCR feature we don't have.

If it's not obvious which they mean, ask one short question before creating.

**Recipe — dragged product photos → line items on a new invoice.** When the
user drops product photos and wants them as **line items** (intent #2 above),
each photo becomes an item that carries its own picture, and the invoice shows
those pictures on the line. There is no single command — chain these:

1. **Recover each image to disk** (recovery ladder in
   `docs/customers-and-items.md` § Product photos). Uploads accept png / jpg /
   jpeg / webp / heic; convert heic (and webp if it renders poorly) to jpg to
   be safe (`sips -s format jpeg in.heic --out out.jpg`).
2. **Create one item per photo, with the photo attached.** Read the name and
   price from the image by vision; if a price isn't visible, ask once (never
   default a real product to $0 silently):
   ```bash
   bookipi item create --name "Blue Ceramic Mug" --price 18 --photo ./mug.jpg
   # → returns the new item; note its handle (@t1) or _id
   ```
3. **Create the invoice referencing those items.** `resolveItem` copies each
   item's photo onto the line item, so the pictures render on the invoice:
   ```bash
   bookipi invoice create --customer @c1 --date 2026-04-14 \
     --item @t1 --item @t2 --item @t3
   ```

Why item-create-first: `--item` JSON can't carry a raw photo path — a photo has
to live on an item record before it can flow onto a line. So it's always
create-items-then-invoice, not inline. (To attach a picture to the whole
invoice instead of per line, that's `--photo` on `invoice create` — the flow
above.)

**Item price behavior when the item is new:**

When you pass `--item "some name"` as a plain string and no matching item exists, the CLI creates it with **price $0, quantity 1** (results in a $0 invoice). To avoid this, pass JSON instead:

```bash
--item '{"name":"test itemx","price":100,"quantity":1}'
```

If the user didn't specify a price for a brand-new item: either (a) ask them once, or (b) pick a sensible default (like $100), pass it as JSON, and tell the user what you defaulted to. Never read source code to "verify" this — the behavior is as documented.

**Minimum happy path — create + send an invoice:**

```bash
# 1. Create (company defaults to primary company)
bookipi invoice create --customer <handle-or-name> --number INV-XXX --date YYYY-MM-DD \
  --item '{"name":"Item name","price":100,"quantity":1}'
# → returns @iN handle AND prints "Recipient Email: <email> [@eN]"

# 2. Send — reuse the email from step 1's output
bookipi invoice send @iN -r <email-from-step-1>
```

Two commands. Don't re-derive this flow from scratch. If the customer handle is already known from earlier in the conversation, use it directly — do not re-run `customer list`. **Critically:** the `invoice create` output already contains the customer's recipient email (labeled "Recipient Email"). Do NOT run `customer list --search` or any other lookup to fetch that email before sending — just reuse it from the create response.

### "Mark INV-X as paid" / "record a payment" / "they paid me"

Use `invoice mark-paid @handle` — this **records a payment** (defaults to the full outstanding balance, method `cash`), which is what actually sets the payment status, clears the amount due, and shows up in payment history. Add `--amount` for a partial/custom amount, `--method` (cash / card / bank transfer), `--date`, or `--note`. **Destructive — confirm with the user first.**

> ⚠️ Do NOT use `invoice update --status paid` to mark something paid — that only flips the raw lifecycle flag and records no money, so the balance and payment history stay wrong.

To undo it — *"void the payment"*, *"un-mark as paid"*, *"that wasn't actually paid"* — use `invoice void @handle`. It clears the recorded payments and reverts the invoice to unpaid; it does **not** delete or cancel the invoice. **Destructive — confirm first.**

### "Update invoice status" (lifecycle only)

Use `invoice update @handle --status <saved|sent|read>` to flip the raw lifecycle status. To mark PAID, use `invoice mark-paid` (above), not `--status paid`. For other common fields use `--note`, `--due-date`, or `--number`; use `--data` for advanced fields not covered by named options.

### "Change the due date" / "Give them another week" / "Make it due on receipt"

Use the due-date flags on `invoice update` — they keep the invoice's `dueDate`/`dueIn`/`removeDueDate` fields consistent (web parity), so never set these via `--data`:

- **Exact date:** `invoice update @i1 --due-date 2026-06-30`
- **Relative** ("another week", "net 30", "due on receipt"): `invoice update @i1 --due-in 7` — days are counted from the *invoice date*, not from today. For "extend by a week" fetch the invoice, read its current due date, and pass the new absolute `--due-date`.
- **No due date:** `invoice update @i1 --remove-due-date`

A due date before the invoice date is allowed but makes the invoice immediately overdue — the CLI prints a note; confirm with the user if that looks unintended.

### "Ask for a deposit" / "Request 20% up front" / "They should pay half now"

Use `--deposit` on `invoice create` or `invoice update` — a percentage (`--deposit 20%`) or a fixed amount (`--deposit 250`). Percentage deposits compute the amount from the invoice total automatically. `--deposit-due <YYYY-MM-DD>` sets when the deposit is due (defaults to the invoice date — i.e. up front); on its own it retargets an existing deposit. `--remove-deposit` withdraws the request.

Facts that matter when talking to the user:
- A deposit does **not** reduce the amount due — it asks for part of it earlier. The deposit has its own lifecycle (`depositStatus`: saved → sent → paid).
- If line items change later, a **percentage** deposit recomputes automatically; a **fixed** deposit stays as-is and the CLI warns if it now exceeds the total.
- A fixed deposit larger than the invoice total is rejected.

### "Change the items / quantity / price on invoice X"

Use the line-item flags on `invoice update` — never hand-roll item JSON through `--data`:

- **Change quantity/price of an existing line:** `invoice update @i1 --set-item '{"name":"Consulting","quantity":5}'` — matched by exact item name or `"_id"`; remaining JSON fields are merged onto the line.
- **Add a line:** `invoice update @i1 --add-item '{"name":"Rush fee","price":50,"quantity":1}'` (also accepts an item name, `@t` handle, or ID, same as create).
- **Remove a line:** `invoice update @i1 --remove-item "Rush fee"` (by exact name, `_id`, or 1-based position).
- **Replace all lines:** repeatable `--item` (same formats as create).

The CLI fetches the invoice, applies the edits, and recomputes per-line totals plus `subtotal`/`total`/`amountDue` before saving — do NOT pass totals yourself. If the invoice carries invoice-level tax/discount/shipping, the recompute uses standard rules and prints a note to stderr; pass explicit totals via `--data` only if the user disputes the math. Flags compose in one call (removes → patches → adds). Removing every line is rejected — an invoice needs at least one item.

### "Delete invoice X"

Use `invoice delete @handle`. Confirm with the user before deleting — this is destructive.

### "Send reminders to everyone overdue" / "Chase up unpaid invoices"

Use `invoice remind` — see Bulk Reminders section above — for a **single** reminder
to everyone in a day-window.

### "Run my collections" / "Chase overdue properly" / "Escalate the late ones" / daily collections check

Use `invoice collections` — the **staged escalation ladder** (gentle → firm →
final; each send re-sends the invoice, which carries its own pay link). See
`docs/collections.md`. Prefer this over `remind` whenever the user wants the
account *worked* (escalating tone, a repeatable/scheduled cadence) rather than one
flat blast.

## Status Values

Valid invoice statuses: `saved`, `sent`, `read`, `partialPaid`, `overdue`, `undelivered`, `paid`
