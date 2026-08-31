# Common Reference — Handles, Output, Errors

## Working Efficiently

The operational efficiency rules (trust the docs, reuse handles/data, skip trivial task-tracking, minimum happy path, command routing, calendar pre-check) live in **SKILL.md § Working Efficiently** — it's always loaded, so it's the single source of truth. This doc doesn't restate them.

## The Handle System — INTERNAL USE ONLY

The CLI uses short handles (`@i1`, `@c1`, `@t1`, `@e1`) as aliases for long MongoDB IDs. Handles dramatically reduce LLM copy-paste errors from ~5% to ~0.1%:

- **@i** = invoice, **@c** = customer, **@t** = line item, **@e** = email
- Handles are **automatically registered** when you run commands that display resources (like `list` or `get`)
- Handles **persist across CLI sessions** in `~/.bookipi/handles.json` (alongside the auth credentials). Older installs may still have them at `~/.bookipi-handles.json`; the CLI migrates automatically on first read.
- You can use either a handle or a raw ID in **any command**

**Handle Availability:**

- Handles from previous sessions are immediately available
- If a handle doesn't exist, you'll get an error: "Handle @i1 not found"
- Solution: Run `bookipi invoice list` first to register handles

**CRITICAL — User-Facing Presentation:**

Handles are an **internal tool for the LLM only**. The user does not know what `@i25` or `@c1` means. When presenting information to the user:

- **NEVER** show handles like `@i1`, `@c1`, `@t1` in your responses to the user
- **NEVER** show raw CLI commands (e.g., `bookipi invoice send @i1`) to the user
- **ALWAYS** refer to invoices by their **invoice number** (e.g., "INV-650"), **customer name**, and **amount**
- **ALWAYS** refer to customers by **name** (e.g., "Kelvin Bookipi"), not by handle
- Use handles silently in CLI commands behind the scenes — the user should never see them
- When suggesting actions, describe them in plain language (e.g., "I can resend the $5,000 invoice to Kelvin NewX") instead of showing raw CLI commands

