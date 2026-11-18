# Leads and prospecting

Find people to sell to: describe an audience, see a sample of who matches, look
one person up, and list the leads already saved in the CRM. All six commands
only read — none of them emails anyone or saves anything.

## Commands

```bash
bookipi lead suggest "accounting firms in Sydney with 10 to 50 staff"   # plain words → filter sets
bookipi lead filters                                                    # values the filters accept
bookipi lead preview --industry "Business Services" --size small --country AU --title "Owner"
bookipi lead enrich --linkedin "https://www.linkedin.com/in/jane-citizen" --contacts
bookipi lead enrich --name "Jane Citizen" --company "Citizen Accounting" --country AU
bookipi lead list --source lead_autopilot                               # prospects sourced by Lead Autopilot
bookipi lead limits                                                     # plan allowance and usage
```

Every command takes `--json`.

## The flow: suggest → preview → enrich

1. **`lead suggest "<audience>"`** turns the user's words into one or more
   filter sets (industries, company sizes, countries, job titles). Use the
   values exactly as returned — industries must match the backend's
   spelling, and countries are two-letter codes (`AU`, `US`). `lead filters` lists every allowed value if the user
   wants to pick by hand.
2. **`lead preview`** shows a **sample of about five people** for one filter
   set: name, job title, company, industry, LinkedIn URL. `--industry`,
   `--size` and `--country` are each required and repeatable. It is a sample to
   check the audience is right, **not a contact list** — it never returns an
   email or phone, and there is no way to page through more.
3. **`lead enrich`** looks **one person** up. Identify them by `--linkedin`
   (most reliable — take it from the preview), `--email`, or `--name` with
   `--company`. Add `--contacts` to also fetch email and phone; only the first
   (best) match gets them.

`lead enrich` waits for the lookup to finish (up to `--timeout`, default 60
seconds). If it says the lookup is still running, run the **same command
again** — it resumes that lookup rather than starting a new one.

## What to tell the user

- **There is no bulk "give me 50 prospects with emails" command.** Preview is a
  five-person sample; contact details come one person at a time. If the user
  wants a steady flow of new leads, that is Lead Autopilot, set up in the
  Bookipi web app (CRM → Lead Autopilot); `lead list --source lead_autopilot`
  then reads what it sourced.
- **Each preview and each lookup is a live, paid search** at Bookipi's
  people-data provider. Don't loop over many people without the user asking
  for those specific people; ask before enriching more than a handful.
- **"Data enrichment feature is disabled."** from `lead enrich` means the
  feature isn't switched on for this account — say so; retrying won't help.
- A rate-limit error on `lead suggest` or `lead enrich` is per company: wait
  and try later rather than retrying in a loop.
- Contact details are data about a real person. Before the user emails someone
  found this way, remind them that anti-spam rules (e.g. Australia's Spam Act)
  may require consent or a clear business relationship. Don't email found
  contacts on your own initiative.

## Saved leads

`lead list` reads the CRM's leads with whatever contact details were found.
`--source` narrows by where a lead came from (`lead_autopilot`, `manual`,
`website_form`, `ai_receptionist`, `meeting`); `--search` matches on name;
`--page` / `--limit` page through. `lead limits` shows the plan's daily and
monthly sourcing limits and how many leads were sourced this month.
