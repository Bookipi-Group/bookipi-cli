# Customer 360 — Everything on a Single Customer

A read-only flow that surfaces everything about one customer in a single view. Use when the user asks for *one specific customer's* full picture — not a daily brief, not a pipeline scan, just "show me everything on this person/company."

## When to Trigger This Flow

Strong signals (always ask about a *specific named entity*):

- "Tell me about Maria Chen" / "Tell me about Acme Corp"
- "How's Acme doing?"
- "What's the status with Beta?"
- "Customer 360 on Maria"
- "Show me everything on Foxtrot"
- "What do I have with Gamma Inc?"
- "Recap on the Acme account"
- Any name-anchored question that's broader than a single artifact

**Skip this flow** when the user asks about a *specific artifact* (an invoice, a deal, a contract). Those are direct lookups — go straight to the relevant `<resource> list --search` or use the existing handle.

**Also skip** for the morning brief — that's `morning-brief.md`. This flow is for ad-hoc requests about one customer.

## The Minimum Happy Path

Same per-customer block as the morning brief uses, in parallel:

```bash
bookipi customer list --search "<name>" --json
bookipi deal list --search "<name>" --json
bookipi proposal list --search "<name>" --json
bookipi invoice list --json   # filter locally by customer ID or name
bookipi contract list --status pending_signature,draft,signed --limit 100 --json   # filter locally by recipients[].email
```

