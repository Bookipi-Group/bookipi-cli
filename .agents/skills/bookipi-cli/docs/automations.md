# Automations — recurring scheduled checks

The launcher's **Daily & automations** card is the hub for setting up and managing
recurring checks. All scheduling runs through the `scheduled-tasks` MCP (there's
no server-side cron in the CLI). Cron expressions are in the user's **LOCAL** time.

> **Two things to tell the user up front:** scheduled tasks run while the app is
> open — if it's closed when one is due, it runs on next launch (so a missed
> morning run isn't a surprise). And every money-related automation **drafts and
> asks** before sending; nothing auto-emails a customer.
>
> **MCP fallback:** if `scheduled-tasks` isn't available in this build, say so
> plainly and offer to run the check on demand instead. Don't promise a cadence
> you can't run.

## What you can automate

| Automation | User says… | What the task does | Setup recipe |
|---|---|---|---|
| **Daily morning brief** | "brief me every morning", "check everything daily" | one unified sweep across invoices + payments + proposals + contracts | `morning-brief.md` § Scheduling |
| **Daily collections check** | "chase overdue every morning", "set up a daily collections check" | dry-run the ladder, present the plan, ask before sending | `collections.md` § Scheduled daily check |
| **Auto-chase stalled deals** | "follow up on stalled deals automatically" | detect quiet proposals and nudge on a cadence | `stalled-recovery.md` |

### Setting one up

Use `mcp__scheduled-tasks__create_scheduled_task` with a **self-contained** prompt —
each run starts fresh with no memory of this chat, so bake in the exact CLI command,
the decision rule, and "never auto-send." Defaults:

- **Schedule:** a weekday morning unless the user says otherwise — e.g. `cronExpression: "0 9 * * 1-5"` (9am local, Mon–Fri). Respect the user's timezone if known.
- **taskId:** stable kebab-case (`daily-collections-check`, `daily-morning-brief`, `stalled-deal-recovery`) so re-runs don't duplicate.
- **Confirm first:** creating a task shows the user an approval prompt — that's the confirmation. Describe what you're scheduling before you call it.

**Idempotency — don't create duplicates.** Before creating, run
`list_scheduled_tasks` and reuse/update an existing task with the same purpose
(match on the stable taskId/description) instead of adding a second one.

## Managing automations

Triggers: *"show my automations"*, *"what's scheduled?"*, *"manage automations"*,
*"pause my daily collections check"*, *"stop chasing overdue automatically"*,
*"change my morning brief to 7am"*.

**1. List — `mcp__scheduled-tasks__list_scheduled_tasks`.** Present each in plain
language: what it does (`description`), its schedule (`schedule` is human-readable),
whether it's **active or paused** (`enabled`), and when it next runs (`nextRunAt`) /
last ran (`lastRunAt`). Don't surface `taskId` or raw cron strings unless asked.

**2. Pause / resume — `update_scheduled_task`.**
- Pause: `{ taskId, enabled: false }` — stops automatic runs, keeps the setup.
- Resume: `{ taskId, enabled: true }`.

**3. Change the time — `update_scheduled_task({ taskId, cronExpression: "<5-field local-time cron>" })`.**
(e.g. `"0 7 * * 1-5"` for 7am weekdays.)

**4. Change what it does —** Read the task's `path` (its SKILL.md, returned by
`list_scheduled_tasks`) to see the current prompt, then
`update_scheduled_task({ taskId, prompt: "<new prompt>" })`.

**5. Stop it for good — `mcp__scheduled-tasks__delete_scheduled_task({ taskId })`.**
Removes the task from the scheduler so it never fires again. (The task's SKILL.md
stays on disk at `~/.claude/scheduled-tasks/<taskId>/`, so the prompt can be
recovered if the user changes their mind.) If they just want a break — not a
removal — **pause instead** (`enabled: false`, item 2): it's reversible in place.

> **Confirm pause/delete/edit via `AskUserQuestion`.** Turning off someone's
> collections chase or morning brief — or changing when it runs — is a change they
> should approve, not something to do silently. Deletion doubly so: confirm
> before calling `delete_scheduled_task`, and offer pause as the lighter option.

**Nothing scheduled yet?** `list_scheduled_tasks` returns none → say so and offer
to set one up from the table above.

## Cross-references
- Set up the daily brief → `morning-brief.md` § Scheduling
- Set up the collections check → `collections.md` § Scheduled daily check
- Set up stalled-deal recovery → `stalled-recovery.md`
- Confirmation style for pause/delete → `common.md` § Confirmation Style
