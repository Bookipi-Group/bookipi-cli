# Quick Quote — Half 1 (proposal generate + send) + Half 2 (proposal → invoice)

The proposal-and-close flow that **every** sale starts with — regardless of whether it ends in a signed contract. Half 1 (pre-acceptance) is **identical** for Flow 2 (no contract) and Flow 1 (with contract). The flow only forks **after** the customer accepts the proposal.

> ## ⚠️ This is the entry point for ALL proposal-related work
>
> **Always load this doc first** when the user wants to draft, edit, or send a proposal — even if their prompt mentions "contract", "agreement", "MSA", or "sign". Reasons:
>
> 1. The contract step requires an **accepted** proposal as input. Acceptance happens externally (the customer clicks a link in their email). You can't bridge it in one session.
> 2. Drafting the contract preemptively (before acceptance) wastes ~25-30s of AI generation if the customer rejects.
> 3. Half 1 is identical for both flows — duplicating it across docs creates routing confusion.
>
> **Examples that ALL route here**, not to `win-deal.md`:
>
> - *"Draft a proposal for Bruce for ₱500K"* → Half 1
> - *"Draft a proposal **and contract** for Bruce"* → Half 1 only (mention contract in your phase-end recap; tell the user the contract waits for acceptance)
> - *"Quote Acme for the website redesign — they'll need an MSA"* → Half 1 only (same)
> - *"Send Tony a proposal, we'll need it signed"* → Half 1 only
>
> **Only after the customer accepts** does the flow fork:
>
> - *"Bruce accepted, draft the contract"* → load `win-deal.md` (Phase 2 — contract draft + send + signing)
> - *"Bruce accepted, send the invoice"* → stay here, run Half 2 (invoice direct, no contract)
>
> If the user's post-acceptance prompt is ambiguous (just *"Bruce accepted"* or *"close it out"*), **ask one targeted question via `AskUserQuestion`** (see `common.md` § Confirmation Style): *"Want me to draft a contract for sign-off first, or invoice direct?"* with choices `["Invoice direct", "Draft contract first", "Not yet"]`.

This skill orchestrates seven mutations across four entities (customer, deal, proposal, invoice) with explicit confirmation gates and branch logic.

> ## ⚠️ Critical confirmation rules — read before invoking any mutation
>
> Three commands in this flow are **destructive** (real customer-visible side effects). The agent **MUST** present a plain-language summary and get explicit user approval before each:
>
> 1. **`proposal send`** — sends a real email. Confirm: who's it going to, what's the subject, what's the amount?
> 2. **`invoice send`** — same. Confirm: recipient, total, due date.
> 3. **`deal update --key closed_win`** — moves the deal to a terminal stage. Confirm: did the customer actually pay / sign off, or are we marking it prematurely?
>
> Three more are **mutations but reversible / quiet** (no email goes out). Run them without confirmation:
>
> 4. **`proposal generate`** — creates a draft. Reversible (drop / regen).
> 5. **`proposal update`** — edits a draft.
> 6. **`invoice create-from-proposal`** — creates the invoice but doesn't send it. Reversible (delete invoice).
>
> **Never skip the confirmation gates above.** It's the difference between a useful agent and one that fires a customer email by mistake.

## When to Trigger This Flow

Strong signals (clear intent to close a sale) — **two flavours, same flow**:

**Description-anchored** (user provides the scope):

- "Draft a proposal for Acme Corp for the website redesign at $50k"
- "Send Maria a proposal for the maintenance retainer"
- "Quote Beta for our standard SEO package"

**Meeting-anchored** (user references a recent meeting):

- "Draft a proposal from my meeting with Maria yesterday"
- "Use the Acme discovery call notes to write the proposal"
- "Based on our chat with Beta, draft a proposal"

**Mid-flow re-entries** (jump straight to a later step):

- "Maria just accepted — let's close it out" *(jumps to post-acceptance half)*
- "Create an invoice from Proposal-169" *(jumps to conversion step)*
- "Mark the Acme deal as won" *(final stage only)*

**Trigger this flow specifically when:**
- The user is in proposal-create-or-send mode for a single customer.
- The customer's deal value or context implies a contract is **not** required (small / repeat / known relationship). If a contract is needed, switch to Flow 1 (Win Deal).