**Example — BAD (don't do this):**
> - @i21 to Kelvin Bookipi — $5,000 still due. Send reminder: `bookipi invoice send @i21 -r email@test.com`

**Example — GOOD:**
> - **INV-626** to **Kelvin Bookipi** — $5,000 still due on a $10,000 invoice (due Apr 5). Want me to send a reminder?

## Output Format

**Default: Human-Readable Markdown**

The CLI outputs formatted markdown with handles embedded for easy copy-paste in follow-up commands. Example:

```markdown
# Invoice INV-650 [@i1]
- Customer: John Doe [@c1]
- Status: Sent | Payment: Not Paid
- Total: $500.00 | Due: $500.00
```

**When to Use `--json` Flag:**

- You need to extract specific fields programmatically
- You're aggregating data across multiple invoices
- You need raw API data for complex calculations

**Presenting Results to Users:**

- Summarize naturally — don't dump raw CLI output
- Highlight key information (totals, overdue status, customer names)
- **NEVER show handles** or raw CLI commands to the user
- Suggest next actions in plain language

## Global Flags

- `--json` — Return raw JSON instead of formatted markdown

## Currency

The CLI formats all amounts in the authenticated user's company currency
(pulled from the whoami response and cached in `~/.bookipi/credentials.json`).
**Do not say "$" when summarising amounts** unless the company currency is USD
— let the CLI's formatted output speak for itself, or echo whatever symbol it
printed.

Precedence (first hit wins):

1. `BOOKIPI_CURRENCY` env var override (e.g. `BOOKIPI_CURRENCY=PHP`).
2. Cached per-company map under `companyCurrencies` in `credentials.json`,
   populated on `login` / `whoami`.
3. `USD` fallback.

If the user complains that amounts still render with `$` after a currency
change, run `bookipi whoami` — it refreshes the cached currency map.

## Error Handling

The CLI emits errors in a consistent format on stderr — the agent should **pass these through to the user verbatim** (they're already user-friendly) and act on the hint line if one is present.

**Default (markdown) format:**

```
❌ <Friendly summary of what went wrong>

💡 <Action hint: what the user / agent should do next>
```

**`--json` flag** (when the agent wants machine-readable output):

```json
{"success": false, "error": "...", "code": "<category>", "hint": "..."}
```

### Error categories the formatter recognises

| Category (`code`) | Markdown summary | Hint | Exit |
|---|---|---|---|
| `auth` | *Your Bookipi session expired (or you're not logged in).* | *Re-run the login flow (`bookipi login --relay-start`, then `--relay-wait`), then retry the command.* | 2 |
| `no-company` | *No company is set as your default.* | *Run `bookipi whoami` after logging in to refresh the default company.* | 2 |
| `network` | *Couldn't reach Bookipi (network issue).* | *Check your connection and try again in a moment.* | 1 |
| `timeout` | *Request timed out.* | *The service might be slow — try the command again.* | 1 |
| `rate-limit` | *Hit Bookipi's rate limit.* | *Wait ~30s and retry.* | 1 |
| `handle-not-found` | *Handle @X isn't registered.* | *Run the matching `list` command (e.g. `bookipi invoice list`) to register handles in this session.* | 3 |
| `not-found` | *Record not found (it may have been deleted, or the ID is wrong).* | *Run the appropriate `list` command to find a valid ID/handle.* | 3 |
| `validation` | *(passes through, e.g. "Invalid --status value")* | — | 3 |
| `upload` | *File upload failed.* | *Retry the command. If it keeps failing, the file might be too large or the network unstable.* | 1 |
| `graphql` | *(stripped of "GraphQL Error:" prefix)* | — | 3 |
| `unknown` | *(raw error message)* | — | 1 |

### How the agent should react

1. **Auth errors** (`code: "auth"`) — silently re-trigger the login flow (`bookipi login --relay-start`, then `--relay-wait`), then re-run the original command. Don't abandon the user's task.
2. **Handle-not-found / not-found** — run the suggested `list` command silently, then retry. If still missing, surface the issue plainly: *"I can't find that record — it might've been deleted."*
3. **Network / timeout / rate-limit** — wait briefly and retry once. If it fails again, surface the hint to the user.
4. **Validation** — these are user-input issues. Surface the message + hint plainly and ask for the right value via `AskUserQuestion` if possible.
5. **Unknown** — surface as-is. If `BOOKIPI_DEBUG=1` was set, the markdown also includes a `_(Debug: <raw>)_` footer for troubleshooting.

**Null Safety:** The CLI handles incomplete API responses gracefully. "N/A" or empty fields mean the API didn't return that data — that's data-shape, not an error.

## Common Spot-Checks — What to Look At

When the user asks a quick yes/no or status question, here's the field on each entity to inspect. Run the relevant `list` command (often with `--search` or by handle) and read the indicated field from the JSON.

| User asks… | Look at | Returns |
|---|---|---|
| "Did Maria view the proposal?" | `proposal.viewedDate` (or `status === "read"`) | Truthy / null |
| "Did the proposal get accepted?" | `proposal.status === "accepted"` + `proposal.clientSignedDate` | true / false |
| "Is the proposal expired?" | `proposal.expirationDate` < today | yes / no |
| "Is invoice INV-203 paid?" | `invoice.computedStatus` (`paid`, `partialPaid`, `overdue`, `sent`, …) | one of the statuses |
| "How much does Acme owe me?" | sum `amountDue` across invoices for that customer where `computedStatus !== "paid"` | total |
| "When did they last pay?" | most recent `invoice.payments[].date` for that customer | date |
| "Has the contract been signed?" | `contract.status === "signed"` (or `signedFile` is set) | yes / no |
| "Has the contract been viewed?" | `contract.latestAction` mentions a view/open event | yes / no |
| "Who's the recipient on this contract?" | `contract.recipients[]` — `fullName` + `email` + `role` | list |
| "What stage is the deal in?" | `deal.status` — stable key (`leads`, `qualified`, `meeting`, `proposal`, `contract`, `closed_win`, `closed_lose`) | the key |
| "What's the deal worth?" | `deal.value` | currency |
| "When was the last activity on the deal?" | `deal.updatedAt` | date |
| "When's the next meeting with X?" | `bookipi meeting list --days 30 --json` then filter by customer email | meeting record |
| "Was the meeting transcribed?" | `meeting.hasAiSummary` and `meeting.transcription.meetingSummary.text` | yes / no + text |

Rules when answering:

1. **Show the user's `label`, not the internal `key`.** "Stage: Quote Sent" not "Stage: proposal". (See [agent-flows.md](../../../../agent-flows.md) on stage `key` vs `label`.)
2. **If the field is empty or null, say so honestly** ("not viewed yet" rather than guessing "no" or "maybe").
3. **Never invent a status** — if the API didn't return the field, surface that ("the API didn't return a viewed timestamp — viewing isn't reliably tracked here").
4. **Translate dates into the user's frame of reference**: "viewed yesterday at 3pm" beats "viewedDate: 2026-05-02T07:00:00Z".

## Deal Stage Auto-Progression

**Rule: when the agent does something on behalf of a deal, it must also bump the deal's stage forward — but only forward, and only if the linked deal isn't already past that stage.**

The current Bookipi backend doesn't auto-progress deals when artifacts are sent. The agent owns this. After every "send" / "create" type mutation that has a linked deal, the agent must follow up with `bookipi deal update <dealId> --key <stage>` according to this table:

| After this action… | Move deal to… | …only when current key is one of |
|---|---|---|
| `meeting create` | `meeting` | `leads`, `qualified` |
| `proposal send` | `proposal` | `leads`, `qualified`, `meeting` |
| User confirms contract sent (from web editor) — bump manually | `contract` | `leads`, `qualified`, `meeting`, `proposal` |
| Invoice fully paid / explicitly closing the deal | `closed_win` | any non-terminal |
| Customer rejected the proposal/contract | `closed_lose` | any non-terminal |

**Five rules the agent must follow:**

1. **Forward only.** Never demote. If the deal is at `contract` and the user re-sends a proposal, do **not** bump back to `proposal` — leave it at `contract`. Re-sending an artifact doesn't unwind the pipeline.
2. **Skip if at-or-past target.** If the deal is already at the target stage (e.g. already at `proposal` and you just sent another proposal), skip the update silently. Don't re-fire a no-op mutation.
3. **Skip if no linked deal.** If the proposal/contract has no `projectPipelineId`, there's nothing to progress. Quietly skip.
4. **Don't auto-progress out of terminal stages.** If the deal is `closed_win` or `closed_lose` and an artifact is somehow re-sent on it, **do not** move it back into the open pipeline. That's a fresh-deal scenario — ask the user before doing anything.
5. **Custom keys exist.** A user might have added a stage with `key: "legal_review"` between `proposal` and `contract`. The agent doesn't know where it sits in the user's mental order. If the deal is at a non-standard key, **don't move it** — leave it alone and let the user advance manually. Only progress *out of* a non-standard key when the action's "allowed source" list (column 3 above) explicitly includes a standard key.

**Easiest path: use the `--advance-deal` convenience flag.**

The CLI bakes the precedence rules above into a `--advance-deal` flag on the relevant send commands. **Prefer this** over manually looking up + comparing + updating:

```bash
# This single command sends the proposal AND advances the linked deal
# (only if not already at-or-past 'proposal', not terminal, not custom-key).
bookipi proposal send @p1 -r email@example.com --advance-deal
```

Currently available on:

- ✅ `proposal send --advance-deal` → bumps to `proposal`
- 🚫 No `contract send --advance-deal` — the contract is sent from the web editor in Flow 1 (see `win-deal.md`). After the user confirms send, run `bookipi deal update <dealId> --key contract` manually using the deal handle captured during Phase 2 step 1.
- 🔜 `meeting create --advance-deal` → bumps to `meeting`
- 🔜 `invoice mark-paid --advance-deal` → bumps to `closed_win`

**Output shows what happened**: the command appends a 📍 line indicating either "Deal moved: X → Y" or the reason it was skipped (already at target / terminal / custom key / no linked deal). Even when the agent runs `--advance-deal`, surface the result in plain language to the user as part of the post-send recap.

**Manual fallback** for commands that don't have the flag yet:

```bash
# Get the deal's current key
bookipi deal list --search "<customer or deal name>" --json
# Compare its `status` to the target. Skip the update if at-or-past.
bookipi deal update @d1 --key proposal
```

## Progress Narration — Don't Leave the User Guessing

Some operations take >5 seconds. During that time the user is staring at silent chat wondering if anything's happening. **Narrate before slow steps with a one-line status + ETA**, so silence becomes attention.

**Format:**

> "[brief status]. **About N seconds.**"

**Slow steps that need narration** (always announce *before* running them):

| Operation | Typical time | Narration |
|---|---|---|
| `proposal generate` (AI proposal generation) | 13–30s | *"Generating the proposal — **about 15 seconds.***" |
| First meet-app or signit call in a session (token mint) | 4s | *"Connecting to the meeting service…"* |
| `report dashboard` / heavy aggregations | 5–15s | *"Building your dashboard — **about 10 seconds.***" |
| `expense scan` (receipt OCR) | 3–8s | *"Reading the receipt — **about 5 seconds.***" |
| `invoice remind --send` (bulk) | 3–10s depending on N | *"Sending N reminders — **about M seconds.***" |

**Don't narrate** — silence is fine here:

- Steps under 2 seconds (`customer list`, `deal list --status X`, `proposal update`, `invoice send`).
- Parallel batches that complete in <3 seconds total.
- Trivial lookups by ID.

**Recap after a parallel batch with multiple results** in a single line — e.g. *"Found Tony's customer record + 2 open deals + the May 3 meeting with transcript. Proceeding to draft."* This both confirms what was found and signals the slow step is starting.

**Don't over-narrate.** Two narration messages per flow is plenty. Three feels chatty. Five is annoying. The rule of thumb: only narrate before a step that takes >5 seconds, or after a parallel batch when summarizing.

**Why this works.** Cowork's chat shows agent messages as they're produced. A well-placed *"about 15 seconds"* during the AI generation step turns "frozen UI" into "active narration" — the actual time is unchanged but the perceived wait shrinks dramatically.

## Confirmation Style — Use `AskUserQuestion` for Choices

**Default rule: when the agent offers a small set of next actions or asks for approval on a binary/finite choice, use the `AskUserQuestion` tool — not free-text chat.** Clickable choices are faster than typing, less ambiguous than parsing "umm yeah" / "kk" / "send it I guess", and prevent accidental approvals from filler words.

### When to use `AskUserQuestion`

Always, for any of these moments:

| Moment | Example question | Choices |
|---|---|---|
| Destructive confirmation (send / delete / close-won) | *"Send Proposal-176 to Maria for ₱75K?"* | "Send now" / "Edit first" / "Cancel" |
| Disambiguation (multiple matches) | *"Which Maria did you mean?"* | "Maria Chen (Acme)" / "Maria Lopez" / "Maria Patel (Beta)" / "None of these" |
| Suggested next action | *"The proposal's out — want a reminder?"* | "Yes — when it expires" / "Yes — daily" / "No, I'll check later" |
| Path branching | *"Use the meeting transcript or describe it yourself?"* | "Use the transcript" / "Just use what I said" |
| Edge-case routing | *"No customer record for John Smith — create one?"* | "Yes — with these details" / "Edit details first" / "Cancel" |
| Spot-check follow-up | *"Maria viewed the proposal yesterday — send a nudge?"* | "Send nudge" / "Wait" / "Show me the thread" |

### When NOT to use `AskUserQuestion`

- **Open-ended questions** ("What should the proposal cover?") — free text is the right shape.
- **Status updates / recaps** — these aren't questions, they're info. Don't pretend they're choices.
- **Already-answered prompts** — don't re-ask the same question the user just answered, even if the conversation re-routed.
- **Trivial passthroughs** — if the only choices are "OK" / "OK", just do it. Don't ask for the sake of asking.

### Format conventions

- **Question is short.** One sentence. Long questions defeat the purpose of clickable choices.
- **2-4 choices ideal.** 5+ is overwhelming; collapse similar ones or use a sub-question.
- **One choice should always be a clean exit** — "Cancel" / "Not now" / "None of these". Never trap the user.
- **Choice labels are short imperative phrases** — "Send now", "Hold", "Edit first" — not sentences.
- **For destructive ops, the destructive choice goes FIRST and the safe option last** — this matches users' top-down reading and reduces accidental "second-click" mishaps. Example: ["Send now", "Edit first", "Cancel"].
- **Include the specifics IN the question, not in choice labels** — *"Send Proposal-176 to maria@acme.com for ₱75K?"* with choices `["Send", "Hold", "Cancel"]` beats `["Send to maria@acme.com", ...]`. Choices stay scannable; details stay above them.

### Graceful fallback

If `AskUserQuestion` isn't available in the current environment (e.g. some Cowork harnesses, or the tool surface didn't load it), fall back to a **labeled text prompt**:

> Send the proposal to Maria for ₱75K?
>
> - **a)** Send now
> - **b)** Edit first
> - **c)** Cancel
>
> Reply `a`, `b`, or `c`.

