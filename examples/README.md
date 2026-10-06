# Bookipi CLI examples

Ready-to-run scripts on top of `bookipi --json`, and prompts for running whole
workflows through Claude. Copy them, change them, wire them into your own
tools.

| File | What it does | Changes anything? |
| --- | --- | --- |
| [`chase-overdue.sh`](chase-overdue.sh) | Lists overdue invoices, asks, then emails a reminder for each | Sends emails, after you confirm |
| [`weekly-digest.sh`](weekly-digest.sh) | Invoiced, collected, overdue and quiet deals as Markdown; posts to Slack if `SLACK_WEBHOOK_URL` is set | No, read-only |
| [`receipts-to-expenses.sh`](receipts-to-expenses.sh) | Reads a folder of receipt photos and PDFs and creates an expense for each | Only with `--save` |
| [`prompts.md`](prompts.md) | Messages to paste into Claude: collections, proposals → eSign → invoice, reports, receipts | Claude asks first |

## Before you run them

1. **Get the CLI.** If you use Claude Code, Codex or Gemini CLI, follow the
   [install steps](../README.md). To run the scripts from a plain terminal, use
   the CLI that ships in this repository:

   ```bash
   git clone https://github.com/Bookipi-Group/bookipi-cli.git ~/bookipi-cli
   export BOOKIPI=~/bookipi-cli/skills/bookipi-cli/bin/bookipi.js
   ```

   The scripts call `$BOOKIPI`, or `bookipi` if that isn't set. You need Node
   22.12 or newer.

2. **Install [jq](https://jqlang.org/download/)**, which the scripts use to read
   the JSON.

3. **Sign in once:**

   ```bash
   $BOOKIPI login
   ```

## Examples

```bash
./weekly-digest.sh                        # this week, printed
./weekly-digest.sh month                  # today | yesterday | week | month
./chase-overdue.sh --min-days 30          # preview, then confirm
./receipts-to-expenses.sh ~/Receipts      # preview what the OCR read
./receipts-to-expenses.sh ~/Receipts --save
```

`chase-overdue.sh --yes` skips the prompt, for a scheduled run. Use it once
you've seen what it sends.

## Writing your own

Every command in the scripts takes `--json`. Run `bookipi <group> --help` to see
a group's commands and flags. [README § Building on the CLI](../README.md#building-on-the-cli)
has the full command table.

Unlike the skill, the CLI doesn't ask before it acts. A command that sends or
records something runs as soon as you call it. That's why these scripts preview
first.
