# Win Deal — Flow 1 (Contract Half: post-acceptance only)

The contract-and-close half of a sales flow. Triggered **after** a proposal has been sent and accepted, when the user wants a signed contract before invoicing. If no contract is needed, the user stays in `quick-quote.md` (Flow 2 — Half 2 invoices direct, no signature step).

> ## Every eSign — you write it, eSign signs it
>
> There is **no AI Contract command**. Anything to be signed — contract,
> agreement, NDA, offer letter, SOW — goes through **Bookipi eSign**, starting
> from one of three things:
>
> - **A document you write.** *"draft an NDA with Acme"*, *"write me a service
>   agreement"*, *"prepare an offer letter for Sam"*: write it yourself in the
>   conversation, let the user review it, render it to a PDF, then
>   `bookipi contract upload ./nda-acme.pdf --title "NDA — Acme"`.
> - **A template** in the user's eSign account or the Bookipi library: start it
>   in the eSign web app (`${BOOKIPI_WEB_URL}/contract`).
> - **A PDF the user already has**: `bookipi contract upload <file>`.
>
> `contract upload` returns the editor URL. Then prepare it as in
> [§ Preparing for signature](#preparing-for-signature) below, and stop at the
> Send screen. Never deliver a document for signature by `customer send-email`
> or any other email — that is a plain email, not an eSign.
>
> Phases 2–3 below are the *deal* flow: the same steps, plus the deal stage and
> the invoice. A standalone contract skips them.

> ## 🛑 STOP — only load this doc if the proposal is already accepted
>
> **This doc covers ONLY the post-acceptance branch.** Specifically:
>
> - **Phase 2** — writing the contract from an accepted proposal, uploading it to eSign, preparing it for signature (signers, tags), stopping at Send for the user's confirmation, then bumping the deal stage.
> - **Phase 3** — converting to invoice, closing the deal as won, after the contract is signed.
>
> **For drafting / sending the proposal itself, ALWAYS use `quick-quote.md`.** Phase 1 of every sales flow is identical (customer + deal + proposal generate + proposal send) and lives there. There is no separate "Win Deal Phase 1" — Win Deal forks off from Quick Quote *after* acceptance.
>
> ### The most common mistake (don't make it)
>
> The user's first prompt mentions "contract" or "agreement" → the agent loads this doc → tries to draft proposal **and** contract in one session. **Wrong.**
>
> The contract is written from an *accepted* proposal. Acceptance happens externally — the customer has to click "accept" in their email. You can't bridge it in a single conversation. **Even if the user explicitly says "draft the proposal and the contract," only draft the proposal.** Send it. Stop. Tell the user: *"Once Bruce accepts, just say 'draft the contract' and I'll handle the rest."*
>
> ### Load THIS doc when you see prompts like:
>
> - *"Tony accepted the proposal, draft the contract"*
> - *"Send the contract to Bruce"*
> - *"Has the MSA been signed yet?"*
> - *"Bruce signed — invoice him and close it out"*
> - *"Mark the Stark deal as won"*
>
> ### Load `quick-quote.md` instead for prompts like:
>
> - *"Draft a proposal for Bruce"* (even if user adds "and contract")
> - *"Quote Acme for the website redesign"*
> - *"Send Maria a proposal for the SEO retainer"*
> - *"Maria accepted, send the invoice"* (Quick Quote's Half 2 — no contract path)

This doc orchestrates **6 CLI mutations** across two entities (contract, invoice) plus deal-stage updates, with **three** CLI-side destructive gates. You write the contract, `contract upload` puts it in eSign, and it is **prepared in the eSign web app** — signers and tags — by you in the browser or by the user. Sending, from there or with `contract send`, waits for the user's fresh OK.

> ## ⚠️ Critical confirmation rules — read before invoking any mutation
>
> **Three** CLI commands in this doc are destructive (real customer-visible side effects). The agent **MUST** present a plain-language summary and get explicit user approval before each:
>
> 1. **Sending the contract** — `contract send`, or pressing **Send** in the eSign web app. Emails the signers; no unsend. Only on a fresh confirmation for this send (Phase 2 step 6). "Looks good" about the document is not one. Never when they say they already sent it themselves.
> 2. **`invoice send`** — sends a real email. Confirm: recipient, total, due date.
> 3. **`deal update --key closed_win`** — moves the deal to a terminal stage. Confirm: did the customer actually pay / sign off, or are we marking it prematurely?
>
> **Three** are mutations but reversible / quiet (no email goes out). Run them without confirmation:
>
> 4. **`contract upload`** — creates the eSign document from your PDF. No signer, no email.
> 5. **`invoice create-from-proposal`** — creates the invoice but doesn't send it. Reversible (delete invoice).
> 6. **`deal update --key contract`** — bumps the deal stage once the contract is sent. Reversible.
>
> (The proposal-side `proposal send` gate lives in `quick-quote.md` — it fires before this doc even loads.)
>
> **Never skip the destructive confirmation gates above.**

## When to Trigger This Flow

**The user signals "I want a signed contract before I invoice" — and the proposal is already accepted.** Concretely:

- "Tony accepted the proposal — draft the contract"
- "Draft the agreement for Bruce" *(only after the proposal was sent + accepted)*
- "Send the MSA to Acme"
- "Has Bruce signed the contract yet?"
- "Bruce signed — invoice him and close it out"
- "Mark the Stark deal as won"

**The most common false-trigger** (don't fall for it):

- ❌ *"Draft a proposal **and contract** for Bruce"* → load `quick-quote.md` instead. Run Phase 1 only. Tell the user the contract waits for acceptance.
- ❌ *"Standard agreement for Tony Stark, ₱200K project"* (no proposal exists yet) → load `quick-quote.md`. Generate + send the proposal first.
- ❌ *"They'll need a contract"* (initial scoping prompt) → still `quick-quote.md`. Mention the contract step in your phase-end recap, but don't try to do it in this session.

**Do NOT trigger** when:

- The proposal hasn't been sent yet → `quick-quote.md`
- The proposal was sent but isn't accepted → wait. Don't drop into Phase 2 speculatively.
- The user just wants a reminder for an existing invoice → `invoices.md`
- The user wants pipeline status → `morning-brief.md` or `customer-360.md`
- The user wants to edit a contract already in `pending_signature` → that's a web-UI action, redirect them.

## The Flow

Two phases separated by an external wait (customer signs the contract). Don't try to bridge them in a single conversation.

```
Phase 2 — Pre-signed             (you write it; prepared in eSign; stop at Send)
   ↓ user waits for customer to sign the contract
Phase 3 — Post-signed            (agent action; close the deal)
```

(Phase 1 — proposal generate + send — lives in `quick-quote.md`. Once the proposal is accepted, the user comes back, says "draft the contract" or similar, and *that* is what brings you into this doc.)

### Phase 2 — Pre-signed (separate user session)

Trigger: user says "Tony accepted, draft the contract", or the morning brief surfaces a fresh `proposal.status === "accepted"` and the user agrees to proceed.

````
1+2. Confirm acceptance AND check for an existing contract — IN PARALLEL
   bookipi proposal list --search "Tony" --status accepted --json     [AUTO]
   bookipi contract list --limit 50 --json                            [AUTO]
   → Issue these as a single batch.
   → After both return:
     - Find the accepted proposal in the first response. Capture its
       `_id` and the linked `projectPipelineId` (deal handle) — you'll
       need the deal handle in step 7.
     - Filter contracts locally — does any contract have a recipient
       email matching the customer? If yes, IDEMPOTENCY KICKS IN:
       • If contract.status === "draft" → already uploaded, not yet
         sent. Its editor URL is
         `${BOOKIPI_WEB_URL}/contract/edit/<contractDocId>` — go to
         step 5 with it.
       • If contract.status === "pending_signature" → already sent,
         skip phase 2 entirely. Tell the user "Already out for
         signature — I'll let you know when it's signed." Stop.
       • If contract.status === "signed" → jump to Phase 3.
   → Otherwise no existing contract — proceed to step 3.

3. Write the contract yourself, from the accepted proposal: its scope,
   value, dates and the customer as the counterparty. Show it to the user
   and take their edits. Render the agreed text to a PDF.

4. bookipi contract upload ./contract-stark.pdf --title "Services Agreement — Stark Industries"   [AUTO]
   → @k4 created as an eSign draft. Output includes the editor URL.

5. Prepare it for signature — § Preparing for signature below. With a
   browser, you do it, and stop at the Send screen. Without one, give the
   user the editor link and the same steps.

6. Ask before anything is sent. Do NOT assume, and do NOT send on your own:
   AskUserQuestion:
   - Question: "<title> is ready to go to <signers>. Send it now?"
   - Header: "Send contract"
   - Choices:
     - "Send it"                        → if you prepared it in the
                                          browser, press the "Finish &
                                          send" dialog's Send. Otherwise
                                          `bookipi contract send @k4 --yes`
                                          [DESTRUCTIVE]. Report who it
                                          went to.
     - "I sent it myself"               → do not send. Step 7.
     - "Hold off"                       → no action; reply: "All good, take your time."
     - "Cancel — leave as draft"        → no action; reply: "Got it, leaving @k4 alone."
   → `contract send` REFUSES, with an editor link, when the contract has no
     signer or no signature field. Relay the reason and the link, and ask
     again once it's fixed. Don't work around it: a contract sent without a
     signature field can be "completed" with no signature on it.
   → Then step 7.

7. [STATE CHANGE — fires once the contract is sent (step 6).]
   bookipi deal update @d57 --key contract                     [REVERSIBLE]
   → deal stage moves from `proposal` → `contract`.
   → If the deal is already at-or-past `contract` (terminal /
     custom-key), the CLI skips with a note. See `common.md` § Deal
     Stage Auto-Progression.
   → IMPORTANT: contracts in the eSign service don't store a deal
     reference. The deal handle must come from step 1 (the
     `projectPipelineId` captured from the accepted proposal). If you
     don't have one, surface it via `AskUserQuestion`: *"What deal
     should I bump?"* with the top 2-3 matching deals from a quick
     `deal list --search "<customer>"` as choices, plus a "None / skip"
     exit. Don't free-text-ask.

8. **Offer the daily signed-watcher** via `AskUserQuestion`. The contract is
   live for signature; the user can passively wait or have the agent check
   for them. Surface this exactly once, right after the deal bump.

   - Question: *"Want me to check daily until Tony signs?"* (substitute the
     real signer's name)
   - Header: `"Watch contract"`
   - Choices:
     - `"Yes — check daily and ping me"` → step 9 (create schedule)
     - `"Check weekly instead"`            → step 9 (create schedule, weekly)
     - `"No, I'll let you know"`           → skip to step 10

9. **Create the scheduled task** via `mcp__scheduled-tasks__create_scheduled_task`.
   The task runs the watcher in a fresh session — so the body must be a
   complete, self-contained set of instructions that re-loads context.

   Use a body like this (substitute the real contractDocId, title, and
   customer/signer names):

   ```
   Daily watcher: has the "<title>" contract for <signer-name> been signed?

   1. Run: bookipi contract list --status signed --limit 50 --json
   2. Search the items array for one with _id === "<contractDocId>".
   3. If found AND status === "signed":
      - Notify the user in plain language: "Good news — <signer-name>
        signed the <title> contract."
      - Load .claude/skills/bookipi-cli/docs/win-deal.md and run Phase 3
        (draft the invoice, offer to close the deal as won).
      - Use mcp__scheduled-tasks__update_scheduled_task to mark this
        watcher complete so it doesn't fire again.
   4. If not found OR status is anything else (still pending_signature,
      declined, expired): exit without messaging the user. The schedule fires again next
      time.

   Context for this watcher:
   - Contract _id: <contractDocId>
   - Source proposal handle: <@pN>
   - Deal handle: <@dN>
   - Customer: <name>
   ```

   Cadence: daily by default, weekly if the user picked that. Pick a
   morning-local time (Cowork handles the timezone). Don't burn the user's
   API budget — once per day is plenty.

   If the user declined to set up a default company / never logged in inside
   this workspace, the watcher will hit an auth error on its first run.
   That's the user's problem to fix, not the agent's — surface the error
   in the watcher's output rather than silently retrying.

10. Recap to user (one paragraph). If the watcher was set up, mention it:
    *"Got it — I bumped the Stark Industries deal to Contract stage and I'll
     check every morning to see if Tony signed. You'll hear from me the day
     he does."*

    If the user declined the watcher:
    *"Got it — bumped the deal. Just say 'has Tony signed?' when you want to
     check, or ping me once he's signed."*
````

**End of Phase 2.** The conversation ends here. Phase 3 resumes either when the watcher catches a signed contract, or when the user mentions it explicitly.

### Phase 3 — Post-signed (separate user session)

Trigger: user says "Tony signed", or `morning-brief` / a spot-check shows `contract.status === "signed"`.

```

1+2. Confirm signed status AND check invoice idempotency — IN PARALLEL
bookipi contract list --status signed --json [AUTO]
bookipi invoice list --status saved,sent,read --json [AUTO]
→ Issue these as a single batch.
→ After both return: - Find the signed contract; capture its source `proposalId` (or
just match by customer email if proposal linkage is fuzzy). - If any invoice has `proposalId === <accepted proposal._id>`:
skip conversion, tell the user: "Already converted to INV-XXX.
Want me to send it?" Then jump to step 4.

3. Convert proposal to invoice
   bookipi invoice create-from-proposal @p15 [AUTO]
   → @i9 created with same items, customer, totals.

4. [USER CONFIRM] — send the invoice:
   "Tony signed the contract. I'll send INV-722 (₱200K, due 15 days)
   now, or hold?"

5. On approval:
   bookipi invoice send @i9 -r tonystark@yopmail.com --yes \
    -s "Invoice INV-722 — Stark Industries platform" \
    -m "Hi Tony, attached is the invoice for the platform engagement..." [DESTRUCTIVE]

6. [USER CONFIRM] — close the deal:
   "Move the Stark Industries deal to Closed Win? (₱200K, all artifacts done)"

7. On approval:
   bookipi deal update @d57 --key closed_win [DESTRUCTIVE — terminal stage]

8. Recap:
   "Closed-won the Stark Industries deal. Contract signed, INV-722
   (₱200K) is out for collection. Nice one."

````

## Branching — All Possible Paths

This doc covers post-acceptance only — proposal-side branches (declined, asked for changes, etc.) are in `quick-quote.md`. The branches that matter here:

| Customer response | Flow direction |
|---|---|
| **Contract signed, invoice sent, deal closed-won** | Run Phase 2 + Phase 3 as documented |
| **Contract uploaded but not prepared or sent** | Pick it up at Phase 2 step 5 with its editor URL. |
| **Contract sent (pending_signature) but not signed for N days** | Stalled. The morning brief surfaces this in *Awaiting action*. Suggest a nudge but **don't auto-resend** without explicit user request. To formally abandon: `deal update <dealId> --key closed_lose` after USER CONFIRM. |
| **Customer wants changes before it is sent** | Revise the text, render a new PDF and upload it again (Phase 2 steps 3–4); leave the old draft or delete it in the web app. If a `pending_signature` contract already went out, the user has to void it in the web; the CLI can't recall a sent contract. |
| **Customer paid but contract was never sent / signed** | Edge case — usually a small / trusted customer where the contract was overkill. Confirm with the user, then run Phase 3 anyway. The draft can stay as-is or be abandoned in the UI. |
| **User says "cancel that" mid-Phase-2** | Don't auto-delete the draft. Drafts are cheap; let it sit. Optionally roll the deal back to `proposal` only if the user explicitly asks — `deal update --key proposal` is a stage *demotion*, which the auto-progression rules normally forbid, so it must be a manual action with explicit intent. |

## Idempotency — Don't Re-Do Work

Uploading twice creates two eSign documents for one deal, and the signers could get both.

| Before running… | Check… |
|---|---|
| `contract upload` | **`contract list --json` and filter locally** by title or recipient email matching the customer. If a draft, pending-signature, or signed contract already exists, surface it instead of uploading again. |
| `contract send` | Safe to repeat: on a contract already at `pending_signature` it reports "already sent" and emails nobody. Still, don't call it when the user says they sent it themselves. |
| `deal update --key contract` | Skip if the deal is already at `contract` or later, or at a terminal/custom-key. The CLI itself will short-circuit with a skip-note. |
| `invoice create-from-proposal` | Same as Quick Quote — `proposalId` match on existing invoices. |
| `invoice send` | Same as Quick Quote. |
| `deal update --key closed_win` | Same as Quick Quote — skip if already at `closed_win`. |

## Preparing for signature

Signers and tags are placed visually, in the eSign web app — the editor URL
`contract upload` returns (`${BOOKIPI_WEB_URL}/contract/edit/<id>`), or
`${BOOKIPI_WEB_URL}/contract` for a template. If you can drive a browser, do
it there; if you can't, give the user the link and these steps:

1. **Signers.** Add each one by searching the user's customers. If there is no
   match, create the customer in that dialog.
2. **Tags.** Place the **signature** tag directly above the signature line,
   its bottom edge touching the line. Place the **date** tag on or beside the
   date line. Left-align the tags with each other.
3. **Check.** Zoom in and confirm every tag sits on its line.
4. **🛑 Stop at the Send screen.** The editor's **Send** button doesn't send:
   it opens a **"Finish & send"** dialog (document name, CC, email message,
   SMS, automatic reminders — on by default, every 2 days). That dialog is the
   Send screen. Tell the user who it will go to and what it is set to, and ask
   (Phase 2 step 6). Press the dialog's **Send** only on a fresh confirmation
   given for this send. Send it **there**, not with `contract send`: the CLI
   skips the dialog's message, CC and reminders, and leaves the open editor
   showing an unsent draft. `contract send` is for a contract the user
   prepared themselves.

Once the contract is sent — in the web app or by `contract send` — run
`deal update --key contract` to bump the deal stage.

## Why the Deal Bump Is a Separate CLI Step

Contracts in the eSign service don't store a `dealId`. They're standalone documents — the CLI can't infer which deal a contract belongs to from the contract record alone.

The agent must explicitly run `deal update --key contract` once the contract is sent (Phase 2 step 6), using the deal handle captured from the accepted proposal in step 1 of Phase 2.

```bash
# Bump the deal stage once the contract is sent.
bookipi deal update @d57 --key contract
```

If the agent forgets to bump it, the deal stays at `proposal` while the contract is out for signature — visible (incorrectly) as "needs proposal action" in the morning brief.

## What to Tell the User Throughout

The agent sends three kinds of messages during this flow:

1. **Status updates** (one-line, factual, after each non-destructive step): *"Uploaded to eSign. Signers and tags are placed — it's on the Send screen."*
2. **Send gate** (one AskUserQuestion in Phase 2, step 6): send it now?
3. **Recaps** (one paragraph at the end of each phase): *"I bumped the Stark deal to Contract stage. Ping me when Tony signs."*

Skip these:

- ❌ Listing every command you ran.
- ❌ Fake suspense ("Let me check…") — just do the check, then report the result.

## What This Flow Does NOT Do

- ❌ **Use AI Contract** — there is no command for it. You write the document.
- ❌ **Attach signers or place tags via CLI** — both happen in the eSign web app (§ Preparing for signature).
- ❌ **Send the contract unasked** — in the browser or with `contract send`, only on the user's fresh OK (Phase 2 step 6). If they sent it themselves, don't.
- ❌ **Email the document for signature** — `customer send-email` sends a plain email, not an eSign.
- ❌ **Recall a sent contract** — once the user sends from the web editor and the contract is `pending_signature`, the email is on its way. No unsend.
- ❌ **Track signature progress in real-time** — the agent reads `contract list --status signed` on demand; there's no webhook or polling. If the user asks "did Tony sign yet?", the agent runs the check fresh.
- ❌ **Send reminders to non-signing recipients** — no contract-reminder verb exists yet. If the user wants to nudge, they do it via email outside the agent.
- ❌ **Auto-decide between Flow 1 and Flow 2** — heuristics suggest, the user / context decides.
- ❌ **Handle invoice payments** — once the invoice is sent, payment tracking is out of scope.

## Cross-References

- **Proposal generation + send (the prerequisite step) →** `quick-quote.md` (the entire doc). Win Deal Phase 2 only triggers AFTER Quick Quote has finished its Half 1 and the customer has externally accepted.
- Customer + deal context → `customer-360.md`
- Detecting an accepted proposal or signed contract during a daily check → `morning-brief.md` (Pipeline Highlights / Awaiting action sections)
- Why per-customer queries fan out across deal/proposal/contract/invoice → `morning-brief.md` (Why all four per-customer queries are needed)
- Stable status keys for deals → `common.md` and the `agent-flows.md` root doc
- Disambiguation when "Tony" matches multiple customers → `common.md` (Disambiguation section)
- Deal stage auto-progression rules (forward-only, terminal-skip, custom-key-skip) → `common.md` (Deal Stage Auto-Progression section)
- Progress narration timing → `common.md` (Progress Narration section)
- Spot-checking contract status mid-conversation → `common.md` (Common Spot-Checks section)