**Do NOT trigger** when the user wants to:
- Send a reminder for an existing invoice → use `invoices.md`
- See pipeline status → use `morning-brief.md` or `customer-360.md`
- Edit a proposal that's already been sent without the user explicitly asking → ask first

## The Flow

Two halves separated by an external waiting period (customer accepts the proposal). Don't try to bridge them in a single conversation.

### Two entry paths into Half 1

Half 1 starts in one of two ways. **Detect which path applies before doing anything**, because the proposal description's source differs:

**Path A — Meeting-anchored.** The user references a meeting that already happened. Examples:

- *"Draft a proposal from my meeting with Maria yesterday"*
- *"Maria and I just discussed an SEO project — write up a proposal"*
- *"Use the Acme call notes to draft the proposal"*
- *"Based on our discovery call with Beta, draft a proposal"*

→ The agent reads the meeting record, extracts what was discussed, and feeds it into the proposal description.

**Path B — Description-anchored.** The user describes the scope themselves, no meeting referenced. Examples:

- *"Draft a proposal for Maria for ₱75K covering SEO support"*
- *"Send Acme a proposal for a website redesign at $50K, 3-month timeline"*
- *"Quote Beta for our standard maintenance retainer"*

→ The agent uses the user's prompt directly as the proposal description.

**Both paths converge at the same downstream flow** (find/create deal → generate → confirm → send → advance stage). Only step "0" differs.

### Step 0 — Detect entry path and gather proposal context

**A.1 — Look for explicit meeting references** in the user's prompt:

- Customer name + recent time reference: "Maria yesterday", "the Acme call this morning"
- Phrases like: "from our meeting", "we discussed", "based on the call", "from the notes", "what we talked about", "the discovery call"
- Direct mentions of a meeting handle (`@m1`)

If any of these signals fire → **Path A.** Skip to A.3.

**A.2 — When the prompt is description-anchored** (Path B), do a *quick proactive check* before defaulting to it. **Use `--search`** — the CLI auto-widens the window to past 365 days + future 30 days when this flag is set AND paginates through all matching pages (the meet-app API caps page size at 100, so a busy account can hide matches past page 1). You don't need the past-date trick or the page-bumping trick anymore.

```bash
# Search by counterpart email (the most reliable):
bookipi meeting list --search "tonystark@yopmail.com" --json   [AUTO]
```

> **Heads up: name search rarely finds meetings.** The meeting record stores the counterpart's *email* but **not** their name (the `customer` field on a meeting is the booking-link OWNER, i.e. you, not the prospect). So `--search "Tony Stark"` will only match if "Tony Stark" appears in the booking title, the guest list, or the host's own name — none of which is reliable.
>
> **Pattern when the user gives you a name, not an email:**
>
> 1. `bookipi customer list --search "Tony Stark" --json` → get the customer record's email
> 2. `bookipi meeting list --search "<that email>" --json` → find the meeting
>
> Issue both as a single parallel batch when you can to save a turn.

If matches come back, look for transcript content (`transcription.meetingSummary.text` or `notes` or `questions[]`).

If a recent meeting with the named customer exists and has useful content (transcript, notes, or `questions[]`), **suggest Path A once via `AskUserQuestion`** (see `common.md` § Confirmation Style):

- **Question:** *"I see you had a call with Maria yesterday morning. Use what you discussed, or just the scope you described?"*
- **Choices:** `["Use the meeting", "Use my description", "Show me the meeting first"]`

On "Use the meeting" → Path A. On "Use my description" → Path B. On "Show me the meeting first" → surface the transcript / summary, then re-ask once. **Don't ask twice past that.** If no recent meeting exists, proceed with Path B silently.

**A.3 — Path A: extract proposal context from the meeting**

> **⚠️ Meeting data-model gotcha (read this once, save yourself a debugging session):**
>
> In a meeting record, the **top-level `email`** is the **counterpart** — the prospect / customer you booked with. The nested `meeting.customer` object is the **booking-link owner** (i.e., you, the Bookipi user). Don't be fooled by the `customer` field name.
>
> When matching a meeting to a customer email/name:
>
> - **Counterpart's email** → `meeting.email` (top-level)
> - **Counterpart's name** → look this up in the CRM by querying `customer list --search "<meeting.email>"` — the meeting record itself doesn't store the counterpart's name
> - **Booking-link owner** (ignore for proposal flows) → `meeting.customer.firstName/lastName/email`
>
> Also: by default `meeting list` shows only TODAY's window. To find **past** meetings (where transcripts live), use `--search <email-or-name>` — the CLI auto-widens the window to past 365 days + future 30 days when this flag is set, and filters results client-side. Don't try to memorize date arithmetic; just pass `--search`.