Five parallel calls, ~1 second total. The same "all four surfaces are independent" rule applies — `deal.proposals[]` and `deal.invoices[]` are subsets, not the full picture. **Always run `proposal list --search` and `invoice list` separately** — see [morning-brief.md § Why all four per-customer queries are needed](./morning-brief.md#why-all-four-per-customer-queries-are-needed).

## Output Format

Organize by *what the user actually wants to know*:

```markdown
# Acme Corp — Customer 360

**Contact:** Maria Chen (CEO) · maria@acme.example · +63 …
**Job:** Website redesign engagement · ongoing since 2026-02

## Pipeline (2 deals)
- **Acme website redesign** — Proposal stage, ₱100,000 (proposal #169 sent 6 days ago, not yet viewed)
- **Acme retainer** — Qualified, no value set yet

## Proposals (2)
- #169 "Website redesign" — sent 6 days ago, ₱100,000, expires June 1
- #168 "Discovery scope" — accepted Feb 14, ₱20,000, converted to invoice INV-201

## Contracts (2)
- "Master Services Agreement" — pending signature with Maria, sent 4 days ago
- "Casual employment information statement" — draft (never sent), 3 days old

## Money
- 1 paid invoice: INV-201 (₱20,000, paid Feb 28)
- No outstanding amounts

## Recent activity (last 30 days)
- Sent proposal #169 — 6d ago
- Sent contract MSA — 4d ago
- Last meeting: Discovery call, Feb 12

## Worth raising
- Proposal #169 not yet viewed after 6 days — worth a nudge
- MSA pending signature for 4 days
```

Rules:

1. **Lead with who they are**, not what's open. Contact + relationship summary in one or two lines.
2. **Pipeline first**, since deals are the orchestration anchor.
3. **One section per surface** (proposals, contracts, invoices) — but only if there's content. Skip empty sections.
4. **Recent activity** — a short timeline of the last ~30 days, only if useful. Drop if nothing happened.
5. **Worth raising** — honest observations, not invented advice. Same rule as morning brief: only if you have data to back it up.
6. Show signed/closed items briefly in the relevant section so the user has historical context, but don't dwell on them.

## Disambiguation

If `customer list --search "<name>"` returns multiple matches, **ask before proceeding**:

> "I see three Marias on file:
> - Maria Chen at Acme Corp (4 deals, ₱120K total)
> - Maria Lopez (1 deal, qualified)
> - Maria Patel at Beta LLC (closed_lose only)
>
> Which one?"

**Use `AskUserQuestion`** for this prompt — see `common.md` § Confirmation Style. Choices like `["Maria Chen (Acme)", "Maria Lopez", "Maria Patel (Beta)", "None of these"]`. Don't print a bullet list and wait for free-text. Pick the right one based on signal (number of recent deals, total value, last activity); if the user already gave a hint ("Maria from Acme"), match on that and skip the question.

If no match at all, also use `AskUserQuestion`:

- **Question:** *"No customer named 'X' on file. How do you want to find them?"*
- **Choices:** `["Search by email", "Search by partial name", "Create them as a new customer", "Cancel"]`

## Mixed-Age and Multi-Record Customers — Priority Rules

When a customer has many records spanning a long time (active + historical), **don't dump everything chronologically**. The view should answer "what's true *right now*?" first and "what's the relationship history?" second. Apply these rules per section:

### Pipeline (deals)

| Bucket | Treatment |
|---|---|
| **Active stages** (`leads`, `qualified`, `meeting`, `proposal`, `contract`) | Show every one in full — name, stage, value, age. These need attention. |
| **Closed Win** | Summarize: *"Closed-won 3 deals in 2025 (₱180K total)."* Mention by name only if recent (last 90 days) or a top-3 deal by value. |
| **Closed Lose** | One-line summary: *"Closed-lost 2 deals (last in Q1 2025, reason: price)."* Skip if old enough that listing them adds nothing. |

### Proposals

| Bucket | Treatment |
|---|---|
| **Active** (`draft`, `saved`, `sent`, `read`) | Show in full with status, value, age. |
| **Recently accepted** (last 90 days) | Show as historical context: *"Accepted #168 in Feb 2026, ₱20K — converted to INV-201."* |
| **Old accepted / declined / completed / terminated / unsuccessful** | Summarize: *"6 historical proposals (3 accepted, 2 declined, 1 expired)."* Spell out by name only if it answers a current question. |

### Contracts

| Bucket | Treatment |
|---|---|
| **Pending** (`pending_signature`) | Show in full — the user might need to chase. |
| **Drafts** (`draft`, never sent — `sentDate: null`) | Mention briefly: *"3 drafts not yet sent."* These are usually forgotten artifacts. |
| **Stale pending** (`pending_signature` older than 30 days) | Mark explicitly as *"likely abandoned"* — don't list as actionable. |
| **Recently signed** (`signed`, last 90 days) | One-line each: *"MSA signed Feb 2026."* |
| **Old signed** | Summary: *"4 signed contracts (oldest: 2024)."* |

### Invoices

| Bucket | Treatment |
|---|---|
| **Outstanding** (`overdue`, `partialPaid`, `sent`, `read` with amount due) | Show every one — number, amount, days overdue. |
| **Recently paid** (last 90 days) | One-line each: *"INV-201 paid Feb 28, ₱20K."* |
| **Older paid history** | Summary: *"35 prior invoices (₱340K total over 2024–2025)."* |

### General principles

1. **Top of each section: what's actionable now.** Active records, in detail.
2. **Bottom of each section: a one-liner of the historical record** so the user knows the relationship has depth without it crowding the screen.
3. **Cap detail at ~5 items per bucket.** If "Active proposals" has 8, show the 5 most recent and note "(+3 more — say 'more proposals' to see all)".
4. **Order within a bucket** by recency *of last meaningful change* (`updatedAt`), not creation date. A proposal sent 3 days ago beats a proposal created last year.
5. **Annotate age in human terms**: "sent 3d ago" not "2026-04-30T07:00Z".

## Worked Example — Busy Customer

```markdown
# Acme Corp — Customer 360

**Contact:** Maria Chen (CEO) · maria@acme.example
**Relationship:** Customer since Aug 2024 · 8 deals total · ₱340K lifetime value

## Pipeline (3 active, 5 closed)
**Active:**
- **Acme website redesign** — Proposal stage, ₱100,000 (proposal #169 sent 3d ago, not viewed)
- **Acme retainer** — Qualified, no value set
- **Acme Q3 expansion** — Meeting, ₱40,000

**History:** 3 closed-won (₱180K total in 2025) · 2 closed-lost (last Q1 2025, reasons: price, timing)

## Proposals (4 active)
- #169 "Website redesign" — sent 3d ago, ₱100K, expires June 1
- #167 "Q3 expansion" — sent 12d ago, ₱40K, viewed but no response
- #165 "Maintenance retainer" — draft, last touched 2 months ago (probably stale)
- #163 "Discovery scope" — saved, never sent

*+8 historical proposals (5 accepted, 2 declined, 1 expired)*

## Contracts (2 pending, 4 signed historically)
- "Master Services Agreement" — pending signature with Maria, sent 4d ago
- "Q3 SOW" — pending signature with Maria, sent 18d ago (likely needs nudge)

*+1 draft never sent (Casual Employment Information Statement, 3 days old)*
*+4 signed contracts (oldest: 2024-08, newest: 2025-11)*

## Money
**Outstanding (3):**
- INV-203 — ₱12,000, 14d overdue
- INV-198 — ₱8,500, 6d overdue
- INV-176 — ₱5,000, 33d overdue

*Paid history: 12 prior invoices (₱180K total) — last paid INV-201 on Feb 28*

## Recent activity (last 30 days)
- Sent proposal #169 — 3d ago
- Sent contract MSA — 4d ago
- INV-203 went overdue — 14d ago

## Worth raising
- Proposal #169 not yet viewed after 3 days — worth a nudge
- Q3 SOW pending signature for 18 days — chase or assume dead
- INV-203 (₱12K, 14d overdue) is the most pressing receivable
```

That's a heavy customer rendered in ~30 lines. Without these rules, the same data could easily produce 100+ lines of mostly noise.

## Payment history (dedicated ledger) — `customer payments`

The 360 view above surfaces a *summary* of paid history. When the user wants the
full **payment ledger** — *"show me &lt;customer&gt;'s payments"*, *"what has Acme
paid"*, *"how much has X paid me"*, *"payment history for X"* — use the dedicated
command:

```bash
bookipi customer payments @c1          # or a customer ID
bookipi customer payments @c1 --limit 10   # most recent 10
```

There's no backend "all payments" endpoint, so it builds the ledger client-side:
it scans the customer's invoices and flattens every entry in each invoice's
`payments[]` array into one chronological list (newest first), with a running
total and the payment method. Unpaid invoices simply contribute nothing.

Present it as a short natural summary — lead with the total ("Acme has paid you
₱9M across 3 payments"), then the individual payments (amount · date · method ·
invoice), and offer a next step if they have anything still outstanding. Never
show the handle or the raw command.

## Presentation Rules (from the main skill)

Same as everywhere — never show handles to the user, never show raw CLI commands, refer to invoices by number, customers by name, deals by their name field.

## Why this is its own skill (not part of morning-brief)

The morning brief is *time-anchored* — what's relevant *today*. Customer 360 is *entity-anchored* — what's true *about this customer right now*. The data overlaps but the framing is different:

- Morning brief asks "what should I focus on?"
- Customer 360 asks "what do I know about this person?"

Both share the same per-customer query block, but the output organization, edge cases, and trigger phrases are distinct. Keeping them separate keeps each skill short and focused.

When Flow 1 (Win Deal) and Flow 2 (Quick Quote) are built, both will reuse the same per-customer query block. At that point, consider extracting the block into its own sub-skill.

## What This Flow Does NOT Do

- ❌ **Send any messages** — read-only.
- ❌ **Move deals between stages** — surface state, don't change it.
- ❌ **Create proposals or invoices** — that's a different flow.
- ❌ **Compare two customers** — one customer at a time.

If the user asks for any of those after the customer-360, switch flows.
