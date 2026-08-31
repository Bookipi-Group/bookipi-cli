# Collections Ladder — staged overdue escalation (`bookipi invoice collections`)

Chase overdue invoices the way a good bookkeeper does: not one flat blast, but a
**staged escalation ladder** that gets firmer as an invoice ages. This is the
*collections agent* — a thin escalation layer over the invoice send rails, built
to be **safe by default** and run either on demand or from a daily scheduled check.

Every stage works by **re-sending the actual invoice** with a stage-toned
covering note. Because it re-sends the real invoice, the customer always gets the
invoice's **own** hosted pay link — and paying through that reconciles the invoice
to "paid." We deliberately do **not** mint a separate standalone payment link
(that would be detached from the invoice and wouldn't settle it).

> **`remind` vs. `collections` — pick the right one.**
> - `bookipi invoice remind` (see `invoices.md` § Bulk Reminders) = **one flat
>   reminder** to everyone in a day-window, same tone for all. Good for a quick
>   "nudge everyone 7+ days overdue."
> - `bookipi invoice collections` = **three escalating stages by age** (gentle →
>   firm → final), each with its own tone. Good for "run my collections" / "chase
>   what's overdue properly" / a recurring daily check.
>
> When the user just wants a single blast, use `remind`. When they want the
> account *worked* — escalating pressure, a repeatable cadence — use `collections`.

## The Ladder

| Stage | Age (days overdue) | Tone |
|---|---|---|
| 🌱 **Gentle nudge** | 3–13 | "friendly reminder, no rush, ignore if paid" |
| 📨 **Firm follow-up** | 14–29 | "now past due, please arrange payment this week — pay from the invoice" |
| ⚠️ **Final notice** | 30+ | "needs attention, pay from the invoice or let's arrange a plan / we pause work" |

Invoices **under 3 days overdue are skipped** — don't nag on something that
lapsed yesterday. Invoices with no due date, no email, or nothing owing are also
skipped (shown in the "Skipped" summary). The firm and final stages tell the
customer to pay directly from the invoice in the email — no extra link is created.

## Draft-and-Hold — the safety model

The command is **dry-run by default** — running it *drafts* the whole staged plan
(and shows the exact email for the first invoice in each stage) but sends
nothing. This is the "draft-and-hold": the user always sees what would go out
before a single email leaves.

The flow is **approve / edit / skip**, always confirmed with `AskUserQuestion`
(see `common.md` § Confirmation Style — never a free-text "send?" for a
destructive bulk action):

1. **Draft (AUTO, read-only).** Run the dry-run:
   ```bash
   bookipi invoice collections --json          # or without --json for the rendered plan
   ```
   Read the plan: how many in each stage, who, amounts, days overdue.

2. **Present in plain language.** Summarize the ladder to the user — *counts per
   stage*, the biggest/oldest few by name and amount. Do **not** dump handles or
   raw commands. Example: *"You've got 5 overdue: 2 firm (14–29d) and 3 final
   (30+d). The oldest is Delta at $2,000, 28 days over. Each one re-sends the
   invoice so they can pay it directly."*

3. **Confirm — approve / edit / skip (USER CONFIRM).** One `AskUserQuestion`:
   - **Question:** *"Run collections on these 5 overdue invoices? Firm + final press harder."*
   - **Choices:** `["Send all 5", "Only final notices", "Let me pick", "Not now"]`
   - **"Only final notices"** → `--stage final`. **"Let me pick"** → offer a
     multi-select of the invoices, or send by stage / by `--customer`. **"Not
     now"** → stop; optionally offer to schedule a daily check (below).
   - **Edit the wording?** The drafts are just defaults. If the user wants a
     different tone, they can't hand-edit per-invoice through the command, but you
     can send one stage at a time and, for a single customer, fall back to
     `invoice remind --customer "X" --subject … --message …` with their exact copy.

4. **Send (DESTRUCTIVE) — only when confirmed.** Add `--send`:
   ```bash
   bookipi invoice collections --send                       # whole ladder
   bookipi invoice collections --send --stage final         # just the final notices
   bookipi invoice collections --send --customer "Acme"     # one customer, all their overdue stages
   ```
   After a successful send, **log it**: one dated line in the assistant-memory
   action log — stages, count, total chased, user-approved (`docs/assistant.md`).
   On `--send`, each invoice is **re-sent** (via the invoice send rails) with the
   stage-toned subject/body as the covering note. The invoice email carries its
   own pay link, so nothing extra is minted. A failed send is surfaced per
   invoice — it's never silently dropped.

## Commands & flags

```bash
bookipi invoice collections                        # dry-run the full ladder (default, safe)
bookipi invoice collections --stage firm           # dry-run just the firm stage
bookipi invoice collections --customer "Delta"     # dry-run one customer
bookipi invoice collections --send                 # ACTUALLY send the whole ladder
bookipi invoice collections --send --stage gentle  # send only the gentle nudges
bookipi invoice collections --json                 # programmatic plan (byStage, outcomes, skipped)
```

Key flags:

- `--send` — actually email (re-sends each invoice with the stage note). Omit = dry run.
- `--stage gentle|firm|final` — act on a single rung of the ladder.
- `--customer <substring>` — match on customer name/email.
- `--exclude <numbers>` — comma-separated invoice numbers to skip (the "let me pick / skip these" case; matches `33`, `INV-33`, or `invoice-33`).
- `--cooldown-days <n>` — don't re-chase an invoice emailed within N days (default **7**, so the escalation is spaced weekly; `0` disables). Cross-device — see Idempotency below.
- `--limit <n>` — cap reminders acted on per run (default 50).
- `--json` — machine-readable output (`byStage`, per-invoice `outcomes`, `planSkipped`).

## Scheduled daily check (the recurring cadence)

Collections shines as a **daily habit**, and the 7-day cross-device cooldown
makes an unattended daily run safe — on most days everything's still within
cooldown and the check simply reports "all clear." Trigger it when the user says
*"chase my overdue invoices every morning"*, *"set up a daily collections
check"*, *"remind me to run collections daily"*, or similar.

The cadence lives in the `scheduled-tasks` MCP (there's no server-side cron in
the CLI):

```
mcp__scheduled-tasks__create_scheduled_task
```

with:

- **Title:** `"Daily collections check"` (stable + unique, so you don't create
  duplicates — before creating, `mcp__scheduled-tasks__list_scheduled_tasks` and
  reuse/update an existing one with this title rather than adding a second).
- **Schedule:** once a day, a weekday morning (respect the user's timezone if known).
- **Prompt:** re-enter this skill with the exact decision rule:

  > *"Daily collections check. Run `bookipi invoice collections --json` (dry-run).
  > Sum the `byStage` counts: if the total is **0**, report 'all clear — nothing
  > new to chase (everything overdue was contacted within the last 7 days)' and
  > stop. If it's **>0**, summarize the staged plan in plain language — counts per
  > stage 🌱/📨/⚠️ and the oldest/biggest few by name and amount — then ask me via
  > `AskUserQuestion` to approve / pick / skip before sending. Never auto-send."*

**The `byStage`-sum rule is the whole trick:** the cooldown already filters out
anything chased in the last week, so `sum(byStage) === 0` means "leave the user
alone today," and `> 0` means "there's genuinely something new to chase." That's
what stops a daily task from nagging.

> **Never auto-send from the schedule.** A scheduled collections check **drafts
> and reports**, then waits for the user's approval. Money-related emails to
> customers always cross a human. The one exception is if the user has *explicitly*
> said "just send my daily collections automatically" — capture that instruction
> in the task prompt, and even then default to gentle-only unless they widened it.

> **MCP graceful fallback.** If `scheduled-tasks` isn't wired in this build, say so
> plainly: *"This build has no scheduler, so I can't run a daily check
> automatically. Ask me 'run collections' each morning and I'll draft the ladder
> for you."* Don't promise a cadence you can't run. (Same pattern as
> `stalled-recovery.md` Phase 3.)

## Idempotency — don't double-chase

`invoice collections` has a **built-in cooldown** so a repeated or scheduled run
won't email the same customer twice. It skips any invoice emailed within
`--cooldown-days` (default **7**, so an invoice is chased at most weekly and the
gentle→firm→final escalation spaces out; `0` disables) and reports it in the
Skipped summary (*"emailed 2026-06-29 (within 7d cooldown)"*).

**The cooldown is cross-device.** It reads the invoice's own server-side `sent`
timestamp — fetched fresh from the API on every run — so it behaves identically
whether you run from your laptop, a Cowork session, or a scheduled job. There's
no local state to sync or go stale.

| Before… | Check… |
|---|---|
| Auto-sending from a scheduled check | The `--cooldown-days` guard already prevents same-day re-sends across devices via the server `sent` timestamp. Still dry-run and confirm before sending. |
| Escalating a stage | An invoice only moves up a rung as it *ages* — the stage is derived from days-overdue, so re-running the ladder tomorrow naturally re-classifies. You don't track "which stage did I last send"; the age does it. |
| Chasing a paid invoice | The plan only pulls `--status overdue`, so a paid invoice drops out automatically. If a customer paid mid-cadence, they won't be chased again. |

## What this flow does NOT do

- ❌ **Auto-send without confirmation.** Dry-run is the default; a real send always
  crosses a human (the one exception is an explicit standing "auto-send" instruction).
- ❌ **Mint a standalone pay link.** It re-sends the invoice, which already carries
  its own reconciling pay link. A separate link would be detached from the invoice
  and wouldn't mark it paid — so we don't create one.
- ❌ **Chase invoices under 3 days overdue.** Too fresh — leave them.
- ❌ **Send marketing.** Every email is a 1:1 transactional collections notice.
- ❌ **Track stage state server-side.** The stage is computed from days-overdue on
  each run — there's no per-invoice "cadence step" record. Age *is* the state.

## Cross-references

- One flat reminder blast (not staged) → `invoices.md` § Bulk Reminders (`invoice remind`)
- How the invoice send carries its own pay link → `invoices.md` (invoice send)
- Chasing stalled *proposals* (not invoices) → `stalled-recovery.md`
- Batch confirmation + `AskUserQuestion` format → `common.md` § Confirmation Style
- Passive surfacing of what's overdue (read-only) → `morning-brief.md`