Look up the meeting via `bookipi meeting list --search "<email>" --json` (it returns transcripts inline). Pull content in this order of preference:

| Source field | Why it matters |
|---|---|
| `transcription.meetingSummary.text` | Polished AI summary — usually the best single source |
| `transcription.meetingSummary.notes` | More detailed AI notes |
| `transcription.meetingSummary.actions` | Action items the customer expects |
| `questions[]` | Booking-form Q&A (e.g. "What do you need?" → "A new website") — gold for AI prompts |
| `notes` | Free-form user notes |
| `summary` | Manual user summary |
| `name` + `link.title` | Last resort — at least labels the engagement |

Combine the available signals into a structured description like:

```
Based on our [meeting type] with [customer] on [date], where we discussed:
[summary text + notes].
The customer indicated they need: [from questions or actions].

Write a professional proposal covering: [scope inferred from above].
```

If the meeting has no transcript and no useful fields, **fall back to Path B**: ask the user to describe the scope.

**A.4 — Path B: use the user's prompt as the description**

The user's prompt already contains the scope. Construct a clean prompt from it:

```
Write a professional proposal for [customer] covering [scope from user prompt].
[Optional: timeline / pricing / specific deliverables from user prompt.]
```

This is the path the agent has been using successfully. Nothing changes.

### Half 1 — Pre-acceptance (one user session)

> **Rule: every proposal MUST live inside a deal.** Don't generate orphan proposals. If a deal doesn't exist for the customer, **create one first** — `deal create` is a CLI command (no fallback to the web app needed). Skip the deal step only if the user explicitly says "no need to track this in the pipeline" — and even then, ask once before honouring it.

> **Performance rule: issue independent lookups in a single parallel batch.** Steps 1 and 2 (customer-resolve + deal-find) don't depend on each other once you have the customer email. Send both `bookipi customer list` and `bookipi deal list` as **one batch of parallel tool calls**, not two sequential turns. This saves ~1 second of API + a full LLM-thinking turn. Same applies to per-customer queries elsewhere in the flow.

