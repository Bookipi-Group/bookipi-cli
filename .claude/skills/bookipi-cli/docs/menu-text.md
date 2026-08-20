# Text Menu — capability list (bare-terminal fallback)

Load this **only** on the text path — when there's no visual-widget tool
(`show_widget` / visualize MCP), e.g. Claude Code, Codex, or a plain terminal.
**In Cowork the widget (`docs/launcher-widget.html`) is used and you never need
this file.** See `SKILL.md` § What You Can Ask the Agent for the format decision.

Pick **4–6 items most relevant to the user** (skip ones that obviously don't
apply — e.g. don't show invoice features to someone who's never created one).
**Don't enumerate everything** — a dump overwhelms; a curated short list invites
the next question.

> Here's what I can help with — say things naturally, no special commands needed:
>
> **Money** (most used)
> - *"Who owes me money?"* / *"Show overdue invoices"*
> - *"Send a reminder for INV-203"* — drafts the email, asks before sending
> - *"Send reminders to everyone overdue"* — bulk, with confirmation
> - *"Run my collections"* — staged chase (gentle → firm → final); re-sends each invoice so they can pay it directly; drafts first, sends on your OK
> - *"Chase overdue every morning"* — set up a daily collections check that drafts the plan and asks before sending (safe to run unattended; it won't re-nag within 7 days)
> - *"Mark INV-203 paid"* / *"Send a receipt"* — close out a payment
> - *"Reconcile my bank statement"* — match deposits to invoices, one confirm, all marked paid
> - *"Create a payment link"* / *"Send a payment link to a customer"* — get paid with a shareable link; *"Has it been paid?"* checks what it collected
>
> **Daily**
> - *"What's on today?"* / *"Morning brief"* — meetings, pipeline, money, awaiting action
> - *"Run my day"* — the brief PLUS today's drafted actions (chasers, nudges), one approval
> - *"Set up my AI employee"* — that same run, scheduled every morning
> - *"What should I focus on?"* — same brief, framed around priorities
> - *"What did you do this week?"* — the assistant's own activity report
>
> **Customers**
> - *"Tell me about Acme Corp"* — full picture: deals, proposals, contracts, invoices
> - *"Follow up with Acme"* / *"Email Maria"* — drafts a freeform note, asks before sending
> - *"Add a customer"*
>
> **Expenses**
> - *"Log this receipt as an expense"* (drag a photo or PDF)
> - *"Show my expenses this month"*
> - *"Show my expense categories"*
>
> **Reports**
> - *"Give me a business dashboard"* / *"Sales report this quarter"*
> - *"Top customers"* / *"Top items"*
> - *"Weekly digest"* / *"Business insights"*
>
> **Pipeline**
> - *"Show me my deals"* / *"What's in the pipeline?"*
> - *"Stalled proposals"* — proposals sent without acceptance for a while
> - *"Win the Acme deal"* — proposal → signed contract → invoice → mark won
>
> **Account & catalog**
> - *"My items"* / *"Add an item"* — your products/services list; paste a product photo and say *"add this as an item"*
> - *"Duplicate an invoice"* — reissue an editable copy
> - *"Switch company"* / *"Who am I?"* — change or check the active account
>
> **Spot-checks**
> - *"Did Maria view the proposal?"*
> - *"Is INV-203 paid?"*
> - *"Has the contract been signed?"*

After listing, offer one specific suggestion based on context: *"Want to start
with a morning brief, or pull up a customer?"* If you know the user is mid-task
(e.g. just sent an invoice), suggest the natural next step.