Don't pretend you used `AskUserQuestion` if you didn't.

### Why this matters

Three failure modes the previous "free-text yes/no" pattern produced:

1. **Accidental approvals.** "yeah" → agent fires the email even though the user was thinking out loud.
2. **Ambiguous denials.** "hmm" / "wait let me think" → agent waits or proceeds based on guesswork.
3. **Hidden forks.** "or do something else" → user expected another option but the agent only offered yes/no.

Clickable choices fix all three by making the option set explicit and the click intentional.

## Disambiguation — When a Search Has Multiple Matches

If `customer list --search` (or any name-based lookup) returns more than one result, **stop and ask** before acting. **Use `AskUserQuestion`** (see the Confirmation Style section above) — don't paste a list of bullets and wait for a free-text reply.

Question: *"Which Maria did you mean?"*

Choices, sorted by signal (most recent activity, deal count, total value):

- **Maria Chen** — Acme Corp (4 deals, ₱120K total)
- **Maria Lopez** (1 deal, qualified)
- **Maria Patel** — Beta LLC (closed_lose only)
- **None of these** *(let user clarify)*

If the user already gave a hint in their original message ("Maria from Acme"), match on that without asking. If you're 90%+ sure based on context, note your pick and proceed: "I'll assume you mean Maria Chen at Acme — say if that's wrong."

