# Bookipi CLI

[![release](https://img.shields.io/github/v/release/Bookipi-Group/bookipi-cli?label=release)](https://github.com/Bookipi-Group/bookipi-cli/releases/latest)
[![release status](https://github.com/Bookipi-Group/bookipi-cli/actions/workflows/release.yml/badge.svg?event=release)](https://github.com/Bookipi-Group/bookipi-cli/actions/workflows/release.yml)

Run your back office — invoices, payments, customers, expenses, proposals,
contracts and reports — by asking Claude in plain English, or from your own
code with `--json` commands.

Anything that emails someone, records a payment or publishes waits for your
OK first, and Bookipi never moves money. Overview: [bookipi.com/cli](https://bookipi.com/cli/).

**Contents**

1. [Ways to use it](#ways-to-use-it)
2. [Install the skill](#install-the-skill)
   — [Claude Desktop & Cowork](#claude-desktop--cowork) ·
   [Claude Code](#claude-code) · [Codex](#codex) ·
   [Gemini CLI](#gemini-cli) · [Other agents](#other-agents)
3. [Allow network access (Cowork)](#allow-network-access-cowork)
4. [Sign in and workspaces](#sign-in-and-workspaces)
5. [Things to ask](#things-to-ask)
6. [Build on the CLI](#build-on-the-cli) — [Commands](#commands)
7. [Help and bug reports](#help-and-bug-reports)
8. [Privacy](#privacy)
9. [License](#license)

## Ways to use it

| You want to… | Use |
| --- | --- |
| Ask Claude (Cowork, Claude Desktop, Claude Code, Codex, Gemini CLI) | [The skill](#install-the-skill) — it includes the CLI |
| Use Bookipi in claude.ai or any MCP client, nothing to install | [The Bookipi connector](docs/connector.md) |
| Script it, or build it into your own agents and products | [The CLI](#build-on-the-cli) |

It's the same tool underneath every option.

## Install the skill

The skill includes the Bookipi CLI, so there's nothing else to install. When it
runs on your own computer (Claude Code, Codex, Gemini CLI), it needs Node
22.12+, and on first use it adds a `bookipi` command to `~/.local/bin` so you
can run it yourself too.

### Claude Desktop & Cowork

1. Download `bookipi-cli.skill` from the
   [latest release](https://github.com/Bookipi-Group/bookipi-cli/releases/latest).
2. Double-click it and confirm. It appears in your Skills list as `bookipi-cli`.

Nothing happens? Drag the file into the Cowork window. If your browser dropped
the `.skill` extension, rename it back first.

### Claude Code

```
/plugin marketplace add Bookipi-Group/bookipi-cli
/plugin install bookipi@bookipi-cli
```

To upgrade, refresh the marketplace **first**, then update (keep the
`@bookipi-cli` part, or you get "Plugin not found"):

```
/plugin marketplace update bookipi-cli
/plugin update bookipi@bookipi-cli
```

A skill installed in Claude Desktop also works in Claude Code sessions started
from the desktop app. To install by hand, unzip the `.skill` file into
`~/.claude/skills/`.

### Codex

```
/plugin marketplace add Bookipi-Group/bookipi-cli
/plugin install bookipi
```

### Gemini CLI

```
gemini extensions install https://github.com/Bookipi-Group/bookipi-cli
```

Upgrade with `gemini extensions update bookipi`. The extension also includes
the [Bookipi connector](docs/connector.md): run `/mcp auth bookipi` once to
sign in, and the skill uses it instead of the CLI.

### Other agents

Cursor, GitHub Copilot, Antigravity and Windsurf read skills from
`.agents/skills/`. Copy `.agents/skills/bookipi-cli/` into your project's or
agent's skills folder.

## Allow network access (Cowork)

**Skip this** on Claude Code, or if your workspace admin has already added the
domains below.

Cowork runs in a sandbox that blocks unknown websites, so Bookipi must be on
your organization's allowlist or sign-in fails. An admin adds these under
**Organization Settings → Capabilities → Code execution → Additional allowed
domains**:

```
*.bkpi.co
*.bookipi.com
*.bookipay.com
*.s3.amazonaws.com
*.amplitude.com
```

The first three are Bookipi's servers; S3 is for receipt uploads and images in
invoice previews. If one is missing, Claude says so on the first request and
lists these domains — forward that to your admin.

## Sign in and workspaces

Each Bookipi workspace is a folder on your computer. Your sign-in is saved in
that folder's `.bookipi/` (git-ignored), so every session in it stays signed in.

1. **Cowork:** New Project → **Use a folder** → pick a folder.
   **Claude Code:** start `claude` in any folder.
2. Ask: *"Set up Bookipi in this folder."* Claude gives you a sign-in link.
3. Check with: *"Who am I logged in as?"*

For another Bookipi account, use another folder.

> **Cowork projects without a folder** are cloud-only and wiped between chats,
> so you'd sign in every time. Attach a folder, or use the
> [Bookipi connector](docs/connector.md), which keeps the sign-in on your
> Claude account.

On Claude Code the folder is optional: just say *"log me in to Bookipi"* and
the sign-in is saved to `~/.bookipi/`, for every folder on your machine.

## Things to ask

| | Try |
| --- | --- |
| **Money owed** | "Who owes me money?" · "Show my overdue invoices." · "Send reminders to all my overdue invoices." |
| **Invoices** | "Create an invoice for Acme — $5,000 for consulting." · "Show me what INV-650 looks like." · "Send INV-650 to alice@acme.com." · "Mark INV-650 as paid." |
| **Customers** | "Pull up Wayne Construction." · "Add a new customer: Acme Corp, billing@acme.com." · "Email Maria — I'll be late to the call." |
| **Deals & proposals** | "Add a deal — Stark kitchen renovation, $40,000." · "Draft a proposal for the Stark deal." · "Mark the Stark deal as won." |
| **Contracts** | "Turn that accepted proposal into a contract." · "Send the MSA to Bruce." · "Has Bruce signed yet?" |
| **Expenses** | Drop in a receipt: "Log this as an expense." · "Show my expenses this month." |
| **Reports** | "Give me the morning brief." · "Who's my biggest customer this quarter?" · "Build me a dashboard for last quarter." |
| **Calendar** | "What's on my calendar today?" · "Find my meetings with Maria this week." |
| **Account** | "What companies do I have?" · "Switch to my other Bookipi account." · "Log me out." |

## Build on the CLI

A JSON-first command-line tool for scripts, automations and your own agents.
Node 22.12+, no build step.

**Install** (macOS/Linux): run the one-line installer from the
[latest release page](https://github.com/Bookipi-Group/bookipi-cli/releases/latest).
It verifies the download, installs to `~/.local/share/bookipi-cli` and adds
`bookipi` to `~/.local/bin`. It never installs Node or edits your shell
profile. Run it again to update.

Or run it from a clone — the production build is at
`skills/bookipi-cli/bin/bookipi.js`:

```
git clone https://github.com/Bookipi-Group/bookipi-cli.git ~/bookipi-cli
alias bookipi=~/bookipi-cli/skills/bookipi-cli/bin/bookipi.js
```

**Use:**

```
bookipi init                                   # create a workspace and sign in
bookipi invoice list --status overdue --json   # structured output
```

For CI or headless use, set `BOOKIPI_TOKEN` instead of signing in. Ready-made
scripts (chase overdue invoices, weekly digest to Slack, receipts folder to
expenses) are in [`examples/`](examples/).

### Commands

Every command accepts `--json`; `bookipi <group> --help` lists the flags.

| Group | Covers | Subcommands |
| --- | --- | --- |
| `invoice` | Invoices and related documents | `list` `get` `preview` `create` `create-from-proposal` `duplicate` `update` `delete` `send` `send-receipt` `mark-paid` `void` `remind` `collections` `attach-photo` |
| `customer` | Customers, payments, email | `list` `get` `payments` `create` `update` `delete` `send-email` `emails` |
| `item` | Products and services | `list` `create` `set-photo` |
| `expense` | Expenses and receipt scanning | `categories` `list` `upload` `scan` `create` `delete` |
| `paylink` | BPay payment links | `create` `list` `get` `status` `send` |
| `deal` | Pipeline deals | `list` `create` `update` |
| `proposal` | AI-written proposals | `list` `generate` `update` `duplicate` `send` `delete` |
| `contract` | eSign contracts | `list` `draft` `upload` `create-from-proposal` `finalize` `send` |
| `report` | Reports, dashboards, insights | `summary` `customers` `items` `dashboard` `insights` `digest` `suggest` `open` |
| `meeting` | Recorded meetings and bookings | `list` |
| `calendar` | Calendar connection | `status` |
| `company` | The active company | `list` `set` |
| `website` | The AI-built company website | `status` `content` `pages` `page` `create` `generate` `add-page` `update` `ask` `preview` `publish` `analytics` `open` |
| — | Session and workspace | `setup` `login` `logout` `whoami` `init` `mcp` |

`bookipi setup` is the first call for an agent: it checks the sign-in, starts
one if needed, and returns the next step as JSON.

Commands that email someone, record or clear a payment, create or send a
payment link, or publish the website refuse to run without `--yes`. In chat,
Claude asks you first; in a script, pass `--yes` yourself.

## Help and bug reports

Open a [GitHub issue](https://github.com/Bookipi-Group/bookipi-cli/issues) with
what you asked, what Claude did, and what you expected.

**Security issues:** please report privately — see [SECURITY.md](SECURITY.md).

## Privacy

Bookipi CLI works with your own Bookipi account. Full policy:
[bookipi.com/privacy-policy](https://bookipi.com/privacy-policy/).

- **Business data** (invoices, customers, expenses, deals, proposals,
  contracts, meetings, website) is read from and written to your Bookipi
  account over HTTPS — nowhere else.
- **Sign-in tokens** stay on your machine, in the workspace's `.bookipi/` or
  `~/.bookipi/`, readable only by you. They go only to Bookipi's sign-in
  service; `bookipi logout` deletes them.
- **Receipt and logo images** are uploaded to Bookipi's S3 storage for scanning
  and invoice previews.
- **Usage analytics** go to Amplitude: which command ran, how long it took,
  whether it failed, and the CLI version, OS and client. You're identified by a
  one-way hash of your email or machine — never arguments, invoice contents,
  customer records or credentials. Turn off with `BOOKIPI_NO_ANALYTICS=1` or
  `DO_NOT_TRACK=1`.
- **Update check:** once a day the CLI asks GitHub for the latest release,
  sending only its version. Turn off with `BOOKIPI_NO_UPDATE_CHECK=1`.

It doesn't scan your files (only the workspace folder and files you point it
at), doesn't collect your conversations with Claude, and doesn't share data for
advertising or model training. Business data follows Bookipi's retention
policy; local sign-ins last until you log out.

Questions or deletion requests: [support@bookipi.com](mailto:support@bookipi.com).

## License

Copyright © Bookipi. All rights reserved — see [LICENSE](LICENSE). Use is
subject to Bookipi's [Terms of Service](https://bookipi.com/terms-of-service/).
