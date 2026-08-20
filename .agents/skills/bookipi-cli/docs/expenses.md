# Expense Commands — Receipt Upload & Capture

The CLI supports logging expenses from receipt images and PDFs. The intended
flow leans on **Claude's native ability to read PDFs and images** — Claude
parses the receipt in-context, then calls `bookipi expense create` with the
extracted fields. Server-side OCR (`expense scan`) is available as a
fallback when the document is low-quality or Claude declines to parse.

## 🚨 Critical — `expense create` is destructive. Never probe with it.

`bookipi expense create` writes a real record to the user's live account
on every successful call. Treat it like `git push` to main, not like a
read-only probe.

**If `expense create` returns an unexpected error** (HTTP 500, schema
error, timeout, malformed GraphQL error, anything that isn't "success"
or a clear user-input validation message):

1. **Stop immediately.** Do NOT retry with variant payloads to narrow
   down which field is at fault — you will spam the live account with
   half-successful duplicates while you hunt.
2. **Report the raw error to the user verbatim** and ask whether to
   retry, try a different category, or open a server ticket.
3. **Never loop across categories/amounts/dates to isolate a bug.**
   If you need to know which categories work, ask the user or use a
   dedicated test account — never their account.

Safe read-only probes when you want to sanity-check the CLI setup:
`bookipi whoami`, `bookipi expense categories`, `bookipi expense list`.

If you created test records you need to clean up, use
`bookipi expense delete <id> [<id>...]` — see the Cleanup section below.

## Commands

```bash
bookipi expense categories                   # list default + custom categories (read-only, safe)
bookipi expense list                         # list expenses in the last 12 months (read-only, safe)
bookipi expense upload -f receipt.png        # upload to S3, print the keys (mostly for debugging)
bookipi expense scan -f receipt.png          # upload + run Bookipi's server-side OCR
bookipi expense create --merchant "Grab" --amount 585 --date 2026-04-10 --category "Other" -f receipt.png
bookipi expense delete <id>                  # delete one expense by _id (destructive)
bookipi expense delete -y <id> <id> ...      # bulk delete (requires -y)
```

## Preferred Flow — Let Claude Parse the Receipt

**⚠️ Pasted vs. attached:** an image *pasted* into chat has no obvious file — but the bytes are usually recoverable, so a pasted receipt CAN still be attached with `--file`. Work the recovery ladder in `docs/customers-and-items.md` § Product photos (file attachment → session-transcript extraction → macOS clipboard → ask): recover the image to disk, then proceed as if it were a file. If recovery fails, the parse-and-create flow below still works from vision alone — just skip the attach step and note the source in `--notes`.

When the user shares a receipt file (either uploaded into the Cowork session
or referenced by path), Claude should:

1. **Read the file directly.** PDFs and common image formats (PNG, JPG,
   HEIC, WebP) render in Claude's context — no external OCR needed.
2. **Extract the key fields** from the visible content:
   - merchant / vendor name
   - total amount (in the currency shown)
   - purchase date
   - a plausible **canonical** category — map user/receipt shorthand to the
     actual category name BEFORE calling create. If unsure, run
     `bookipi expense categories` first (see "Category matching" below).
   - optionally: invoice number, notes
3. **Call `bookipi expense create`** with those fields. When the receipt
   exists as a real file, add `--file <path>` so the original is attached in
   the Bookipi web app (the upload path was fixed in 0.25.x — it's reliable
   now). For paste-only receipts there's no file — mention the source in
   `--notes` instead so there's still a trail.
4. **Confirm briefly** to the user ("Logged $585 at Grab on Apr 10 as
   Other.") — never dump raw CLI output or handles.

### Example

Given `/sessions/<id>/mnt/uploads/grab-receipt.png` showing a $585 ride:

```bash
bookipi expense create \
  --merchant "Grab" \
  --amount 585 \
  --date 2026-04-10 \
  --category "Other" \
  --notes "Airport transfer (from grab-receipt.png)"
```

The command:

- Resolves "Other" against the category list, filling categoryId/categoryName.
- Converts 585 → 58500 cents (the amount unit the API expects).
- Converts 2026-04-10 → `2026-04-10T00:00:00.000Z`.
- POSTs the `bookipayExpensesCreateOne` mutation and reports the new record ID.

### Attaching the original file (`--file`)

`--file` uploads the original receipt to Bookipi's S3 bucket (original +
thumbnail) and links it to the expense record, so it shows in the web app.
**Use it whenever the receipt exists as a real file** — the historical
flakiness was a presign-parsing bug fixed in 0.25.x; uploads are reliable
now.

If an upload still fails (genuine network trouble), the create call aborts
**before** any DB write, so no duplicate expense is created. Recovery:

1. The CLI already retries transient 5xx/network failures 3× with backoff
   internally — so if the command still failed, retry the exact same command
   once more (a fresh presigned URL may succeed).
2. If it fails again, drop `--file` and create the expense without the
   attachment. The user can attach the file manually in the web app later.
3. Never loop through variants trying to make the upload work — that's
   exactly the kind of probing the "Critical" section above forbids.

### Amount format

`--amount` takes **dollars** (`585` or `585.00`). Internally it's multiplied
by 100 because the Bookipi API stores amounts as integer cents. If you
already have the raw cents value, pass `--amount-cents 58500` instead.

### Category matching