```
User: "draft a proposal for Maria for ₱75k SEO retainer"

1+2. Resolve customer AND find any open deal — IN PARALLEL
   bookipi customer list --search "Maria" --json    [AUTO]
   bookipi deal list --search "Maria" --status leads --json     [AUTO]
   → (issue these as a SINGLE BATCH, not sequentially)

   Why --status? Without a --status filter, `deal list` fans out across
   ALL 7 stages internally (7 parallel API calls, ~2.7s wall-clock). When
   you're looking for a deal at a specific stage, pass --status to do a
   single call (~0.8s). Default Path A is "is there an open deal in early
   stages" — try `--status leads` first, fall back to `qualified` or
   `meeting` only if no match. If the user said "the deal we discussed
   last week" you might already know the stage.

   After both return:
   - Customer found → use it. (If no match: see "Customer doesn't exist".)
   - Deal lookup result has 3 branches:
     a. Exactly ONE open deal that fits → use it.
     b. MULTIPLE open deals → ask the user which one, e.g.
        "Maria has 2 open deals — 'Maria — Website redesign' (Proposal stage,
         ₱100K) and 'Maria — Maintenance' (Leads, no value). Which is this
         proposal for, or should I create a new deal?"
     c. NO open deal that fits → create one:
        bookipi deal create \
          --customer @c6 \
          --name "Maria Chen — SEO retainer" \
          --value 75000 \
          --description "3-month SEO engagement, content + reporting"  [AUTO]
        → @d78 created at stage `leads`.

3. **Narrate before the slow step** (see common.md § Progress Narration):
   Tell the user one short message recapping what you found AND what's next:
   "Found Maria's customer record + opened a new deal. Generating the
    proposal — **about 15 seconds.**"
   Then run:
   bookipi proposal generate \
     --description "Write a proposal for Maria Chen at Acme covering 3-month SEO retainer with monthly reporting and content optimization." \
     --customer @c6 \
     --deal @d78 \
     --item '{"name":"SEO retainer","price":75000,"quantity":1}' \
     --expires-in 30                                 [AUTO ~15s]
   → @p15 created, status=draft, attached to @d78.

4. Show the draft to the user — use the **summary + clickable-link** pattern.

   The `proposal generate` command's output includes a `🔗 Review or edit: <url>`
   line — that's the Bookipi web-app edit URL. Surface it as an **inline**
   markdown link on its own line at the END of the message (never mid-sentence,
   and never reference-style — some clients render `[label][1]` as dead text) —
   see SKILL.md § User-Facing Presentation Rules (T-17).

   > **⚠️ Use the right number field for the user-facing recap.** The API
   > returns two number-like fields:
   >
   > - **`title`** — auto-generated as `"Proposal - N"`, where `N` is the
   >   user's per-account counter. **This is what the web app shows** ("Proposal-3").
   > - **`no`** — a global cross-tenant counter (e.g. `19073`). The web app
   >   does NOT show this. Mentioning it confuses users.
   >
   > **In your recap, surface the number from `title` (or just print the
   > title verbatim).** The CLI's formatted markdown output already does this
   > correctly — its "Number" line shows the per-account value. If you read
   > `--json`, parse `title` for the digits, never read `no` for display.

   Format the chat reply roughly like this (tailor to the actual data):

   ```markdown
   ✅ Drafted **Proposal-176** for **Maria Chen** — ₱75K SEO retainer, expires June 3.

   **Quick summary:**
   - 1× SEO retainer @ ₱75,000
   - 3-month engagement
   - Includes monthly reporting + content optimization
   - Tied to deal: *Maria Chen — SEO retainer* (now at Proposal stage when sent)

   **🔗 [Review or edit the full proposal][proposal]**

   Want me to send it as-is, or adjust something first?

   [proposal]: <the edit link printed by the CLI>
   <!-- Reference-style: the label sits inline, the long URL goes in this
        definition at the very END of the message so it doesn't stream
        character-by-character mid-reply (T-17). Always use the 🔗 link from the
        CLI's own output — the domain differs per environment (staging
        ac-app.bkpi.co, prod web.bookipi.com) and the CLI always prints the
        right one. Never construct it by hand. -->
   ```

   Why this pattern: the chat summary answers "is this roughly right?" without
   making the user leave the conversation. The clickable link gives them the
   full Bookipi UI for visual review and edits when they want them. **Don't**
   try to download / iframe / re-render the proposal in chat — the rich design
   only renders properly in the web app.

5. User reviews — possible responses:
   a. "Looks good, send it"     → step 6
   b. "Make it ₱60K instead"    → bookipi proposal update @p15 --data '{...}' [AUTO]
                                  Also update the deal value:
                                  bookipi deal update @d78 --value 60000   [AUTO]
                                  Loop back to step 4.
   c. "Cancel that"             → bookipi proposal update @p15 --data '{"isDraft":true}'
                                  (Don't auto-delete the deal — leave it for
                                  the user to clean up or reuse.)

6. [USER CONFIRM via `AskUserQuestion`] — see `common.md` § Confirmation Style.
   Put the specifics in the **question**, keep the **choices** short:

   **Question:** *"Send Proposal-176 to mariachen@yopmail.com? — ₱75K, 'Proposal — SEO retainer', expires June 3, deal: Maria Chen — SEO retainer."*
   **Choices:** `["Send now", "Edit subject/message first", "Cancel"]`

   On "Send now" → step 7.
   On "Edit subject/message first" → ask one targeted free-text follow-up
   to capture the new `-s` / `-m` values, then loop back to this step.
   On "Cancel" → stop. Don't auto-delete the proposal draft.

7. On approval:
   bookipi proposal update @p15 --no-draft           [AUTO]   (draft → saved)
   bookipi proposal send @p15 -r mariachen@yopmail.com \
     -s "Proposal — SEO retainer" \
     -m "Hi Maria, here's the proposal we discussed..." \
     --advance-deal                                  [DESTRUCTIVE]
   → status=sent. The `--advance-deal` flag also bumps the linked deal to
     `proposal` stage automatically (only if it's not already there or past).
     See common.md § Deal Stage Auto-Progression for the precedence rules.

8. Recap to user (one paragraph). Pull the 📍 "Deal moved" line from the
   send command's output. **Keep this factual — no monitoring promises.**
   Step 9 is what actually sets up monitoring; the recap shouldn't imply
   it's already happening.

   *"Sent Proposal-176 to Maria for ₱75K. Deal moved to Proposal stage. When she accepts, just tell me — say 'invoice her' for the direct path, or 'draft the contract' if you want it signed first."*

   The both-branches mention at the end is important: the user needs to know
   what to say later to trigger the right post-acceptance flow (Half 2 here
   vs `win-deal.md` Phase 2 for the contract path).

   ❌ Don't say *"I'll let you know when she responds"* unless Step 9 has
   actually scheduled a check. That phrase makes the user think the agent
   is watching — but without a scheduled task, the agent can't act
   asynchronously.

9. **Schedule a reminder — default-on, but check for an existing one first.**
   This is NOT optional. Proposals get forgotten if no one's watching, and
   the agent CAN'T notify the user asynchronously without a scheduled task.
   Run this step after every successful `proposal send`.

   **9a. Check existing scheduled tasks first** (idempotency). Call
   `mcp__scheduled-tasks__list_scheduled_tasks` and look for any task whose
   prompt or title contains this proposal's `_id`, the proposal handle
   (e.g. `@p15`), or the customer's email. Use the immutable `_id` as the
   primary key for matching — handles can re-register, emails can change.

   **9b — Existing task found.** Don't re-ask. Tell the user it's already
   being watched, then offer to adjust via `AskUserQuestion`:

   > *"Already watching Proposal-176 — checking daily. Want to change that?"*
   >
   > Choices: `["Keep daily", "Switch to once-on-expiry (Jun 3)", "Stop watching", "Show me what's set"]`

   On "Switch" → call `mcp__scheduled-tasks__update_scheduled_task` to flip
   the cadence. On "Stop watching" → call the delete equivalent (or update
   to disabled). On "Show me what's set" → surface the task's prompt and
   next-fire time. On "Keep daily" → no-op, brief acknowledgement.

   **9c — No existing task.** Use `AskUserQuestion` to offer monitoring:

   > *"The proposal's out. Want me to keep an eye on it?"*
   >
   > - **(a)** *"Yes — once on its expiration date (Jun 3)"* → one-shot at `expirationDate`
   > - **(b)** *"Yes — daily until she responds"* → daily cron, auto-stop on accept/decline/expire
   > - **(c)** *"No — I'll check the morning brief or ask later"* → no-op

   For (a) and (b), call `mcp__scheduled-tasks__create_scheduled_task` with:

   - **Title**: `"Proposal monitor — <customer name> Proposal-N (<proposalId>)"` so 9a's lookup can find it next session.
   - **Schedule**: one-shot at `expirationDate` (a) or daily cron (b).
   - **Prompt**: re-enter this skill with something like *"Check if Proposal-N (`<proposalId>`) for `<customer>` has been accepted or declined. If accepted, ask the user via `AskUserQuestion`: 'want to invoice direct, or draft the contract for sign-off?' — choices `['Invoice direct', 'Draft contract', 'Not yet']` — then route to Half 2 or `win-deal.md` Phase 2 accordingly. If declined, suggest `closed_lose`. Otherwise stay silent."*

   **9d — Skip the entire step (don't ask, don't check)** when:

   - The user already said they'd handle follow-up themselves in this session
     ("I'll check tomorrow", "no need to remind me").
   - The proposal has no `expirationDate` AND no useful daily-check window —
     extremely rare, but in that case skip silently and rely on morning-brief.

   **9e — MCP graceful fallback.** If `mcp__scheduled-tasks__list_scheduled_tasks`
   or `create_scheduled_task` aren't available in this Cowork build (some
   plugin manifests don't include the scheduled-tasks MCP), gracefully fall
   back: tell the user *"This Cowork build doesn't have a scheduler wired
   up — I'll surface this in your next morning brief instead. Just ask 'any
   update on Maria?' if you want to check sooner."* Don't pretend to
   schedule something you can't.
```

