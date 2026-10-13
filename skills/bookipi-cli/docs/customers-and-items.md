# Customer & Item Commands

> **Available subcommands today:** `customer` supports `list`, `get`, `create`, `update`, `delete`, `send-email`, and `emails` (read-only email history). `item` supports `list` and `create` (no `item get`, `item update`, or `item delete`). Don't guess at `item get` — it doesn't exist.

> **Reading the email history:** `bookipi customer emails <customer>` lists messages newest-first with a direction marker (→ sent to the customer, ← received from them), whether each was opened, `↩` if it has a reply, `📎` if it has attachments, and a `Re` column linking the related invoice (`INV-…`) or proposal. Use it for *"show my emails with Acme"*, *"did Wayne reply?"*, *"what have I sent this customer?"*. It's read-only — to actually send, use `customer send-email` (or the resource-specific sends).

## Customer Commands

```bash
# List customers (returns formatted table with handles)
bookipi customer list
bookipi customer list --search "John" --limit 10 --page 2
bookipi customer list --json

# Get a single customer's full details by ID or handle
bookipi customer get @c1
bookipi customer get @c1 --json

# Create a customer
bookipi customer create --first-name "John" --last-name "Doe" --email "john@example.com"
bookipi customer create --company-name "Acme Corp" --email "billing@acme.com" --phone "+1234567890"

# Create with additional fields via --data
bookipi customer create --first-name "Jane" --last-name "Smith" \
  --data '{"jobTitle":"CTO","address":{"address1":"123 Main St","city":"Sydney","country":"AU"}}'

# Update a customer — all fields optional, at least one required
bookipi customer update @c1 --email "new@example.com"
bookipi customer update @c1 --notes "Referred by Acme"
bookipi customer update @c1 --data '{"phone":"+61400000000","jobTitle":"CTO"}'

# Delete a customer — this is a soft delete (moves to trash, not permanent)
# The record continues to exist server-side; linked invoices are unaffected.
bookipi customer delete @c1
bookipi customer delete 6621a3f4c8b2e10012abc123
bookipi customer delete @c1 --json

# Send a standalone email to a customer — independent of any invoice/proposal/contract.
# Use when the user says "email Acme about X", "send a note to @c1", "follow up with
# Wayne", "reply to that customer". Auto-detects HTML in --body; otherwise wraps plain
# text in <p> with newlines as <br>. Add --cc / --bcc for additional recipients.
bookipi customer send-email @c1 --yes \
  --to kelvin@bookipi.com \
  --subject "Following up" \
  --body "Hi Kelvin, just checking in on the proposal."

# HTML body — passed through unchanged, plain-text fallback derived by stripping tags
bookipi customer send-email "Wayne Construction" --yes \
  --to wayne@example.com --cc finance@example.com \
  --subject "Invoice INV-186 attached" \
  --body "<p>Hi Wayne,</p><p>Invoice attached.</p>"

# Multiple recipients — repeat --to or pass comma-separated
bookipi customer send-email @c1 --yes \
  --to "a@x.com,b@x.com" --to c@x.com \
  --subject "Update" --body "Sending the revised quote tomorrow."

# Email history for a customer (sent + received, newest first) — read-only
bookipi customer emails @c1
bookipi customer emails "Wayne Construction" --limit 20 --page 2
bookipi customer emails @c1 --json
```

> **`send-email` is for ad-hoc / freeform messages.** For invoice / proposal / contract sends, use the resource-specific commands (`invoice send`, `proposal send`, `contract send`) — those generate the right templates and update record state. Don't use `customer send-email` to deliver an invoice.

## Item/Product Commands

```bash
# List items/products (returns formatted table with handles)
bookipi item list
bookipi item list --search "Consulting" --limit 20
bookipi item list --json

# "Get" a single item's full details — use search + json
bookipi item list --search "Consulting" --json

# Create an item/product
bookipi item create --name "Consulting" --price 150 --company <company_id>
bookipi item create --name "Design Work" --price 200 --company <company_id> --code "DSN-001" --unit hour --description "UI/UX design services"

# Create WITH a product photo (png, jpg, jpeg, webp, heic — image is uploaded first)
bookipi item create --name "Logo Design" --price 2000 --photo ./logo-sample.jpg

# Attach or REPLACE the photo on an existing item (an item holds one photo — set-photo swaps it)
bookipi item set-photo @t1 -f ./product.jpg
```

### Product photos — "add this image to the item" / "create an item from this photo"

When the user drags in a product image (or a photo of something they sell):

1. **Read the image yourself** (vision) to extract the name/price if the user hasn't given them.
2. `bookipi item create --name "..." --price ... --photo <path>` — one command creates the item WITH the image attached. For an existing item, use `bookipi item set-photo <handle> -f <path>` instead.
3. The photo shows in the web app's item catalog and on invoice line items.

Don't confuse this with **expense receipts** (`docs/expenses.md` — `expense scan`/`upload`): a receipt the user wants *logged as an expense* goes through the expense flow; an image the user wants *on a product* goes through `--photo`/`set-photo`. If ambiguous ("here's a receipt for the chair I sell"), ask via `AskUserQuestion`.

**⚠️ Pasted images.** An image *pasted* into chat may arrive as vision content
with no file behind it. Use the user's attachment if there is one (in Cowork: the
session's uploads dir or the mounted project folder; in Claude Code: the path
shown with the attachment). Item photos accept png/jpg only — convert webp/heic
first (macOS: `sips -s format jpeg <in> --out <out>.jpg`); expense receipts accept
webp as is, and invoice photos are covered in `docs/invoices.md`. No file → do the vision work
you can (read name/price, even create the item without a photo), then one
plain-language line: *"Got the details — to attach the photo itself, just drag it
straight into the chat and I'll add it."* Never say "path", "file on disk" or
"Finder"; never read the conversation's local history files or the clipboard to
dig out an image; never claim an upload succeeded without a real file.

## Extending to Future Resources

This CLI is designed to grow. When new resource commands are added (e.g., `payment`, `expense`), they'll follow the same patterns:

- `<resource> list` with `--status`, `--page`, `--limit`, `--sort`, `--json`
- `<resource> get <id|handle>`
- `<resource> create --data '{...}'`
- `<resource> update <id|handle> --data '{...}'`
- `<resource> delete <id|handle>`

Handles will use new prefixes (e.g., `@p` for payments). The same principles apply — check auth first, use handles when available, confirm destructive actions.