Never silently pick the first match. That's how the agent ends up acting on the wrong customer.

## Web URLs returned by the CLI are auto-authenticated

Web URLs returned by `contract create-from-proposal`, `contract finalize`,
`calendar status` (when disconnected), and similar commands include
`authToken`/`authRefreshToken`/`expireAt` query params by default. When the
user clicks the link, the Bookipi web app reads those params and skips the
login prompt — they land on the editor / settings page already authenticated.

If you (Claude) ever need to surface a plain URL to the user (e.g., for
documentation, demo screenshots, or troubleshooting), set
`BOOKIPI_NO_AUTH_URL=1` in the environment before running the CLI command.

**Never paste these URLs anywhere outside the user's direct view.** The auth
token in the URL is a credential — same security model as a session cookie.
Don't include in error reports, summaries to third parties, or any persistent
storage.

## Project-folder workspaces

Run `bookipi init` in a folder to make it a self-contained Bookipi workspace.
This stores credentials locally in `.bookipi/` inside the folder, isolating them
from the global `~/.bookipi/` store. The folder can then be mounted into a
Cowork project for a portable, per-project setup.

Use when:
- User says "set up bookipi in this project" or similar
- User wants to use a different Bookipi account for a specific workspace
- User wants their Bookipi setup to travel with a Cowork project

Run with `--no-login` if the user wants to set up the structure first and
authenticate later via `bookipi login`.

Run with `--with-cowork-instructions` to also write a `COWORK.md` capturing the
multi-agent flow conventions.

## Calendar pre-check (before meeting work)

Before running any `bookipi meeting *` command or doing scheduling-related work,
run `bookipi calendar status --json` once per session to verify Google Calendar
is connected. The JSON shape:

```
{ "isGoogleCalendarConnected": true,  "user": {...} }
{ "isGoogleCalendarConnected": false, "setupUrl": "https://...", "user": {...} }
```

If `isGoogleCalendarConnected === false`, surface the `setupUrl` to the user and
**stop the meeting flow** — explain that they need to connect Google Calendar
via the web UI first. Don't try to run `meeting list` or other meeting commands
that will fail at the meet-app layer.

If `isGoogleCalendarConnected === true`, proceed normally. Cache the positive
result for the rest of the session — don't re-check on every meeting command.

The setup URL is always derived from `BOOKIPI_WEB_URL` — works correctly for
staging, production, or any local override.