**End of half 1.** The conversation ends here. The flow resumes externally when the customer accepts (or the user says she did).

### Half 2 — Post-acceptance (separate user session)

Trigger: user says "Maria accepted", or the agent reads `proposal list --status accepted --search "<customer>"` during a `morning-brief` and detects a freshly-accepted proposal.

```
1+2. Confirm acceptance AND check for idempotency — IN PARALLEL
   bookipi proposal list --search "Maria" --status accepted --json   [AUTO]
   bookipi invoice list --status saved,sent,read --json              [AUTO]
   → Issue these as a single batch.
   → After both return:
     - Find the accepted proposal in the first response.
     - If any invoice has `proposalId === <accepted proposal._id>`: skip
       conversion, tell the user: "Already converted to INV-XXX. Want me
       to send it?" Then jump to step 4.

3. Convert to invoice
   bookipi invoice create-from-proposal @p15         [AUTO]
   → @i7 created with same items, customer, totals. Note: projectPipelineId
     is NOT auto-set on the invoice — the deal-invoice link is implicit
     through the proposal. That's fine for normal flow.

4. [USER CONFIRM via `AskUserQuestion`]:

   **Question:** *"Created INV-657 — ₱75K, due in 15 days. Send to Maria now?"*
   **Choices:** `["Send now", "Edit message first", "Hold for later"]`

5. On "Send now":
   bookipi invoice send @i7 -r mariachen@yopmail.com \
     -s "Invoice INV-657 — SEO retainer" \
     -m "Hi Maria, attached is the invoice for the SEO retainer..."   [DESTRUCTIVE]

6. [USER CONFIRM via `AskUserQuestion`]:

   **Question:** *"Mark the Maria Chen — SEO retainer deal as Closed Won? (₱75K)"*
   **Choices:** `["Yes — close-won", "Not yet, leave it open", "No — closed-lose instead"]`

   The third option is a defensive escape hatch for the case where the
   user mis-said "close it out" when they meant the customer declined.

7. On "Yes — close-won":
   bookipi deal update @d57 --key closed_win         [DESTRUCTIVE — terminal stage]

   On "No — closed-lose instead":
   bookipi deal update @d57 --key closed_lose --data '{...}' (offer to capture closeReason)

8. Recap:
   "Closed-won the Maria deal. INV-657 (₱75K) is out for collection."
```

