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

**Other MCP clients:** any client that supports remote MCP servers over
streamable HTTP with OAuth discovery can use the same URL. No manual OAuth
configuration is needed — the server advertises everything the client needs.

## Sign in

The first time Claude uses a Bookipi tool, your browser opens to Bookipi's own
sign-in page (`auth.bookipi.com`). Sign in with your Bookipi email, or with
your Google or Apple account — which also works for creating a new account on
the spot. There is no API key to copy and no software to install; the
connector never sees your password. If your account has more than one company, tell Claude which one to
work in — or just ask "what companies do I have?".

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
offers some flows the connector doesn't (and vice versa); the connector is the
zero-setup option and the only one that works on claude.ai in the browser. You
don't need both.

## Support and policies

- Questions or problems: [support@bookipi.com](mailto:support@bookipi.com), or
  [open an issue](https://github.com/Bookipi-Group/bookipi-cli/issues).
- Security issues: see [SECURITY.md](../SECURITY.md) — please report privately.
- [Privacy policy](https://bookipi.com/privacy-policy/) ·
  [Terms of service](https://bookipi.com/terms-of-service/)
