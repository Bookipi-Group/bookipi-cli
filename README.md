# Bookipi CLI

[![release](https://img.shields.io/github/v/release/Bookipi-Group/bookipi-agent-cli-release?label=release)](https://github.com/Bookipi-Group/bookipi-agent-cli-release/releases/latest)
[![release status](https://github.com/Bookipi-Group/bookipi-agent-cli-release/actions/workflows/release.yml/badge.svg?event=release)](https://github.com/Bookipi-Group/bookipi-agent-cli-release/actions/workflows/release.yml)

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
   [Releases](https://github.com/Bookipi-Group/bookipi-agent-cli-release/releases).
2. Double-click it. Cowork or Claude Desktop will prompt to install.
3. Confirm. It now appears in your Skills list as `bookipi-cli`.

If double-click does nothing, drag the file into the Cowork window. If your
browser stripped the `.skill` extension on download, rename it back.

**Claude Code (terminal):** a skill installed via Claude Desktop is also
available in Claude Code sessions started from the desktop app. For standalone
terminal use, unzip the `.skill` file into `~/.claude/skills/` (it's a zip —
you'll end up with `~/.claude/skills/bookipi-cli/`). Claude Code runs the CLI
on your own machine, so you'll also need Node 22.12 or newer installed.

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

Claude opens a browser for staging login, then saves your credentials
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

```
git clone https://github.com/Bookipi-Group/bookipi-agent-cli-release
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

A small, predictable, `--json`-first surface your code can call reliably.

## Found a bug? Stuck?

Open an issue on
[GitHub](https://github.com/Bookipi-Group/bookipi-agent-cli-release/issues) with:

- What you typed
- What Claude did
- What you expected

The more detail, the faster we can help.

**Security issues:** please don't open a public issue — see
[SECURITY.md](SECURITY.md) for how to report privately.

## License

Copyright © Bookipi. All rights reserved. See [LICENSE](LICENSE).