## Branching — All Possible Paths

Half 1 can end with the user dropping out (no send). Half 2 has more branches:

| Customer response | Flow direction |
|---|---|
| **Accepted** | Run half 2 as documented |
| **Declined** | `bookipi deal update <dealId> --key closed_lose` after USER CONFIRM. Optionally `--data '{"closeReason":"..."}'` if available. The proposal stays at `declined` — no need to delete it. |
| **Asked for changes** | Loop back to half 1 step 4 — `proposal update`, then re-confirm send. The proposal stays at the same `_id`, status flips back to `saved` when re-sent. |
| **No response after N days** | Stalled. The morning brief surfaces this in Pipeline Highlights. The agent can suggest a nudge, but **don't auto-send a follow-up** without explicit user request. |
| **User says "cancel that"** | `proposal update <id> --data '{"isDraft":true}'` to revert to draft, or `bookipi proposal delete <id>` to trash it outright (soft-delete — confirm first, it's destructive). Optionally move the deal back to `qualified` or `closed_lose`. |

## Customer / Deal Doesn't Exist

These two edge cases handle the "starting from scratch" scenarios:

### "Draft a proposal for John Smith" (new customer)

1. `customer list --search "John Smith"` → 0 results.
2. **Ask the user**: "I don't have John Smith on file. What's the company name and email? I'll create him before drafting."
3. On reply: `customer create --first-name "John" --last-name "Smith" --email "..." --company "..."`
4. Then proceed with `proposal generate --customer @c<n>`.

Don't auto-create the customer with empty fields — the proposal will look weird without an email at minimum.

### "Customer exists but has no open deal"

This is **not** an edge case anymore — it's the normal path for a brand-new sale. Step 2 of the flow handles it: when no open deal fits, `deal create` runs automatically. The user doesn't have to ask for it; the agent does it as part of "draft a proposal for X". Reference: see [step 2.c](#half-1--pre-acceptance-one-user-session) in the main flow.

The agent should pick a sensible deal name from the user's prompt — usually `<Customer> — <short scope description>` (e.g., "Maria Chen — SEO retainer"). Don't get fancy; deals can be renamed later.

### "User explicitly wants to skip deal tracking"

Rare but possible: *"just draft a quick proposal for Maria, no need to track this in the pipeline."* In that case, drop the `--deal` flag from `proposal generate` and skip the deal-create step. **Confirm once with the user before honouring it** — orphan proposals are easy to forget about, so the default should always be to create a deal.

## Idempotency — Don't Re-Do Work

The agent might run a flow step multiple times (scheduled re-checks, conversation restarts). Always check current state before mutating:

| Before running… | Check… |
|---|---|
| `proposal generate` | The user might already have a recent draft for this customer (`proposal list --search <name> --status draft`). If one exists from the same session, ask whether to use it or generate fresh. |
| `proposal send` | If `proposal.status === "sent"`, it's already sent. Don't re-send unless the user explicitly asks ("re-send it" / "send a new copy"). |
| `invoice create-from-proposal` | Look for `invoice` records with `proposalId === <proposalId>`. If one exists, **don't re-convert** — surface the existing invoice instead. |
| `invoice send` | `invoice.computedStatus === "sent"` or `read` — already sent. Confirm before re-sending. |
| `deal update --key closed_win` | If `deal.status === "closed_win"` already, skip. Just confirm to the user that it's already done. |

## What to Tell the User Throughout

The agent sends three kinds of messages during this flow:

1. **Status updates** (one-line, factual, after each non-destructive step): *"Drafted Proposal-176, ₱75K, draft status — ready for your review."*
2. **Confirmation prompts** (before every destructive op, with concrete details): *"I'll send this to mariachen@yopmail.com — proceed?"*
3. **Recaps** (one paragraph at the end of each half): *"Sent Proposal-176 to Maria. Deal moved to Proposal stage. I'll let you know when she responds."*

Skip these:
- ❌ Long explanations of what the CLI is doing under the hood
- ❌ Listing every command you ran ("I ran proposal generate, then proposal update, then…")
- ❌ Fake suspense ("Let me check…") — just do the check silently, then report the result

## Confirmation Gate Style

When asking for confirmation, give the user the **specifics** to evaluate, not a vague "OK to proceed?". Three lines:

```
I'll send Proposal-176 to mariachen@yopmail.com:
  • Subject: "Proposal — SEO retainer"
  • Total: ₱75,000 (3-month engagement)
  • Expires: June 3
Send now?
```

If the user wavers ("uhh, hold on"), pause. Don't infer approval from anything other than a clear yes.

## What This Flow Does NOT Do

- ❌ **Generate a contract** — that's Flow 1 (Win Deal). If the customer needs an MSA, switch flows.
- ❌ **Auto-decide whether to use Flow 1 or Flow 2** — the user / customer profile makes that choice. The skill can suggest based on heuristics (deal value > some threshold, customer has `requiresContract: true`, etc.) but doesn't decide silently.
- ❌ **Chase non-responses** — if the customer doesn't respond, that's Flow 3 (Stalled Recovery — `stalled-recovery.md`). Don't auto-trigger it from here. (The optional reminder in step 9 is *passive* — it pings the user, not the customer.)
- ❌ **Handle invoice payments** — once the invoice is sent, payment tracking happens elsewhere (`invoice list --status paid` etc.). Out of scope.
- ❌ **Send marketing-style follow-ups** — every email this flow sends is transactional and customer-initiated. No nurture, no drip.

## Duplicating / Reusing a Proposal

*"Duplicate that proposal"*, *"make another like Proposal-201"*, *"reuse the Acme proposal for Beta"* → `bookipi proposal duplicate <handle-or-id>`.

The server creates a **fresh editable draft** copy — same title, line items, terms, and tax/discount settings — with its own new `_id` and number, `isDraft: true`. A copy is never auto-sent, even if the source was already sent or accepted. The command registers a handle for the new draft and prints its `🔗 Review or edit` link.

Typical follow-ups after duplicating:
- *"point it at a different customer"* → `bookipi proposal update <new-handle> --customer <name-or-handle>`.
- *"change the price / items"* → edit via the link, or `bookipi proposal update <new-handle> --data '{…}'`.
- *"send it"* → `bookipi proposal send <new-handle> -r <email> --advance-deal`.

Don't want the copy after all? `bookipi proposal delete <handle-or-id>` soft-deletes it (moves to trash). It's destructive — **confirm with the user via `AskUserQuestion` before deleting** (see `common.md` § Confirmation Style). Or just leave the draft; it won't be sent on its own.

## Cross-References

- Customer + deal context → `customer-360.md`
- Detecting an accepted proposal during a daily check → `morning-brief.md` (Pipeline Highlights section)
- The reasons we query proposals separately even when looking at a deal → `morning-brief.md` (Why all four per-customer queries are needed)
- Stable status keys for deals → `common.md` and the agent-flows.md root doc
- Disambiguation when "Maria" matches three customers → `common.md` (Disambiguation section)
