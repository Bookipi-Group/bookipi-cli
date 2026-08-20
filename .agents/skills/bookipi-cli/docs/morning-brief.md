# Daily Morning Brief

The one morning pass: it REPORTS what matters today, then PREPARES the day's
actions as drafts behind a single approval ask. Nothing sends, charges, or
moves without that day's explicit yes — which is what makes it safe to run
unattended on a schedule ("the AI employee").

The report covers four sections:

1. **Today's meetings** — calendar context, with a card per meeting
2. **Pipeline highlights** — open deals worth attention (close to closing, stalled, awaiting action)
3. **Money** — overdue / partially-paid invoices **and unpaid payment links** to chase
4. **Awaiting action** — contracts pending signature, proposals sent but not viewed

…followed by the **Prepared actions** stage (see below): drafted overdue
chasers, stalled-deal nudges, and — only when a bank statement has been
provided — a reconciliation match table, bundled into ONE `AskUserQuestion`.

Each section appears only if it has content. If everything is empty, you can honestly say "Nothing pressing today" in one line.

This same flow doubles as the **unified status sweep** — the "check everything in
one go" pass across paid/unpaid invoices, unpaid payment links, proposals awaiting a
response, and contracts pending signature. It's what you schedule when the user wants
**one daily check of everything** instead of N per-item checks — see
[Scheduling](#scheduling--one-unified-sweep-vs-per-item-checks).

> ## ⚠️ Critical rule: per-meeting context needs FOUR queries, not one
>
> For each meeting's customer, you **MUST** run all four of these in parallel:
>
> - `bookipi deal list --search "<name>" --json`
> - `bookipi proposal list --search "<name>" --json`
> - `bookipi invoice list --json` (filter locally by customer)
> - `bookipi contract list --status pending_signature,draft --limit 50 --json` (filter locally by recipient)
>
> **Do NOT rely on `deal.proposals[]` or `deal.invoices[]` alone.** Those inline arrays only contain artifacts formally attached to that specific deal record. A customer can have proposals/invoices that exist independently. If you skip the separate `proposal list` query, you will incorrectly tell the user "no proposal sent yet" when they actually just sent one — this has happened before and embarrassed the user.
>
> See [Why all four per-customer queries are needed](#why-all-four-per-customer-queries-are-needed) for the full rationale.

## When to Trigger This Flow

Strong signals:

- "What's on today?" / "What's on my calendar?"
- "Morning brief" / "Daily brief"
- "What should I focus on?"
- "Get me ready" / "Pre-brief me"
- "Run my day" / "Do your morning rounds" / "What did I miss?"
- "Set up my AI employee" / "handle my mornings" — the SCHEDULED version (see Scheduling)
- **"Status sweep" / "check everything" / "what's outstanding / unpaid everywhere?"** — the same flow, run as the unified status sweep (invoices, payment links, proposals, contracts)
- "Check all my payment statuses" / "anything paid / signed / accepted?"
- "Any meetings today?" (still triggers — meetings are one section)
- Morning greeting on a workday with no other intent ("morning!", "let's get started")

**Skip this flow if** the user is asking about a *specific* deal/customer/invoice. Those are direct lookups, not morning briefs.

## Calendar pre-check

Before fetching meetings, run `bookipi calendar status --json` once. If
`isGoogleCalendarConnected === false`, replace the entire "Today's meetings"
section with a single line pointing to the `setupUrl`:

> **Today's meetings:** Google Calendar isn't connected yet — [connect it here](`setupUrl`) to enable meeting data.

Skip `bookipi meeting list` and all per-customer meeting queries for this brief.

## The Minimum Happy Path

Run these in parallel — they don't depend on each other:

```bash
# Today's meetings (the calendar input)
bookipi meeting list --json

# Open deals at decision stages (proposal/contract are "hot")
bookipi deal list --status proposal --limit 50 --json
bookipi deal list --status contract --limit 50 --json

# Money to chase
bookipi invoice list --status overdue,partialPaid --json

# Active payment links (then `paylink status <id>` on active ones to see which are still unpaid)
bookipi paylink list --json

# Contracts awaiting action
bookipi contract list --status pending_signature,draft --limit 50 --json
```

That's 6 parallel calls, ~1 second total. For each meeting, also issue these per-customer queries in parallel — **all four are needed** because each surface is independent (see [Why all four queries are needed](#why-all-four-per-customer-queries-are-needed)):

```bash
bookipi deal list --search "<customer name>" --json
bookipi proposal list --search "<customer name>" --json
bookipi invoice list --json   # then filter locally by customer
bookipi contract list --status pending_signature,draft --limit 50 --json   # filter by recipient
```

## Output Format

Use plain markdown headers per section. Keep each line scannable — short noun phrases, one fact per bullet, no paragraphs. If a section is empty, **omit it entirely** rather than printing "(none)".

Example for a typical morning:

```markdown
## Morning brief — Thursday May 1

### Today's meetings
**10:00 — Onboarding kickoff with Acme Corp (45m)**
Counterpart: Maria Chen (CEO) · maria@acme.com
- Open deals: Acme website redesign (Proposal stage, $12,000)
- Recent: Proposal sent 6d ago, not yet viewed
- Worth raising: the MSA is still pending signature with Maria

**14:00 — Discovery call with Beta LLC (30m)**
Counterpart: Sam Patel · sam@beta.io
- First contact — no prior deals or invoices in CRM

### Pipeline highlights
- 3 proposals sent more than 5 days ago without acceptance:
  - Acme website redesign — sent 6d, not viewed
  - Delta retainer — sent 8d, viewed but no response
  - Echo SOW — sent 11d, not viewed
- 1 contract close to closing: Foxtrot MSA in Contract stage

### Money
- 4 invoices overdue, $34,877 outstanding total
- Top 3: INV-203 ($12,000, 14d overdue), INV-198 ($8,500, 6d), INV-176 ($5,000, 33d)

### Awaiting action
- 2 contracts pending signature:
  - Acme MSA — with Maria Chen, sent 4d ago
  - Foxtrot MSA — with Jordan Lee, sent 2d ago
```

If there are zero meetings, just drop that section. Same for any other empty section.

If the user has no meetings, no overdue invoices, no stalled proposals, no pending contracts: **say so honestly** in one line. Don't pad.

## Section-by-Section Guidance

### 1. Today's meetings

For each meeting (chronological, earliest first):

- **Lead with time + counterpart.** That's what the user is about to see on their calendar.
- **Match the meeting's customer to the CRM** by email first, then name (see Customer Matching below).
- **Per-customer context:** open deals (with stage and value), recent proposal/contract activity, anything that's worth raising in the meeting.
- **Suggestions are honest observations**, not invented advice. Only suggest something if you have data to back it up: an overdue invoice, a stalled proposal, a pending contract. Don't fabricate icebreakers.

If the customer isn't in the CRM at all, say "First contact — no prior deals or invoices in CRM" and move on.

### 2. Pipeline highlights

Show deals that need attention. Keep it brief — count + names, not a full deal dump.

What counts as "attention":

- **Proposal-stage deal with linked proposal `sent` for 5+ days** without becoming `read` / `accepted` / `declined`. The deal-list response includes the linked proposal's status — filter client-side.
- **Contract-stage deal with linked contract still `pending_signature` for 5+ days.** Same filtering pattern.
- **Hot deals at the cusp of closing** — anything in `contract` stage at all, briefly listed.

Skip anything that's just "sitting there normally" — recently-sent proposals, fresh leads, etc. Highlight friction or imminence.

If nothing qualifies, **drop the entire section.** Don't print "No pipeline highlights" — that's noise.

### 3. Money

Pull `invoice list --status overdue,partialPaid --json`. Summarize:

- Total count + outstanding total amount.
- Top 3 by amount with days overdue, customer, invoice number.

Don't list every overdue invoice if there are 20 — top 3 plus the total tells the same story.

**Unpaid payment links.** Also pull `paylink list --json`. For the **active** links
(cap ~10), run `paylink status <id>` to find ones still **awaiting payment**; surface
those (title, amount, age). Skip links already paid. If a link has partial/failed
attempts, note it. Keep it to a short list — this is "what's still owed", not a ledger.

### 4. Awaiting action

Pull `contract list --status pending_signature,draft --limit 50 --json`. Show contracts that aren't moving:

- Title, recipient (from `recipients[0].fullName` or email), days since `sentDate`.
- Cap at 5; note "(+N more)" if truncating.

You can also include "proposals sent but not viewed" here, but that's likely already covered by section 2 — don't double-list. Pick the one section it fits best.

## Prepared Actions — the stage after the report

After presenting the report, prepare (never execute) the day's actions and end
with ONE bundled ask. All preparation is dry-run/read-only, so this stage is
free — skip an item only when its trigger is absent.

1. **Overdue chasers** — `bookipi invoice collections` (dry-run default; the
   7-day server-side cooldown means most days report "all within cooldown").
   See `docs/collections.md`.
2. **Stalled-deal nudges** — per `docs/stalled-recovery.md`, when pipeline
   highlights surfaced stalled proposals.
3. **Reconciliation** — ONLY if the user provided a bank statement (dropped in
   chat or a pointed-at folder): draft the match table per `docs/reconcile.md`.
   No statement → skip silently; never ask for one.
4. **Hot signals** — from data already fetched: unpaid invoices with status
   `read` ("Tony viewed invoice-56 yesterday — good moment for a nudge") go in
   a "Worth knowing" line, optionally with a drafted nudge in the bundle.

Then ONE `AskUserQuestion` bundling everything that needs a yes — e.g.
*"Approve today's actions? (send 3 reminders · re-engage 1 stalled proposal)"*
with options like "Approve all" / "Reminders only" / "Show me the drafts" /
"Skip today". On approval, execute via each flow's own commands, confirm in
one line each, and **log each executed action** in the assistant-memory
action log (`docs/assistant.md`). **A standing yes never carries over — each day's run gets its
own gate.** If everything is within cooldown and nothing needs approval, say
so in one line instead of asking an empty question.

## Customer Matching Strategy

> **⚠️ Meeting data-model gotcha:**
>
> In a meeting record, the **top-level `email`** is the **counterpart** (the prospect / customer you booked with). The nested `meeting.customer` object is actually the **booking-link owner** — i.e. *you*, the Bookipi user — not the counterpart. Don't match against `meeting.customer.email`; you'll match yourself.

Match the meeting's counterpart to a CRM customer in this order:

1. **By `meeting.email` (top-level) → CRM `customer.email`**. Most reliable.
2. **By name** as fallback — but only if you can resolve the counterpart's name from the CRM (the meeting record itself doesn't store the counterpart's name).
3. **No match** — treat as a first-touch meeting. The briefing notes "First contact — no prior deals or invoices in CRM."

When you call `deal list --search "<name>"`, the API returns matching deals across all stages. Filter the results by the counterpart's email/name yourself if there are multiple matches.

## Why all four per-customer queries are needed

`deal list` *does* return linked invoices and proposals inline (the deal record includes `invoices[]` and `proposals[]`) — but **only proposals/invoices that have been formally attached to that specific deal**. Records can exist for a customer without being tied to any deal yet:

- A user may create a proposal for "Acme Corp" before creating a deal for them, or never link the two.
- An invoice from before the deal-tracking feature won't be in any `deal.invoices[]`.
- Contracts live in a separate service (signit) and are never inline on the deal.

If you only inspect `deal.proposals[]`, you'll miss proposals that exist in the customer's CRM but haven't been attached. The morning brief said "no proposal document sent" while the user had just created one — that bug came from this exact gap.

**The fix:** for each meeting customer, query all four surfaces independently and merge:

| Surface | Query | What it adds |
|---|---|---|
| Deals | `deal list --search "<name>"` | Pipeline position, deal value |
| Proposals | `proposal list --search "<name>"` | All proposals for the customer, attached or not |
| Invoices | `invoice list --json` (filter locally) | Outstanding amounts, history |
| Contracts | `contract list ... --json` (filter recipients) | Signature status |

When merging, dedupe proposals: any `_id` already present in a `deal.proposals[]` should be marked as "attached to deal X"; the rest are loose proposals worth surfacing too.

The standalone calls in the briefing's other sections (Money, Awaiting action) cover the global account view — these per-customer calls cover the meeting-customer-specific view.

## Parallelisation

For N meetings, run the per-meeting context queries in parallel. Three queries × N meetings done sequentially is slow.

A typical morning has 1–4 meetings. The base 5 parallel calls + 4 per-meeting calls × N meetings (deal/proposal/invoice/contract — see [Why all four](#why-all-four-per-customer-queries-are-needed)) = ~21 calls in parallel for 4 meetings = still ~1 second total when issued in a single batch.

Use the agent's parallel tool-call capability — issue all the `list --json` calls in a single batch.

## Edge Cases

| Situation | Handling |
|---|---|
| All four sections empty | "Nothing pressing today." Single line, done. |
| Meeting with no email and no customer object | Show only the meeting time + title. Note: "Counterpart info missing." |
| Customer not found in CRM | "First contact — no prior deals or invoices in CRM." Don't error. |
| Multiple customers match the name | Pick the one whose email matches the meeting email. If still ambiguous, list both deals briefly and note the match is uncertain. |
| Deal list returns 50+ deals (very active customer) | Show only the top 3 by stage importance (`contract` > `proposal` > `meeting` > `qualified` > `leads`). Note "(+N more)" if truncating. |
| Customer is internal (e.g. an `@bookipi.com` email) | Show as a "team meeting" — skip CRM context, just show meeting title and attendees. |
| Hundreds of overdue invoices | Top 3 by amount, plus total count and total $. Don't list all of them. |
| User asks "what's on today?" at 5pm | Same flow, but skip the meetings section if all today's meetings are already past. Reframe as "rest of today + state of pipeline." |

## Presentation Rules (from the main skill)

These are non-negotiable — see `SKILL.md` for the full list:

- **Never show handles** (`@i1`, `@c1`, `@d1`, etc.) in the briefing.
- **Never show raw CLI commands.**
- **Refer to invoices by number** (e.g., INV-203), customers by name, deals by their name field, contracts by their title field.
- Include amounts in the user's currency (the CLI formats them automatically — pass through whatever it printed).

## Scheduling — one unified sweep vs per-item checks

When the user checks (or asks to schedule a check of) a **single** item's status —
one invoice, one payment link, one proposal, one contract — and you'd offer to
schedule it, **also offer the unified alternative** via `AskUserQuestion`:

- **"Just this one"** — schedule a check of that single item.
- **"Everything, once a day"** — schedule **one** task that runs this whole sweep:
  overdue / partially-paid invoices, unpaid payment links, proposals awaiting a
  response, and contracts pending signature.

One scheduled task covering everything beats N per-item tasks — recommend it when the
user has more than one thing they'd otherwise track separately. To create it, use the
schedule skill (a cron routine) with a prompt such as:

> *"Run my Bookipi morning brief: report meetings, pipeline, money, and awaiting-action,
> then prepare the day's drafts (overdue chasers, stalled-deal nudges) and ask me for
> one approval. Never send anything without that day's yes."*

This scheduled brief IS the "AI employee" setup — one task, one card, one ask. If the
user already has separate scheduled checks (daily collections, stalled-deal check,
per-item status checks), offer to consolidate them into this single brief so they get
one card instead of three. The run is safe unattended because it only ever *drafts*:
sending stays behind the day's explicit approval (see
[What This Flow Does NOT Do](#what-this-flow-does-not-do)).

## Cadence (When to Run Without Being Asked)

If the user opens Cowork in the morning (before noon, local time) and hasn't asked for anything else yet, *consider* offering a morning brief — using `AskUserQuestion` per `common.md` § Confirmation Style, not free-text:

- **Question:** *"Morning! Want a quick rundown? You have 3 meetings, 2 stalled proposals, and $35K in overdue invoices."*
- **Choices:** `["Walk me through it", "Just the meetings", "Just the money", "Skip it"]`

The headline numbers in the question earn the click. The choices let the user dial in just the part they care about, instead of getting the full brief every time. Don't push it more than once a day. If the user said "Skip it" or just started another task, drop it.

After the brief itself, if any actionable items surfaced (overdue invoices to chase, accepted proposals to convert), end with another `AskUserQuestion` offering the top 2-3 next actions — never end with a free-text "what would you like to do?".

For autonomous morning briefs (e.g., delivered as an email digest), see the `Prompting & Cadence` discussion in `agent-flows.md` at the repo root — channel selection (push vs digest) is a system-level concern, not a skill concern.

## What This Flow Does NOT Do

- ❌ **Send anything without the day's explicit approval** — the brief DRAFTS
  reminders and nudges (Prepared Actions stage) but every send sits behind that
  run's own `AskUserQuestion`. A scheduled run with no one answering sends
  nothing.
- ❌ **Move deals between stages** — the user does that themselves.
- ❌ **Generate a proposal or contract** — that's Flow 1 (Win Deal), not this.
- ❌ **Book new meetings** — surface what exists; user creates new ones manually.
- ❌ **Mark invoices paid on its own** — reconciliation matches are drafted only
  when a statement was provided, and recording stays behind the same gate.

If the user asks for something beyond the brief's scope, that's a separate request — switch flows.