**🚨 Before creating an expense, ALWAYS run `bookipi expense categories` first
if the user gave an approximate or short category label** (e.g. "Meals",
"Office", "Subs", "Software", "Ads", "Training", "Comms", "Health", "Misc",
"Gas") rather than the full canonical name. The user's shorthand almost
never matches the canonical category name exactly — but the canonical list
is small (~15 defaults) and you can pick the right one yourself without
round-tripping through the user.

Rule of thumb:
- **Exact canonical name or key** (`"Meals & Entertainment"`,
  `"Meals___Entertainment"`, `"Travel"`, `"Other"`) → pass it straight through
  to `expense create`, no lookup needed.
- **Anything else** (`"Meals"`, `"food"`, `"office stuff"`, `"ads"`) → run
  `bookipi expense categories` first, pick the canonical match yourself, then
  call `expense create` with the canonical name. Do NOT send the shorthand
  and wait for a server error to course-correct — this spams the live account
  with failed writes and wastes the user's time.

Common shorthand → canonical mappings you can assume without a lookup if
you're confident:
- "meals", "food", "lunch", "dinner" → **Meals & Entertainment**
- "office", "supplies" → **Office Supplies**
- "subs", "software", "saas" → **Subscriptions & Software**
- "ads", "marketing" → **Marketing & Advertising**
- "training", "education", "course" → **Education & Training**
- "health", "medical", "wellness" → **Healthcare & Wellness**
- "comms", "phone", "internet" → **Telecommunications**
- "transport", "uber", "taxi", "gas" → **Transportation** (or **Travel** if
  it's a trip, not a local commute)
- "misc", "other", anything unrecognised → **Other**

Once you have a canonical name, the CLI matches it case-insensitively against:

1. Custom categories by `name`
2. Default categories by `name` or `key`

On a match, the command sets `categoryId` (custom) or `categoryName` only
(default). For **default** categories, `categoryName` is sent as the
category **key** (e.g. `Meals___Entertainment`), not the display name
(`Meals & Entertainment`) — this is handled internally by the CLI, so just
pass whatever the user-facing name is (e.g. `--category "Meals & Entertainment"`).
On no match, the CLI sends the raw hint as `categoryName` with a null
`categoryId` — the server accepts free-form labels in that case.

If you already know the custom category `_id`, pass `--category-id <id>`
to skip the lookup round-trip.

## Fallback Flow — Server-Side OCR

Only reach for this when Claude can't parse the receipt itself (e.g. the
file is a CR2 raw image, or the text is too blurry for visual parsing):

```bash
bookipi expense scan -f receipt.png
```

This uploads the file, runs Bookipi's server OCR, and prints the extracted
fields. Feed those fields into `expense create` — reuse the upload with
`--image-key`/`--thumbnail-key` so you don't upload twice:

```bash
bookipi expense scan -f receipt.png --json > /tmp/scan.json
# Claude reads /tmp/scan.json, picks out the fields, then:
bookipi expense create \
  --merchant "$(jq -r .scanned.merchantName /tmp/scan.json)" \
  --amount-cents "$(jq -r .scanned.amount /tmp/scan.json)" \
  --date "$(jq -r .scanned.purchaseDate /tmp/scan.json)" \
  --image-key "$(jq -r .upload.filename /tmp/scan.json)"
```

Note: `scanInvoiceImage` returns `amount` as an integer already — its unit
may be cents or whole currency depending on the backend. Inspect the value
before picking `--amount` vs `--amount-cents`.

## Presentation Rules

Same as everywhere else:

- **Never** show raw CLI commands or S3 keys to the user.
- Refer to the expense by merchant, amount, and date.
- Only say "receipt attached" when `--file` was explicitly used and
  succeeded — the default flow parses the receipt in-context and does not
  attach it.

Good (default flow, no attachment):

> Logged **$585 at Grab** on Apr 10 under **Other**.

Good (user asked for the file to be attached and it uploaded cleanly):

> Logged **$585 at Grab** on Apr 10 under **Other** — receipt attached.

Bad:

> Ran `bookipi expense create --amount-cents 58500 --image-key 2a30...png`. Record ID: 68041…

## Cleanup — Deleting Test / Mistaken Expenses

`bookipi expense list` shows the most recent expenses with their `_id`s.
To remove one or more:

```bash
# Single delete — no confirmation needed
bookipi expense delete 69e7a138e78ac08febf532de

# Bulk delete — requires -y so an accidental glob doesn't nuke a page
bookipi expense delete -y <id1> <id2> <id3>
```

Always show the user the list (merchant / amount / date) and ask before
deleting. Do not delete records the user didn't explicitly identify.

## Common Pitfalls

| Symptom                                 | Cause / Fix                                                                                                    |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Amount saved as 1/100th of expected     | Passed cents to `--amount` (which expects dollars). Use `--amount-cents`, or divide by 100.                    |
| "S3 upload failed (HTTP 403)"           | Presigned URL expired — they're short-lived. Re-run the command so `expense create` requests a fresh URL.      |
| Category missing in the Bookipi UI      | The category hint didn't match any default or custom category. Either use `expense categories` to see the list, or create the custom category in the web app first. |
| Receipt not visible in the web app      | `imageKey` was passed but `thumbnailKey` wasn't (or vice versa). Pass both, or pass `--file` to let the CLI upload both for you. |
