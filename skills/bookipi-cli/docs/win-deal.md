# Win Deal — Flow 1 (Contract Half: post-acceptance only)

The contract-and-close half of a sales flow. Triggered **after** a proposal has been sent and accepted, when the user wants a signed contract before invoicing. If no contract is needed, the user stays in `quick-quote.md` (Flow 2 — Half 2 invoices direct, no signature step).

> ## Standalone contracts (no proposal) — `contract draft` and `contract upload`
>
> The proposal-gated flow below is for contracts that come **out of a deal**. When
> the user just wants a contract on its own, there are two paths — neither needs a
> proposal, and both end at the **editor URL** where the user places the signature
> and sends. Do **not** route these through `create-from-proposal`.
>
> **A. AI writes it → `contract draft`.** *"draft an NDA between me and Acme"*,
> *"write me a service agreement"*, *"draft a contract for a 6-month retainer"*:
>
> ```bash
> bookipi contract draft "mutual NDA between my company and Acme Corp" \
>   --jurisdiction usa \
>   --detail "Term?::12 months" --detail "Confidentiality?::Mutual" \
>   --signer-name "Acme Corp" --signer-email "legal@acme.com"   [AUTO ~15-30s]
> ```
> The AI generates the clauses server-side; `--detail "q::a"` is repeatable (map
> the user's asks: term, value, parties, IP, confidentiality).
>
> **B. Bring your own file → `contract upload`.** *"I have a contract PDF, send it
> for signature"*, *"upload this contract"*, *"sign this PDF"* — or an
> **AI-written contract the agent drafted and rendered to a PDF itself** (no
> contract API): render the text to a PDF, then upload it.
>
> ```bash
> bookipi contract upload ./nda-acme.pdf --title "NDA — Acme"    [AUTO]
> ```
> Uploads the file as the document body and returns the editor URL. Signers +
> signature placement happen in the editor (that's inherently visual).
>
> Everything below (Phases 2–3) is the *deal* flow and does not apply to a
> standalone draft/upload.

> ## 🛑 STOP — only load this doc if the proposal is already accepted
>
> **This doc covers ONLY the post-acceptance branch.** Specifically:
>
> - **Phase 2** — drafting the AI contract from an accepted proposal, auto-finalizing it (signer + signature placement + PDF + S3 upload), then confirming send via a destructive gate before bumping the deal stage.
> - **Phase 3** — converting to invoice, closing the deal as won, after the contract is signed.
>
> **For drafting / sending the proposal itself, ALWAYS use `quick-quote.md`.** Phase 1 of every sales flow is identical (customer + deal + proposal generate + proposal send) and lives there. There is no separate "Win Deal Phase 1" — Win Deal forks off from Quick Quote *after* acceptance.
>
> ### The most common mistake (don't make it)
>
> The user's first prompt mentions "contract" or "agreement" → the agent loads this doc → tries to draft proposal **and** contract in one session. **Wrong.**
>
> `contract create-from-proposal` requires an *accepted* proposal as input. Acceptance happens externally — the customer has to click "accept" in their email. You can't bridge it in a single conversation. **Even if the user explicitly says "draft the proposal and the contract," only draft the proposal.** Send it. Stop. Tell the user: *"Once Bruce accepts, just say 'draft the contract' and I'll handle the rest."*
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

This doc orchestrates **6 CLI mutations** across two entities (contract, invoice) plus deal-stage updates, with **two** CLI-side destructive gates. The contract signing flow uses a two-pass editor design: the CLI handles PDF mechanics (render + upload + record creation) while the web editor handles signer attachment, signature placement, and the send action.

> ## ⚠️ Critical confirmation rules — read before invoking any mutation
>
> **Two** CLI commands in this doc are destructive (real customer-visible side effects). The agent **MUST** present a plain-language summary and get explicit user approval before each:
>
> 1. **`invoice send`** — sends a real email. Confirm: recipient, total, due date.
> 2. **`deal update --key closed_win`** — moves the deal to a terminal stage. Confirm: did the customer actually pay / sign off, or are we marking it prematurely?
>
> **Four** are mutations but reversible / quiet (no email goes out). Run them without confirmation:
>
> 3. **`contract create-from-proposal`** — creates the AI source draft. No PDF, no signer, no email.
> 4. **`contract finalize`** — renders PDF, uploads to S3, creates contract record. No signer, no email. Reversible.
> 5. **`invoice create-from-proposal`** — creates the invoice but doesn't send it. Reversible (delete invoice).
> 6. **`deal update --key contract`** — bumps the deal stage after the user sends from the editor. Reversible.
>
> **`bookipi contract send` is NOT called by this skill flow.** Signer attachment, signature placement, and the send action happen in the web editor (editor URL #2 returned by `contract finalize`). The CLI command still exists for power users.
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
Phase 2 — Pre-signed             (fully CLI-driven; web editor is fallback)
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
       • If contract.status === "draft" → already finalized, not yet
         sent. Surface the editor URL #2:
         `${BOOKIPI_WEB_URL}/contract/edit/<contractDocId>`.
         Tell the user to open it to attach signer, place signature, send.
       • If contract.status === "pending_signature" → already sent,
         skip phase 2 entirely. Tell the user "Already out for
         signature — I'll let you know when it's signed." Stop.
       • If contract.status === "signed" → jump to Phase 3.
   → Otherwise no existing contract — proceed to step 3.

3. Narrate the slow step (~15-20s for AI clauses). Then:
   bookipi contract create-from-proposal @p15                  [AUTO ~15s]
   → @k4 created at AI-edit stage. Output includes editor URL #1.

   **Smart input defaults already baked in** — no flags needed for the
   common case. If the user wants to override:
   - `--jurisdiction <slug>`: ANY country (e.g. `usa`, `australia`, `germany`) — the generator produces law appropriate to it. Default: derived from the company's country, falling back to `usa`; the CLI prints which it chose
   - `--industry <name>` (default: `Web, Tech & Media`)
   - `--what-to-create "<text>"` (default: derived from proposal title)

4. Surface editor URL #1 to the user. Tell them:
   "Open the link to tweak any clause wording. Come back when you're done editing
    and I'll finalize the document."

   Use AskUserQuestion to gate on user's return:
   - Question: "Done editing the clauses?"
   - Header: "Clauses ready"
   - Choices:
     - "Yes — finalize the contract" → step 5
     - "Still editing — give me a sec" → no action; reply: "All good, take your time."
     - "Cancel — leave as AI draft" → no action; reply: "Got it, leaving @k4 alone."

5. On confirmation: run finalize. This renders PDF + uploads + creates the
   contract record. ~5-10 seconds.
   bookipi contract finalize @k4                               [AUTO ~5-10s]
   → @k5 created. Contract record in draft status. Output includes editor
     URL #2 with the contract doc ID.

   Format the chat reply after finalize completes:

   ```markdown
   ✅ AI contract drafted and finalized for **Tony Stark** — ₱200K, from Proposal-176.

   **Quick summary:**
   - Title: *Service Agreement — Stark Industries*
   - Source: Proposal-176 (₱200K, accepted yesterday)
   - Status: draft (PDF uploaded, ready for signer)
   ```

6. Surface editor URL #2. Tell the user:
   "The contract is finalized and ready. Open the link to:
    - Attach the signer (recipient email + name)
    - Place the signature box where it should sit
    - Click Send when ready

    Once you hit Send, the signer gets a real signature-request email — no
    unsend. Ping me when you've sent it and I'll bump the deal stage."

   AskUserQuestion for post-send signal:
   - Question: "Tell me when you're back — what happened in the editor?"
   - Header: "Contract status"
   - Choices:
     - "Sent it — bump the deal" → step 7 (deal bump) → step 8 (offer watcher)
     - "Still working — hold off" → no action
     - "Cancel — leave as draft" → no action

7. [STATE CHANGE — fires from explicit chip-click in step 6.]
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
      declined, expired): silently exit. The schedule fires again next
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
   bookipi invoice send @i9 -r tonystark@yopmail.com \
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
| **AI draft created (via create-from-proposal) but not yet finalized** | Run `contract finalize @kN` to render PDF + create the contract record. If finalize already ran (status is no longer `created_by_ai` or `draft`), the command will error — surface the error and offer editor URL #2 as the fallback. |
| **Contract sent (pending_signature) but not signed for N days** | Stalled. The morning brief surfaces this in *Awaiting action*. Suggest a nudge but **don't auto-resend** without explicit user request. To formally abandon: `deal update <dealId> --key closed_lose` after USER CONFIRM. |
| **Customer wants contract changes after the AI draft is generated** | Tell the user contract editing is a web-UI action — they should open the AI draft in the editor, edit clauses or fields, then send from there. If a `pending_signature` contract already went out and the customer asks for changes, the user has to abandon-and-redraft in the web; the CLI can't recall a sent contract. |
| **Customer paid but contract was never sent / signed** | Edge case — usually a small / trusted customer where the contract was overkill. Confirm with the user, then run Phase 3 anyway. The AI draft can stay as-is or be abandoned in the UI. |
| **User says "cancel that" mid-Phase-2** | Don't auto-delete the AI draft. Drafts are cheap; let it sit. Optionally roll the deal back to `proposal` only if the user explicitly asks — `deal update --key proposal` is a stage *demotion*, which the auto-progression rules normally forbid, so it must be a manual action with explicit intent. |

## Idempotency — Don't Re-Do Work

Critical because Phase 2 has the slowest single command in the skill (~15-20s of AI generation). Re-running it would burn time AND create a duplicate AI draft record.

| Before running… | Check… |
|---|---|
| `contract create-from-proposal` | **`contract list --json` and filter locally** by recipient email matching the customer. If a draft, pending-signature, or signed contract already exists, surface it instead of regenerating. Re-deriving AI clauses costs ~15-20s — never burn that twice for the same customer. Note: an AI-only draft (created by this CLI before finalization) may not yet show up in `contract list` — that lists finalized contract docs, not AI source docs. If the user is unsure whether they already drafted, ask before re-running. |
| `contract finalize` | Idempotent in spirit — if you re-run it on the same `@kN`, the command will fail because the AI source doc is no longer in a finalize-able state after the first run. That's expected and safe: surface the error to the user. The finalized contract record (a different handle, @k(N+1)) already exists. Surface editor URL #2 for the existing record. |
| `deal update --key contract` | Skip if the deal is already at `contract` or later, or at a terminal/custom-key. The CLI itself will short-circuit with a skip-note. |
| `invoice create-from-proposal` | Same as Quick Quote — `proposalId` match on existing invoices. |
| `invoice send` | Same as Quick Quote. |
| `deal update --key closed_win` | Same as Quick Quote — skip if already at `closed_win`. |

## Smart Inputs to `contract create-from-proposal`

The command auto-derives almost everything from the proposal. The agent rarely needs to pass flags explicitly. Defaults:

| Input | Default | Override flag | When to override |
|---|---|---|---|
| `whatToCreate` (the AI prompt) | derived from proposal title (strips "Proposal — N" prefix) | `--what-to-create "..."` | When the proposal title is generic ("Proposal — 169") AND the user gave specific scope verbally. |
| `jurisdiction` | derived from the company's country — ANY country works (CLI prints its choice; falls back to `usa` with a warning if the country is missing) | `--jurisdiction <any country>` | Pass it explicitly when the CUSTOMER's country is known and differs from the company's — the contract should match where the counterparty operates. Watch the CLI's stderr note and surface it if it warned. |
| `industry` | `Web, Tech & Media` (the CLI prints a note when this default is used) | `--industry "<name>"` | **Always pass it when the business or deal context tells you the industry** — a plumber's contract shouldn't carry tech framing. Infer from the deal/customer/description; only accept the default for genuinely tech engagements. The list of valid industries is enforced server-side. |

If the user is in the USA or Australia and the deal is software/web — pass nothing, the derived default is fine. Signer attachment happens in the web editor (editor URL #2), not via a CLI flag.

## Web Editor — Two Passes

The flow uses two editor URLs, each with a distinct job:

1. **Editor URL #1** — `${BOOKIPI_WEB_URL}/contract/ai-contract/edit/<aiDocId>` (from `create-from-proposal` output). Used for clause editing before finalization. The AI draft is still editable here.

2. **Editor URL #2** — `${BOOKIPI_WEB_URL}/contract/edit/<contractDocId>` (from `contract finalize` output). Used after finalization to attach the signer, place the signature box, and click Send. This is not a fallback — it is the required step for sending.

After the user sends from editor #2, they should ping the agent so it can run `deal update --key contract` to bump the deal stage.

## Why the Deal Bump Is a Separate CLI Step

Contracts in the eSign service don't store a `dealId`. They're standalone documents — the CLI can't infer which deal a contract belongs to from the contract record alone.

The agent must explicitly run `deal update --key contract` after the user confirms they sent the contract from editor #2 (the "Sent it — bump the deal" chip in Phase 2 step 6), using the deal handle captured from the accepted proposal in step 1 of Phase 2.

```bash
# Bump the deal stage after user confirms send from editor URL #2.
bookipi deal update @d57 --key contract
```

If the agent forgets to bump it, the deal stays at `proposal` while the contract is out for signature — visible (incorrectly) as "needs proposal action" in the morning brief.

## What to Tell the User Throughout

The agent sends three kinds of messages during this flow:

1. **Status updates** (one-line, factual, after each non-destructive step): *"AI contract drafted. Open the editor to tweak clauses — I'll finalize once you're done."*
2. **Editor URL gates** (two AskUserQuestion gates in Phase 2): one after `create-from-proposal` (done editing clauses?), one after `contract finalize` (sent from the editor?). See Phase 2 steps 4 and 6 for exact formats.
3. **Recaps** (one paragraph at the end of each phase): *"I bumped the Stark deal to Contract stage. Ping me when Tony signs."*

Skip these:

- ❌ Long explanations of the AI generation pipeline ("first I generate a doc ID, then clauses, then persist the AI source…").
- ❌ Listing every command you ran.
- ❌ Fake suspense ("Let me check…") — just do the check silently.

## What This Flow Does NOT Do

- ❌ **Edit contract clauses via CLI** — the AI generates them on creation; tweaks happen in editor URL #1. The CLI exposes no clause-edit verb.
- ❌ **Attach signer via CLI** — signer attachment happens in editor URL #2 (after `contract finalize`). The `--signer` flag no longer exists on `contract finalize`.
- ❌ **Send the contract via CLI** — `bookipi contract send` is not called by this skill flow. The send action happens in editor URL #2. The CLI command still exists for power users.
- ❌ **Recall a sent contract** — once the user sends from the web editor and the contract is `pending_signature`, the email is on its way. No unsend.
- ❌ **Track signature progress in real-time** — the agent reads `contract list --status signed` on demand; there's no webhook or polling. If the user asks "did Tony sign yet?", the agent runs the check fresh.
- ❌ **Send reminders to non-signing recipients** — no contract-reminder verb exists yet. If the user wants to nudge, they do it via email outside the agent.
- ❌ **Generate a contract without an accepted proposal** — the entry point is `contract create-from-proposal`, which requires a proposal. If the user wants a standalone contract, they should use the web app directly.
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
