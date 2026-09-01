# Bookipi CLI

[![release](https://img.shields.io/github/v/release/Bookipi-Group/bookipi-cli?label=release)](https://github.com/Bookipi-Group/bookipi-cli/releases/latest)
[![release status](https://github.com/Bookipi-Group/bookipi-cli/actions/workflows/release.yml/badge.svg?event=release)](https://github.com/Bookipi-Group/bookipi-cli/actions/workflows/release.yml)

**Bookipi CLI** turns your back office — invoices, payments, customers,
expenses, proposals, contracts, and reports — into clean `--json` commands you
can run directly or drive through Claude in plain English.

Full overview and docs: [Bookipi CLI](https://bookipi.com/cli/)

## Two ways to use it

- **Talk to Claude** — install the skill and ask in plain English inside
  Cowork, Claude Desktop, or Claude Code. Claude runs Bookipi CLI for you; no
  commands to memorize. Setup is below.
- **Build on the CLI** — clone it, run `bookipi init`, and pipe `--json`
  output into your own agents, automations, and products. See
  [Building on the CLI](#building-on-the-cli).

Either way it's the same tool underneath. Everything that sends, charges, or
records stops for your confirmation first.

## Talk to Claude

The skill bundle is self-contained (it includes the Bookipi CLI), so no
separate installation is required. You don't run commands — you talk to Claude
and Claude does the work. This guide shows you how to set that up.

### 1. Install the skill

1. Download the latest `bookipi-cli.skill` from
   [Releases](https://github.com/Bookipi-Group/bookipi-cli/releases).
2. Double-click it. Cowork or Claude Desktop will prompt to install.
3. Confirm. It now appears in your Skills list as `bookipi-cli`.

If double-click does nothing, drag the file into the Cowork window. If your
browser stripped the `.skill` extension on download, rename it back.

**Claude Code:** install it as a plugin instead — no download, and upgrading
later is two commands rather than a re-download:

```
/plugin marketplace add Bookipi-Group/bookipi-cli
/plugin install bookipi@bookipi-cli
```

Claude fetches the CLI on first use, so there's nothing else to install. You
need Node 22.12 or newer on your machine.

To upgrade later, refresh the marketplace **first** — `install` and `update`
both read a local copy of this repo, so without the refresh they will happily
keep serving the version you originally cloned:

```
/plugin marketplace update bookipi-cli
/plugin update bookipi@bookipi-cli
```

Include the `@bookipi-cli` part — `update bookipi` on its own reports
"Plugin not found".

A skill installed via Claude Desktop is also available in Claude Code sessions
started from the desktop app, so you may already have it. To install by hand
instead, unzip the `.skill` file into `~/.claude/skills/` (it's a zip — you'll
end up with `~/.claude/skills/bookipi-cli/`).

**Codex:** add this repo as a marketplace and install from it — the plugin
carries its own Codex manifest, so you get the Bookipi icon and starter prompts
rather than a bare listing:

```
/plugin marketplace add Bookipi-Group/bookipi-cli
/plugin install bookipi
```

**Gemini CLI:** install it as an extension:

```
gemini extensions install https://github.com/Bookipi-Group/bookipi-cli
```

Upgrade later with `gemini extensions update bookipi`.

**Other agents** — Cursor, GitHub Copilot, Antigravity, Windsurf — read
skills from `.agents/skills/`, which this repo publishes alongside the Claude
path. Copy `.agents/skills/bookipi-cli/` into your project or agent skills
directory.

### 2. Allow network access (only on your own Claude subscription, one-time)

You can skip this entirely if:

- You're on Claude Code — it runs on your own machine with your normal network,
  so an org allowlist doesn't apply.
- Your workspace admin has already allowlisted the domains below.

You only need this if you're using Cowork / Claude Desktop on your own
workspace/org. Cowork runs Claude in an Anthropic-hosted sandbox that blocks
unknown websites, so Bookipi's servers must be on your org's allowlist —
otherwise login will fail on the first try. (Tip: if you hit network trouble in
Cowork, switching to Claude Code is a quick workaround.)

Ask your workspace admin (or do it yourself if you're an admin):
**Organization Settings → Capabilities → Code execution → Additional allowed
domains**, and add:

```
*.bkpi.co
*.bookipi.com
*.bookipay.com
*.s3.amazonaws.com
*.amplitude.com
```

The first three are Bookipi servers (invoices, login, meetings, contracts, PDF
rendering). The S3 one is only needed for uploading receipt photos and showing
logos/QR codes in invoice previews.

**How you'll know it's missing:** Claude will tell you directly — something like
"this environment is blocking network access to Bookipi's servers", usually on
the very first request. That message includes the same list above; forward it to
your admin.

### 3. Set up your project folder

Every Bookipi workspace lives in its own **local folder**. This keeps your
credentials and account-specific data scoped — no env-var juggling, no
shared global state.

> ⚠️ **Cowork changed how projects are stored.** New projects are now
> **cloud-based by default** — they do _not_ create a local folder unless you
> ask for one. A cloud-only project runs in a temporary space that's wiped
> between chats, so your Bookipi login **won't survive** to the next session.
> To stay logged in, you **must** attach a local folder when you create the
> project (below).

1. In Cowork, click **New Project**, give it a name like `bookipi-testing`,
   then click **Use a folder** and pick (or create) a folder on your computer.
   This is the important step — without it, the project is cloud-only and your
   login won't persist.
   **In Claude Code** there's no button — just start `claude` inside any
   folder you want to use as the workspace.
2. In the chat, say:

   > _Set up Bookipi in this folder._

Claude opens a browser to sign you in to Bookipi, then saves your credentials
inside the folder (under `.bookipi/`, auto-gitignored). Confirm with:

> _Who am I logged in as?_

Every session you open in that project is auto-logged-in. To work with a
different Bookipi account, create a different folder and repeat — each
folder is its own workspace.

**If you skip the folder in Cowork** (a cloud-only project), you'll be asked to
log in again every new chat — there's nowhere persistent to keep the
credentials. Attaching a folder is the only way to stay logged in between
sessions. _(A no-folder, zero-setup alternative — the **Bookipi connector**,
which stores the login on your Claude account — is in the works; ask if you want
early access.)_

**Claude Code only:** the folder is recommended, not required. If you skip
it and just say _"log me in to Bookipi"_, credentials are saved globally
(`~/.bookipi/`) and work from any directory on your machine — fine for a
single account. Use per-folder workspaces when you want to test multiple
accounts side by side.

### 4. Try things

#### Reading

- "Who owes me money?"
- "Pull up Wayne Construction."
- "Show my overdue invoices."
- "Show me what INV-650 looks like." (you get a print-ready PDF)
- "List my open proposals."
- "Show my pending contracts."
- "What deals are in proposal stage?"
- "Show me my items / products."
- "What's on my calendar today?"
- "Find my meetings with Maria this week."
- "Is my Google Calendar connected?"
- "Give me the morning brief."
- "How much did I invoice last month?"
- "Who's my biggest customer this quarter?"
- "What products are selling well?"

#### Creating

- "Add a new customer: Acme Corp, billing@acme.com."
- "Add 'logo design' to my items list at $200."
- "Add a new deal — Stark kitchen renovation, $40,000."
- "Create an invoice for Acme — $5,000 for consulting."
- "Draft a proposal for the Stark deal — kitchen renovation, $40,000."
- "Turn that accepted proposal into a contract."

#### Sending

- "Send invoice INV-650 to alice@acme.com."
- "Send the proposal to John."
- "Send the MSA contract to Bruce."
- "Email Maria — tell her I'll be late to the call."
- "Send reminders to all my overdue invoices."

#### Receipts & expenses (drag an image/PDF into chat)

- (drop in a receipt photo) "Log this as an expense."
- "What expense categories do I have?"
- "Show my expenses this month."

#### Reports & insights

- "Build me a dashboard for last quarter." (opens an HTML report)
- "Give me insights on my business this month."
- "What should I focus on this week?"

#### Acting / changing things

- "Mark the Stark deal as won."
- "Mark INV-650 as paid."
- "Update Wayne's email to wayne@new-domain.com."
- "Has Bruce signed the MSA yet?"
- "Switch to my other Bookipi account."
- "What companies do I have?"
- "Log me out."

Everything that sends, charges, or records stops for your confirmation first.

## Building on the CLI

Bookipi CLI is also a standalone, JSON-first command-line tool you can build on
directly — for AI agents, automations, integrations, and your own products. The
bundled CLI runs on Node 22+ with no build step.

Grab the bundled CLI from the latest release — this repo holds the skill and
docs, not the CLI source, so cloning it won't give you a binary:

```
curl -fsSL -o bookipi-cli.skill \
  https://github.com/Bookipi-Group/bookipi-cli/releases/latest/download/bookipi-cli.skill
unzip -q bookipi-cli.skill 'bookipi-cli/bin/*'
alias bookipi='node "$PWD/bookipi-cli/bin/bookipi.js"'

bookipi init                                   # creates a workspace + browser OAuth sign-in (~5s)
bookipi invoice list --status overdue --json   # structured output your code can act on
```

For headless or CI use, skip the browser sign-in and set a token instead:

```
export BOOKIPI_TOKEN=...
```

Add `--json` to any command for machine-readable output. A typical example:

```
$ bookipi invoice list --status overdue --json
[
  { "number": "INV-650", "customer": "Acme Corp", "amount": 5000, "currency": "USD", "status": "overdue", "days_late": 12 },
  { "number": "INV-661", "customer": "Stark Ind.", "amount": 12000, "status": "overdue", "days_late": 4 }
]
```

### Commands

A small, predictable, `--json`-first surface your code can call reliably. Every
command accepts `--json`; run `bookipi <group> --help` for the flags on any one
of them.

| Group | What it covers | Subcommands |
| --- | --- | --- |
| `invoice` | Invoices and the wider document family | `list` `get` `preview` `create` `create-from-proposal` `duplicate` `update` `delete` `send` `send-receipt` `mark-paid` `void` `remind` `collections` `attach-photo` |
| `customer` | Customers, their payment history and email | `list` `get` `payments` `create` `update` `delete` `send-email` `emails` |
| `item` | Products and services you bill for | `list` `create` `set-photo` |
| `expense` | Expenses and receipt scanning (OCR) | `categories` `list` `upload` `scan` `create` `delete` |
| `paylink` | BPay payment links | `create` `list` `get` `status` `send` |
| `deal` | Pipeline deals | `list` `create` `update` |
| `proposal` | AI-written proposals | `list` `generate` `update` `duplicate` `send` `delete` |
| `contract` | eSign contracts | `list` `draft` `upload` `create-from-proposal` `finalize` `send` |
| `report` | Reports, dashboards and insights | `summary` `customers` `items` `dashboard` `insights` `digest` `suggest` `open` |
| `meeting` | Recorded meetings and bookings | `list` |
| `calendar` | Calendar connection state | `status` |
| `company` | The active company | `list` `set` |
| `website` | The AI-built company website | `status` `content` `pages` `page` `create` `generate` `add-page` `update` `ask` `preview` `publish` `analytics` `open` |
| — | Session and workspace | `login` `logout` `whoami` `init` `mcp` |

Note the difference between the two paths: in chat, the skill stops and asks
before anything sends, charges, or records. The CLI has no such prompt — a
write subcommand executes as soon as you run it, which is what you want in a
script and worth knowing before you wire one up.

## Found a bug? Stuck?

Open an issue on
[GitHub](https://github.com/Bookipi-Group/bookipi-cli/issues) with:

- What you typed
- What Claude did
- What you expected

The more detail, the faster we can help.

**Security issues:** please don't open a public issue — see
[SECURITY.md](SECURITY.md) for how to report privately.

## Privacy

Bookipi CLI talks only to Bookipi's own services, on your behalf, using your own
Bookipi account. Full policy: **[bookipi.com/privacy-policy](https://bookipi.com/privacy-policy/)**.

**What it collects and where it goes**

- **Your Bookipi business data** — invoices, customers, items, expenses, deals,
  proposals, contracts, meetings, website content. Read from and written to
  your Bookipi account over HTTPS. Nothing is stored anywhere else.
- **Credentials** — an OAuth access token and refresh token, obtained by
  browser sign-in. Stored **locally on your machine** in the workspace folder
  (`.bookipi/`, auto-gitignored) or in `~/.bookipi/`. They are never sent
  anywhere but Bookipi's auth service, and `bookipi logout` deletes them.
- **Receipt and logo images** — uploaded to Bookipi's S3 storage so scanning and
  invoice previews work.
- **Usage analytics** — which command or tool ran, how long it took, whether it
  failed, plus CLI version, OS and client platform, sent to Amplitude so we can
  find broken flows. Identified by a one-way hash of your email and a hash of
  the machine, never by either value itself. Command arguments, invoice
  contents, customer records and credentials are not included. Turn it off with
  `BOOKIPI_NO_ANALYTICS=1` or the cross-tool `DO_NOT_TRACK=1`.

**What it does not do**

It does not scan your filesystem — it reads the workspace folder and whatever
file you point it at, such as a receipt image. It does not collect your
conversations with Claude, and it does not share your data with third parties
for advertising or model training.

**Retention** — business data lives in your Bookipi account and follows
Bookipi's retention policy; delete it there or ask support to delete the
account. Local credentials live only on your machine until you log out.

**Questions or a deletion request:** [support@bookipi.com](mailto:support@bookipi.com).

## License

Copyright © Bookipi. All rights reserved — see [LICENSE](LICENSE). Use of
Bookipi CLI is subject to Bookipi's
[Terms of Service](https://bookipi.com/terms-of-service/).
