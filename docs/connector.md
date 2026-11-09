<!-- Edit this in Bookipi-Group/bookipi-agent-cli; a release publishes it to Bookipi-Group/bookipi-cli, where its relative links resolve. -->

# Bookipi connector

The Bookipi connector is a hosted [MCP](https://modelcontextprotocol.io) server
at:

```
https://mcp.bookipi.com/mcp
```

Add it to Claude (or any MCP client) and your Bookipi account is available in
chat with nothing to install — no download, no folder setup, no API key. Your
login is stored with your Claude account, so it works across devices and
persists between conversations.

Requires a Bookipi account (free tier included). If you don't have one yet,
sign up at [bookipi.com](https://bookipi.com) — or just connect and create one
during sign-in with your Google or Apple account.

## What connecting gives you

Bookipi runs the back office of a small business: invoices, customers,
expenses, deals, proposals, eSign contracts, meetings, reports and the company
website — all from a conversation.

**Reads:** outstanding and overdue invoices, a customer's full payment history,
expenses by category, pipeline deals, proposals and contracts and where each
one stands, recorded meetings with transcripts and summaries, revenue and
top-customer reports, and the state of the company website.

**Writes:** create and send invoices; record payments and issue receipts; copy
an invoice into an estimate, credit note, delivery note or purchase order; send
reminders on overdue invoices; add customers and catalogue items; log expenses
from a photographed receipt; move deals through the pipeline; draft and send
proposals; prepare eSign contracts; and edit and publish the website.

**Payments:** Bookipi can issue a payment link and record that an invoice has
been paid. Money moves only on Bookipay's own hosted checkout, in the
customer's browser. No funds are transferred by the connector.

## Connect

**claude.ai / Claude Desktop:** go to **Settings → Connectors → Add custom
connector**, paste `https://mcp.bookipi.com/mcp`, and click **Add**.

**Claude Code:**

```
claude mcp add --transport http bookipi https://mcp.bookipi.com/mcp
```

**Gemini CLI:** the `bookipi` extension
(`gemini extensions install https://github.com/Bookipi-Group/bookipi-cli`)
includes the connector. To add only the connector, without the skill:

```
gemini mcp add --scope user --transport http bookipi https://mcp.bookipi.com/mcp
```

Either way, run `/mcp auth bookipi` inside Gemini CLI to sign in.

**Other MCP clients:** any client that supports remote MCP servers over
streamable HTTP with OAuth discovery can use the same URL. No manual OAuth
configuration is needed — the server advertises everything the client needs.
It is also listed in the official
[MCP Registry](https://registry.modelcontextprotocol.io/?q=bookipi)
as `io.github.Bookipi-Group/bookipi`, so clients and directories that read the
registry can find it by name.

## Sign in

The first time Claude uses a Bookipi tool, your browser opens to Bookipi's own
sign-in page (`auth.bookipi.com`). Sign in with your Bookipi email, or with
your Google or Apple account — which also works for creating a new account on
the spot. There is no API key to copy and no software to install; the
connector never sees your password. If your account has more than one company,
tell Claude which one to work in — or just ask "what companies do I have?".

## Writes ask first

Every tool that changes something — creating an invoice, recording a payment,
sending anything — is marked as a write, so Claude stops and asks for your
confirmation before it runs. Read-only tools (listing invoices, running
reports) run without a prompt.

For invoices you can also ask for a preview first: Claude shows exactly what
would be created or changed, and nothing is written until you confirm.

## Disconnect

Remove the connector wherever you added it:

- **claude.ai / Claude Desktop:** **Settings → Connectors**, find Bookipi and
  remove it.
- **Claude Code:** `claude mcp remove bookipi`

Removing the connector ends its access to your Bookipi account. Your Bookipi
data is untouched — it lives in your Bookipi account either way.

## Connector or skill?

This repo also ships the [Bookipi CLI skill](../README.md) — a different way to
use Bookipi from chat, where Claude drives a locally installed CLI. The skill
offers some flows the connector doesn't; the connector is the zero-setup
option and the only one that works on claude.ai in the browser. You don't need
both. When the skill finds Bookipi connector tools in a session (including the
Gemini CLI extension, which bundles the connector), it uses them and not the
CLI, so the limits below apply there too.

## What the connector doesn't do

The items below are known differences, not bugs. Everything else the CLI does
has a connector tool.

| You ask for… | CLI | Connector |
| --- | --- | --- |
| A quote, estimate, credit note, delivery note or purchase order | `invoice create --type estimate` (and the other types) | **Not yet.** `create_invoice` only makes invoices. `copy_invoice` can convert an existing invoice into another type, but that needs an invoice to copy first. |
| Listing estimates and other non-invoice documents, or filtering by customer or date | `invoice list --type`, `--customer`, `--from`, `--to`, `--sort` | `list_invoices` lists invoices only, filtered by status and a text search. `list_recurring_invoices` does take `document_type`. |
| Changing an invoice's status or number, or editing one line item | `invoice update --status`, `--number`, `--add-item`, `--set-item`, `--remove-item`, `--reset-status` | `update_invoice` replaces the whole `items` list; it can't set the status or number. |
| Scanning a receipt or attaching a photo from your computer | `expense scan`, `expense upload`, `item set-photo`, `invoice create --photo` | The hosted connector can't read your disk, and there is no way to send it the file yet. It works only when the MCP server runs locally (`bookipi mcp`). |
| Uploading your own PDF as an eSign contract | `contract upload` | Not available. Draft one with `draft_contract` instead. |
| The staged overdue-collections ladder (gentle, firm, final) | `invoice collections` | `remind_invoice` sends one reminder per invoice; it picks gentler wording for invoices not yet overdue. |
| Switching the default company | `company set` | Pass `company_id` on each call; `whoami` lists the companies. |
| Sign-in, workspace setup, calendar setup | `login`, `setup`, `init`, `calendar` | Not needed: sign-in happens when you connect. `calendar_status` reports the calendar connection. |

Both ask before anything that emails someone, records a payment, publishes or
deletes. On the CLI that is `--yes`; on the connector it is a preview (`plan`)
followed by your OK.

## Support and policies

- Questions or problems: [support@bookipi.com](mailto:support@bookipi.com), or
  [open an issue](https://github.com/Bookipi-Group/bookipi-cli/issues).
- Security issues: see [SECURITY.md](../SECURITY.md) — please report privately.
- [Privacy policy](https://bookipi.com/privacy-policy/) ·
  [Terms of service](https://bookipi.com/terms-of-service/)
