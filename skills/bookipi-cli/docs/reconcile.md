# Bank Reconciliation — match deposits to invoices, then mark paid

Triggers: *"reconcile my bank statement"*, *"match these deposits"*, *"here's my
bank export"*, *"I got paid by bank transfer — update my invoices"*, a dragged
bank CSV/OFX file, or a pasted screenshot of online banking.

**What this flow is for:** payments Bookipi cannot see — direct bank transfers,
checks, cash deposits. Payments made through the invoice's own Stripe button
record themselves automatically and never need this flow. Reconciliation closes
the gap for everything paid *off-platform*.

## The contract with the user

- **Matching is automatic. Writing is gated.** Never run `mark-paid` from this
  flow without a fresh `AskUserQuestion` confirmation showing the full match
  table.
- **Low confidence becomes a question, never a write.** A wrongly-marked
  invoice costs the user real money and trust.
- **Every proposed match shows its evidence** (descriptor fragment, amount fit,
  date fit, customer) so the user can scan-verify instead of re-deriving.

## Step 1 — Intake the statement

Accept any of:
- **CSV/TSV file** (dragged in or a path): read it directly. Column layouts
  vary by bank — identify date / description / amount (credit) columns by
  inspection, don't assume an order. Only CREDIT (incoming) rows matter.
- **Screenshot/photo of a statement**: read the rows by vision (extract date,
  descriptor, amount per row), then treat identically. Use the pasted-image
  recovery ladder from `customers-and-items.md` only if the file itself is
  needed — for reconciliation, reading the rows is enough.
- **Pasted text**: parse as-is.

Normalize each deposit to `{date, descriptor, amount}`.

## Step 2 — Load the open pool

```bash
bookipi invoice list --status saved,sent,read,overdue --limit 50 --json
```

The pool is invoices with `amountDue > 0`. Paid invoices (including everything
Stripe already recorded) are excluded automatically. For partially-paid
invoices, match against the REMAINING `amountDue`, not the total.

## Step 3 — Set aside processor payouts FIRST

Deposits whose descriptor names a payment processor — `STRIPE`, `STRIPE
PAYOUT`, and similar settlement lines — correspond to invoices **already marked
paid** by the platform (bundled, net of fees, delayed ~2 days). **Never match
these against open invoices** — doing so double-counts revenue. List them in
the results table as *"Stripe payout — already reconciled automatically, no
action."*

## Step 4 — The matching ladder (per deposit, in order)

1. **Descriptor reference**: invoice number in the text (`INV-56`, `invoice
   56`) → direct match. Highest confidence.
2. **Descriptor identity**: payer/customer name or a recognizable fragment
   (`S INDUSTRIES PTE` → Stark Industries) → narrows the pool to that
   customer's open invoices; combined with an amount fit → high confidence.
3. **Amount uniqueness**: exactly one open invoice at that amount → confident
   match even with a mute descriptor (`CASH DEPOSIT`). Amount within ~2% under
   the invoice (bank fee shaving) counts as an amount fit — record the actual
   received amount and note the difference as a probable fee.
3b. **Mute-descriptor signals** (deposits with no useful text — common; don't
   give up at rung 3): (a) *payment rhythm* — `bookipi customer payments <id>`
   / insights expose each customer's typical pay-lag; a deposit landing at a
   customer's usual N-days-after-invoice is a strong vote for that customer's
   open invoice; (b) *lifecycle correlation* — an invoice recently viewed
   (`--status read`) or recently reminded is disproportionately likely to be
   the one just paid. These are corroborating votes, not sole evidence: mute
   descriptor + amount fit + rhythm fit = proposable; rhythm alone = ask.
4. **Date sanity** (constraint, not a matcher): a deposit must be ON/AFTER the
   invoice's issue date. Payments lag invoices by days or weeks — "long after
   due date" is normal, never disqualifying.
5. **Mutual exclusion**: each deposit pays at most one invoice-set; each
   invoice absorbs at most one deposit (v1). Lock high-confidence matches
   first — ambiguity often collapses once the confident matches leave the pool.
6. **Same customer, same amount, multiple invoices** (e.g. two Rp 20,000
   invoices to the same customer, one Rp 20,000 deposit): assign to the
   **oldest invoice first** (standard bookkeeping FIFO) and say so in the
   table — the books balance either way, but the choice must be visible.
7. **Genuinely undecidable** (same amount, different customers, mute
   descriptor): list under "needs your call" with the candidates **ranked by
   the soft signals above and with the evidence stated** — the confirmation
   step asks the user to assign or skip. Never coin-flip across customers.
   This residue is the product working as designed: the user answers a couple
   of multiple-choice questions instead of cross-referencing the whole
   statement. If mute deposits recur for a user, suggest the structural fix:
   unique reference amounts on invoices (distinct trailing digits per open
   invoice) make even blank deposits match deterministically.

Bundled transfers (one deposit = sum of 2-3 invoices from the same customer)
are in scope: try exact subset-sums against a single customer's open invoices
before declaring a deposit unmatched.

## Step 5 — The confirmation gate

Present ONE table in chat (plain language, no handles/commands):

> | Deposit | Matched invoice | Evidence |
> |---|---|---|
> | 14 Jul · Rp 520,000 · "TRF STARK... INV-56" | invoice-56 — Tony Stark | invoice # in descriptor |
> | ... | | |
>
> Plus sections for: **Stripe payouts (no action)**, **needs your call**,
> **unmatched** (left untouched).

Then `AskUserQuestion`: *"Record these N payments (Rp total)?"* — options like
"Record all N" / "Let me adjust" / "Cancel". Undecidable rows get their own
question with the candidate invoices as options.

## Step 6 — Execute and verify

Only after explicit confirmation, one `mark-paid` per match:

```bash
bookipi invoice mark-paid <id> --amount <received> --method transfer --date <deposit date>
```

- Use the DEPOSIT's date and actual received amount (fee-shaved counts as
  partial + note, or full per user preference — ask once if it recurs).
- Then re-run the open-pool query and close with the delta: *"Recorded 3
  payments totaling Rp 605,000 — Tony's balance is now Rp 20,000 across 1
  open invoice."*
- **Log it**: one dated line in the assistant-memory action log — payments
  recorded, total, user-approved (`docs/assistant.md`).
- Mistake recovery: `bookipi invoice void <id>` clears payments and returns
  an invoice to unpaid — mention it if the user spots a wrong match after the
  fact.

## Recurring sweep (optional)

The flow slots into the standard automations pattern (`docs/automations.md`,
like the daily collections check): e.g. every Monday, the user drops the
week's export (or a mounted folder is checked for new statements), the agent
drafts the match table, and NOTHING is recorded until the user confirms that
run's card. Safe unattended: the sweep only ever *drafts*.
