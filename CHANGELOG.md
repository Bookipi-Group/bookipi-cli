# Changelog

User-facing changes to Bookipi CLI, the skill bundle, and the plugin manifests.
Each version is a [release](https://github.com/Bookipi-Group/bookipi-cli/releases)
with a `bookipi-cli.skill` attached.

A note on upgrading: the plugin cache is keyed by version, so content published
under a version you already have will not reach you. `claude plugin update`
reports "already at the latest version" and keeps serving the cached copy —
refresh the marketplace first (`/plugin marketplace update bookipi-cli`).

## 0.56.0 — 2026-11-26

### Added
- Connector: `list_invoices` filters by customer (`customer_id`) and by date
  range (`created_from`, `created_to`), and can return each invoice's line items and payments
  in the same call (`include`). Questions about one customer, one period or
  what was sold no longer need a call per invoice.
- Connector: `list_proposals` takes the same customer and date filters, and a
  text `search`.

### Changed
- Paging to page 3 or beyond of invoices, customers or items with no filter now
  prints a one-line note on how to search instead, on the CLI (stderr, so
  `--json` output is unchanged) and as a `hint` on the connector's result.
- When Bookipi rate-limits a call and says how long to wait, the error now
  gives that time in place of a fixed "about 30 seconds".
- Connector: `list_invoices` asks Bookipi only for the fields it returns, not
  the whole invoice for every row, so a page loads with far less data.
- Usage analytics for a CLI command or a connector tool call now include the
  page number and page size asked for, the document type, status, sort and
  period chosen, how long it took and how much it returned. Search text,
  customer names, ids, dates, amounts and every other value are still not sent.
- Usage analytics and the connector's failure log now say what kind of
  failure a tool call was: the tool declining the request, a sign-in problem,
  the Bookipi API being unreachable, slow or throttled, a record that does not
  exist, or a rejected value. Every failure used to be reported as "refused".
- The hosted connector logs one line for every tool call, with the same
  details plus the caller's hashed user id, sign-in type and forwarded
  address. A failed call's line now carries them too.

### Fixed
- Duplicating a repeating invoice on a free plan no longer starts a second
  repeating series. The copy is a one-off, the same as a duplicate made in the
  web app. On a paid plan the copy keeps repeating, as before.

## 0.55.1 — 2026-11-25

### Fixed
- A sign-in the auth server has rejected is no longer retried. Scheduled jobs
  with an expired session retried it on every run until the auth server
  rate-limited them; now each later run skips the retry and asks for
  `bookipi login`.

### Removed
- The fallback to the old `/api/auth/token/refresh` endpoint. Renewals use
  the standard OAuth refresh grant, which production now accepts.

## 0.55.0 — 2026-11-25

### Added
- `bookipi customer create --works-at <company>` names the company a person
  works at, and `--type person|company` says which a new customer is.

### Changed
These can affect scripts and saved prompts; each is explained under Fixed.
- `invoice create`, `invoice update` and `invoice duplicate --customer` no
  longer create customers or catalogue items. An unknown customer stops the
  command; a new line with a price is a one-off line.
- `invoice delete`, `customer delete`, `proposal delete` and `expense delete`
  need `--yes`.
- `invoice remind --json` and `invoice collections --json` count skipped
  invoices in `skippedBecause` instead of listing them (collections no longer
  has `planSkipped`). `report digest --json`: `collectedCount` is now
  `collectedPayments`.
- Reports count only sent invoices in the company's currency, so figures can
  differ from the web app's Reports page.
- Connector: `create_website` is removed for now; `scan_receipt` is a write.

### Fixed
- `bookipi website create` no longer fails with "Token is invalid or has
  expired". Bookipi's website creation looks up the business profile with a
  sign-in token the CLI didn't send; it now does, as the web app does.
- The connector no longer offers `create_website`, which failed the same way
  every time and can't be fixed from the connector yet. `website_status` tells
  a company with no website to open the Website Builder in the web app, which
  creates it; the builder message says the same.
- When a payment link's payments can't be read, `paylink status` and the
  connector's `paylink_status` now say why and what to do instead. Bookipay no
  longer reports payments per link (staging, then production), and the web
  app doesn't show them either; the old message said the history was
  unavailable "right now" or pointed to a dashboard that doesn't have it.
- `create_paylink` on the connector uses the company's currency when none is
  given, as it says. It sent an empty currency, so the link failed with
  "currency is required" (INTERNAL_SERVER_ERROR) after the preview had passed.
  The preview now shows the currency, and both refuse with a clear message if
  the company's currency cannot be found. `bookipi paylink create` no longer
  falls back to USD when the currency isn't cached; it reads the company's.
- Expenses logged through the connector are no longer saved 100 times too
  small. `create_expense` takes the amount in the company's currency (42.50)
  but passed it on unconverted, and Bookipi stores cents, so A$42.50 was
  saved as A$0.43 and showed that way in `expense list`, the web app and the
  connector. It now converts. `list_expenses` returns amounts in the currency
  instead of raw cents, and the skill's scan-to-expense recipe passes the
  scanned amount (which is in the currency) to `--amount`, not
  `--amount-cents`. Expenses already saved wrong stay wrong: fix the amount in
  the web app.
- Reports no longer count drafts never sent as invoiced revenue. "Invoiced",
  the monthly breakdowns, the collection rate, top customers and items, and
  advice such as "X accounts for 58% of your revenue" all counted drafts, so
  a customer whose every invoice was an unsent draft could top the list.
  `report summary`, `report digest`, `report suggest`, `report insights`,
  `report customers`, `report items`, the dashboard and the connector's
  report tools now count only invoices that were sent, by the date on the
  invoice, and show unsent drafts on their own line. These figures no longer
  match the web app's Reports page, which counts drafts.
- Reports no longer add invoices in other currencies into the company's
  totals as if they were the same money (on the staging account, USD
  payments were counted as pesos). Invoiced, paid, unpaid, overdue,
  collection rates, top customers and items, and the insights analysis count
  only the company's currency (and invoices with none set); other currencies
  are listed on their own line per currency, not converted, since Bookipi
  stores no exchange rate. Payments are now read off the invoices, by payment
  date, instead of the report API's totals. The digest's "Collected" counts
  payments, and its JSON field is now `collectedPayments`.
- Reminder and collections emails show the amount in the invoice's own
  currency. A USD invoice's reminder from a peso company said "₱20.00" to the
  customer instead of "$20.00".
- `bookipi logout` no longer says "Already logged out" while you are still
  signed in. A delete that failed (seen in a Cowork project folder) was
  dropped silently. Logout now empties a sign-in file it cannot delete, names
  any file it could not clear, and checks afterwards: if a sign-in is still
  found (a leftover file, or the `BOOKIPI_TOKEN` variable) it says where and
  exits with an error.
- `scan_receipt` on a local connector is no longer labelled read-only. It
  uploads the file to Bookipi's receipt storage, but said it saved nothing, so
  a host could run it without asking. It is now a write (hosts ask first), and
  it says it uploads the file. Uploads for receipts (`scan_receipt`, and
  `expense scan`, `upload` and `create -f` in the CLI) accept only png, jpg,
  jpeg, pdf, heic and webp; any other file used to be sent too.
- Deletes need `--yes`, like sends and payments. `invoice delete`,
  `customer delete`, `proposal delete` and `expense delete` ran straight away
  (only deleting several expenses asked), so a customer who still had an
  estimate, or a proposal already sent to the customer, went to the trash with
  no warning. Without `--yes` they now refuse and say what would go and what
  to know first: the documents the customer still has, or that the invoice or
  proposal was already sent. `invoice delete` refuses an invoice with payments
  recorded, as the connector already did. The connector's delete previews
  carry the same warnings. All four move the record to the trash.
- Making an invoice no longer creates a customer or catalogue item on the side.
  Asked for an estimate for someone not in Bookipi yet, the skill created the
  customer and the items with no question; they are lasting records, and a
  duplicate customer splits their history. `invoice create`, `invoice update`
  and `invoice duplicate --customer` now stop when the customer matches nobody,
  write nothing, and name any similar customers: create them with
  `customer create` (after asking) and re-run with the handle. A new line with
  a price goes on the invoice as a one-off line and adds nothing to the item
  catalogue; a new name with no price stops the command instead of becoming a
  $0 line. Copying into another company you own still brings the customer
  across. On the connector, `copy_invoice` no longer creates a customer from a
  name, and `create_customer` and `create_item` tell the assistant to check for
  a match and ask first.
- Reminders leave drafts alone (`invoice remind` and `invoice collections` in
  the CLI, `remind_invoice` on the connector). A draft past its due date was listed as overdue and
  reminded, so the customer received the invoice for the first time as an
  "overdue" notice and the draft became a sent invoice. Drafts are now skipped
  in the overdue scan, in the collections ladder and with `--invoice` /
  `invoice_id`, with the reason shown; send the invoice first.
- `invoice remind --customer` (and `customer` on `remind_invoice`) matches the
  customer's name, as it says. It only ever matched the email address, so
  "remind Acme" skipped every Acme invoice unless "acme" was in the email.
- Reminders and collections no longer miss overdue invoices on an account with
  many drafts past their due date. They read only the newest 200 "overdue" results, which
  include drafts, so an account whose newest 200 were drafts chased nobody.
  They now read every overdue invoice, up to 3,000, and say so when there are
  more (`partial` in `--json` and on `remind_invoice`).
- `invoice remind --json` and `invoice collections --json` list only the
  invoices that are sent or would be, and count the skipped ones by reason in
  `skippedBecause`. On an account with many overdue drafts the output listed
  every skip, about 250 KB.
- The dashboard's `company_id` on the connector reaches every figure on it, and
  its currency. It used to build the page from the default company.
- Reports no longer count drafts the customer was never sent as unpaid or
  overdue. `report insights` read Bookipi's overdue list, drafts included, and
  told you to chase them; it also counted a draft twice in "revenue sitting
  uncollected", once as overdue and once as an unsent draft. `report summary`,
  `report digest`, `report suggest`, `report insights` and the dashboard
  now read unpaid and overdue the same way, by balance, without those drafts.
  An invoice that was sent and later edited still counts.
- `report insights` and `report suggest` no longer name invoices with no
  customer as one customer ("Unknown has 174 overdue invoices").
- `report insights` no longer counts an invoice twice in "revenue sitting
  uncollected" and the next-month cash estimate when the customer has viewed
  it and it is past due. It counts once, as overdue.
- Report hints no longer point at a list that disagrees with the figure. The
  "view overdue" and "view unpaid" hints say that drafts in the list show as
  Draft and are not counted, and "view unpaid" now includes overdue invoices.
  `report suggest` points at an `invoice remind` dry run that lists exactly the
  invoices it names. The customer name in that command is single-quoted, so a
  name with `$`, a backtick or a quote pastes into a shell as written.
- `invoice remind --customer` and `invoice collections --customer` match a
  customer's company name as well as the person's name, for a customer that
  has both. Both commands now match the same way.
- `bookipi customer create` makes a person a person: one created with a name and
  no `--company-name` is listed under People in Bookipi, not Companies. Bookipi
  took every customer the CLI created as a company. `--company-name` with a
  person's name beside it still makes a company with a contact name; for the
  company a person works at, use `--works-at`.

## 0.54.0 — 2026-11-24

### Added
- `bookipi company update` changes the active company's details as its documents
  print them: name, business number and its label, address, phone, email and
  website. Only the options given are changed.
- `bookipi company logo <file>` replaces the company's logo with a PNG or JPEG
  file.
- `bookipi company get` now shows the company's website.
- `bookipi company style` shows and changes how the company's documents look:
  one accent colour, font and text size for every document type.
- `bookipi company terms` shows and changes what new documents start with: when
  an invoice is due, how long a proposal stays open, and the payment
  instructions printed on invoices.
- Contract templates: `bookipi contract templates` lists the company's own and,
  with `--library`, Bookipi's ready-made ones; `contract from-template` starts a
  draft from one; `contract save-template` keeps a contract as a template.

### Fixed
- `bookipi company get` shows the address a company keeps today, with its city,
  state, postcode and country, the way documents print it. It read only an
  older set of fields, so an address set in the web app or with
  `company update` showed as not set.

## 0.53.0 — 2026-11-20

### Added
- `bookipi customer open` gives a link to the Customers page in the Bookipi web
  app that signs you in, for the spreadsheet and Google Contacts imports, which
  only the web app can run.

## 0.52.0 — 2026-11-19

### Added
- `bookipi company get` shows the active company's details as its documents
  print them: name, business number and its label, address, phone, email and
  the logo's address. `--json` gives the same as `{ "company": { ... } }`.
- More for the AI receptionist: `receptionist voice preview` gives a link to a
  sample of a voice in a tone, `receptionist test-questions` suggests questions
  for a test call, and `receptionist summary read` clears the call summary's
  new badge. `receptionist call list` filters by `--caller`, takes several
  `--type` values and sorts by caller, name, type or status; `receptionist
  stats --all` counts every call so far. `receptionist get --json` now includes
  `vapiClientKey` and the plan's `callLimitPerMonth`.

### Changed
- Recurring invoices on the connector have their own tools.
  `start_recurring_invoice` makes an existing invoice recurring or changes its
  schedule, and `stop_recurring_invoice` ends one. The `repeat` and
  `stop_repeating` options are gone from `create_invoice` and
  `update_invoice`: create the invoice, then make it recurring. Because every
  scheduled run emails the customer, that step now gets its own confirmation,
  like sending. The CLI's `invoice create --recurring` and
  `invoice update` flags are unchanged.

## 0.51.0 — 2026-11-19

### Removed
- **AI Contract is gone, from the connector and the CLI.** `draft_contract`,
  `draft_contract_from_proposal` and `finalize_contract` are no longer
  connector tools, and `contract draft`, `contract create-from-proposal` and
  `contract finalize` are no longer CLI commands. The assistant writes a better
  contract than AI Contract did, and the tool kept pulling eSign requests away
  from eSign.

### Changed
- Every request to get something signed now goes to **Bookipi eSign**: a
  document the assistant writes for you, a template from your account or the
  Bookipi library, or a PDF you have. The assistant prepares it in the eSign
  web app — signers found in (or added to) your customers, the signature tag
  just above its line, the date tag on its line — and **stops at the Send
  screen** until you confirm that send. Without a browser it gives you the link
  and the same steps. It never sends a document for signature as a plain
  email. A contract prepared in the browser is sent from its "Finish & send"
  dialog, so its message, CC and reminders apply. In the CLI, a contract you
  wrote goes in with `contract upload`.
- `send_contract` and `contract send` take only a contract's id; there are no
  AI drafts left to resolve.

### Fixed
- Payment links on a company that has never set up card payments: the message
  now says what actually has to happen (accept card payments on the Payment
  Links page of the web app, then Stripe's identity checks) and links to it.
  It used to say "open Payment Links in the web app once", which does not
  activate anything. Listing payment links on such a company answers "none
  yet" with the same pointer, where it used to fail. `create_paylink`'s
  preview runs the same check as the real call, so it no longer passes and
  then errors. The connector page now mentions the setup step.
- `document_numbering` no longer reports an `enabled` flag per document type.
  It read as "this company has purchase orders switched off", but it is
  Bookipi's default value for credit notes, delivery notes and purchase orders
  on every company, and nothing acts on it: the web app and the connector both
  create those documents regardless.
- The public connector page said estimates, credit notes, delivery notes and
  purchase orders were "Not yet" supported. They are; the page is corrected.
- "What was my revenue last quarter?" works. The revenue report
  (`report_summary` on the connector, `report summary` in the CLI) offered a
  `quarter` cycle that Bookipi's report API does not have and failed with a
  server error; quarters are now built from months. `week` is offered too, and
  an unknown cycle is refused with the list of valid ones.
- The revenue report's unpaid and overdue figures are now everything owed as
  of today, by balance — the same numbers as the digest. They were scoped to
  the date range in two different ways and matched nothing else ("6 overdue"
  beside the digest's "8 overdue").
- The revenue report counts an invoice in the period printed on it. An invoice
  dated 31 July and entered in September was counted as September's, because
  Bookipi's report API goes by the day an invoice was created. Invoiced totals
  are now read from the invoices by their own date; paid totals still go by
  payment date. This can differ from the web app's Reports page for a
  backdated invoice.
- The connector's revenue report returns a simpler shape: `invoiced`, `paid`,
  `buckets` and `owedNow`. `report summary --json` returns the same.
- Suggestions count invoices and customers separately and quote the days the
  invoices really span: "Send reminders for 8 overdue invoices from 3
  customers … 7 to 87 days past due", where it said "8 overdue customers" and
  always "7-89 days" (`report_suggestions` on the connector, `report suggest`
  in the CLI). The outstanding amount is now by balance, so it agrees with the
  overdue total; it counted a part-paid invoice in full. Overdue invoices are
  read in full, not just the 100 newest, and ones with nothing left to pay are
  left out.
- Proposal emails no longer arrive with "&apos;" in the subject line. Sent
  with no subject from the connector or the CLI, a proposal now goes out as
  "Proposal from <your company>" with the message "Looking forward to doing
  business with you", the web app's own defaults; it used to be "You've
  received a proposal", and Bookipi's mail service turns an apostrophe in a
  subject into "&apos;". A subject you type keeps its apostrophes, written as
  ’ so they survive. `send_proposal`'s preview shows the subject and message.
- Reminder emails name the invoice by its own number and write the due date
  in your company's date format: "invoice invoice-1 … (due 17/11/2026)", or
  "17 Nov 2026" if that is your setting, matching the "Due:" line at the top
  of the email. They said "INV-invoice-1" and "2026-11-17" (`remind_invoice`
  on the connector, `invoice remind` and `invoice collections` in the CLI).
  An invoice with no due date reads "due on receipt". The default message on
  a plain send formats its due date the same way.
- A document sent without a typed message no longer arrives with an empty
  message box (`send_invoice` on the connector, `invoice send` in the CLI,
  for invoices, estimates and the other document types). It now carries the
  same default the web app pre-fills: the message your company saved for that
  document type if there is one, otherwise "Hi Jenny, Here's estimate
  estimate-2 for $1,500.00. Thank you!" with the amount, due date, deposit
  request and pay-online line as they apply. The connector's send preview
  shows the message in full before anything is sent.
- The digest's figures match the period it states (`report_digest` on the
  connector, `report digest` in the CLI):
  - **Invoiced and collected** are for the period, with real counts. They were
    the trailing twelve months' amounts beside a count of 0, so a weekly digest
    showed the year's billing.
  - **Unpaid and overdue** are everything still owed as of today, by balance.
    They were limited to invoices from the last twelve months and unpaid was
    summed by invoice total, so a part-paid invoice counted in full.
  - **Recent activity** lists payments received in the period. It listed the
    latest paid invoices whenever they were paid.
  - **`last-week` and `last-month`** work. Both were offered by the connector
    and silently returned this week, labelled "This week". An unknown period is
    now refused.
  - The CLI digest no longer crashes when more was collected in a period than
    was invoiced in it.
- Expense date ranges and merchant search work. `list_expenses` on the
  connector and `expense list` in the CLI accepted a start date, an end date
  and a search, and applied none of them, so "my expenses this month" returned
  every expense on the account. The range is now applied by Bookipi, both ends
  inclusive, and the search matches anywhere in the merchant name. The list is
  ordered by purchase date, newest first. `expense list --end` no longer
  defaults to today, which hid future-dated expenses.
- `send_contract` refuses a contract with no signature field. Bookipi accepted
  the send, but the signer could only view and complete it, and the contract
  ended up marked signed with no signature on it. `contract send` in the CLI
  already refused. Both now also refuse a contract that is already signed or
  declined, and `send_contract` no longer emails the signers again when the
  contract was already sent.

## 0.50.0 — 2026-11-19

### Added
- AI receptionist from the CLI: `receptionist get` shows its status, phone
  number, subscription and the published and draft setup; `receptionist stats`
  counts calls by type with the change against the period before (and the AI's
  summary with `--summary`); `receptionist call list` (filter by `--caller`, sort by caller, name,
  type or status) and `call get` read the
  call log, summaries and transcripts; `call read` and `call status` mark a
  call read or set its follow-up status. `receptionist draft save` creates or
  changes the draft (voice, tone, hours, greeting, FAQ, contacts…) and never
  makes it live. `receptionist publish` does, so it refuses without `--yes`; it
  needs a subscription (bought in the web app, which `receptionist open` links
  to). `receptionist voice preview` gives a link to a sample of a voice in a
  tone, `receptionist test-questions` suggests questions for a test call, and
  `receptionist summary read` clears the call summary's new badge. `get --json`
  now includes the `vapiClientKey` the web test call starts with and the
  plan's `callLimitPerMonth`. CLI and skill
  only.
- Events from the CLI: `event list` reads what happened on the account's CRM
  timeline (an invoice paid, a payment failed, a contract signed, an email
  replied to), newest first, with filters for event type, record type,
  record and customer, and a cursor for the next page. Read-only. CLI and
  skill only.

## 0.49.0 — 2026-11-18

### Fixed
- `paylink status` (and the connector's `paylink_status`) no longer fails
  when Bookipay does not report a link's payments, as on staging since Bookipay
  dropped that lookup. It shows the link and says the collected amount is
  unknown instead of erroring. `paylink_status` also stopped counting failed
  attempts as paid: `paid`, `paymentCount` and `collected` now cover
  successful payments only.

## 0.48.0 — 2026-11-16

### Added
- Signals from the CLI: a new `signal` group. `signal list` reads what the
  CRM noticed on the account's timeline and suggests doing next (an unpaid
  invoice, a failed payment, a bounced email), pending and most severe first,
  with filters for status, record type, record and rule. `signal execute` and
  `signal dismiss` record what the user decided; they change the signal only
  and send nothing. CLI and skill only.
- Prospecting from the CLI: a new `lead` group. `lead suggest "<audience>"`
  turns plain words into audience filters, `lead filters` lists the allowed
  values, `lead preview` shows a sample of about five matching people (no
  contact details), `lead enrich` looks one person up by LinkedIn URL, email
  or name and company (`--contacts` adds email and phone), `lead list` reads
  the leads saved in the CRM, and `lead limits` shows the plan's allowance.
  All read-only; nothing is emailed or saved. CLI and skill only.
- The connector creates every document type, not only invoices:
  **estimates, credit notes, delivery notes and purchase orders**.
  `create_invoice` takes `document_type` (`estimate`, `credit_note`,
  `delivery_note`, `purchase_order`; default `invoice`), and `list_invoices`
  takes it too, so those documents can be listed. Before this, asking the
  connector for an estimate created a real invoice.

## 0.47.0 — 2026-11-09

### Added
- Recurring invoices, end to end. `invoice create --recurring` takes `--every`; `invoice update` can start, change or stop a repeat (`--recurring`, `--every`, `--next-run`, `--stop-recurring`); no end date, because Bookipi's scheduler doesn't honour one yet; new `invoice recurring list` and `invoice recurring stop`. Starting a repeat needs `--yes`. The MCP server gets a `repeat` option on `create_invoice` and `update_invoice`, `stop_repeating` on `update_invoice`, and a `list_recurring_invoices` tool, so a monthly invoice asked for through Claude or ChatGPT is no longer created as a one-off.
- Recurring invoices, phase 2. `invoice recurring history <invoice>` lists what a repeat has produced; `invoice recurring list --type` lists repeating estimates, credit notes, delivery notes and purchase orders. On the MCP server `list_recurring_invoices` takes `document_type` and `generated_from`. Rows in a plan-limit grace period carry `planLimit`.

### Changed
- Sign-in refresh uses the standard OAuth refresh grant, falling back to the older endpoint where it isn't available yet.

### Fixed
- Hosted MCP server: no longer renews the Bookipi token on every OAuth refresh, and forwards the signed-in user's IP, which ends the daily sign-in lockouts many connector users shared.

## 0.46.1 — 2026-10-29

### Fixed
- 0.44.0–0.46.0 failed to start on Node 22.12–22.14 ("Cannot read properties
  of undefined (reading 'bind')"). The HTTP library is back on a version that
  supports Node 22.12, with no open security advisories.

0.45.0 and 0.46.0 were re-tags of 0.44.0 with documentation changes only.

## 0.44.0 — 2026-10-29

### Added
- The skill gives you a `bookipi` command on first use: it copies the CLI it
  already ships into `~/.local/bin` (no download) and runs plain `bookipi`
  from then on. Not in Cowork, whose sessions don't keep a home folder — there
  it uses the bundled CLI straight away.
- The Gemini CLI extension bundles Bookipi's hosted MCP server. When Bookipi
  MCP tools are present (Gemini, or the Bookipi connector in Claude), the
  skill uses them instead of the CLI. This reverses 0.38.1's CLI-only rule.
  The skill no longer translates CLI commands into tool calls; it uses each
  tool as its own schema describes. The connector still does less than the
  CLI. [What each one supports](docs/connector.md#what-the-connector-doesnt-do).
- Contributor kit: `CONTRIBUTING.md` and the `bookipi-contribute` skill for
  Bookipi teams adding their own capabilities.

### Changed
- Sessions start with no setup calls: the skill runs `bookipi setup` only when
  a command reports that sign-in is needed. A normal session now takes one
  call instead of two.

### Security
- Credential files are owner-only (0600); a world-readable file from an older
  version is tightened on its next write, and a new `~/.bookipi` is created
  0700.
- Opening a browser no longer passes the URL through a shell.
- Dependency advisories patched: undici, zod, body-parser, qs, fast-uri,
  ip-address, sanitize-html.

### Fixed
- An unexpected crash now ends with the CLI's normal error message and exit
  code instead of a raw stack trace.

## 0.43.0 — 2026-10-14

### Added
- `bookipi setup` — one call that checks the workspace and sign-in, sets up a
  workspace or starts the login when needed, and returns the next step as JSON
  (`ready`, `show_login_link`, `choose_folder`, `needs_folder`,
  `create_company`, `offline`). `--check` only reports; `--folder <path>` puts
  the workspace in a given folder. The skill now starts every session with it.
- Update notice: once a day the CLI checks GitHub for the latest release and,
  while a newer one exists, prints one line saying how to update for the way it
  was installed (Claude Code plugin, Codex, `npx skills`, Gemini extension,
  the standalone installer, or the `.skill` file). Nothing is downloaded.
  Turn it off with `BOOKIPI_NO_UPDATE_CHECK=1`.
- Standalone installer for using `bookipi` in your own terminal, attached to
  each release with `bookipi-cli.tar.gz` and its `.sha256`. It installs the
  latest release (or `BOOKIPI_VERSION`), verifies the checksum, does nothing
  if that version is already installed, and asks before changing versions.
- `bookipi login --config-dir <dir>` — the login wait finds its pending session
  from any folder.

### Changed
- The skill's setup instructions are replaced by `bookipi setup`: SKILL.md is
  about a quarter shorter, so each session loads fewer tokens.
- Error hints for an expired login, a missing default company, an unwritable
  config folder and the web-handoff warning now say `bookipi setup`.

### Fixed
- A login could fail with "Unknown session" on the second wait in harnesses
  that reset the working folder between calls (Codex, subagents).
- The auth-error hint pointed at `bookipi login --relay`, a flag that no longer
  exists.
- `bookipi whoami` fetched the account twice.

## 0.42.0 — 2026-10-13

### Breaking
- `invoice send`, `invoice send-receipt`, `invoice mark-paid`, `invoice void`,
  `paylink create`, `paylink send`, `proposal send`, `contract send`,
  `customer send-email` and `website publish` now refuse to run without
  `-y, --yes` (exit 3, before anything is sent or recorded). Scripts that call
  them must add `--yes`; the skill adds it only after the user approves.

### Changed
- The skill states that it never moves money, and that `invoice void` only
  clears a mistakenly recorded payment and refunds nothing.

> 0.39.0 – 0.41.3 shipped without changelog entries.

## 0.38.1 — 2026-09-02

> The CLI-only routing below was reversed in 0.44.0.

### Changed
- **The skill drives the `bookipi` CLI only.** It previously claimed to cover
  the hosted MCP connector as well, and that pairing had never been tested.
  It does not hold: the flow docs document `invoice create --type estimate`,
  `--recurring`, `--add-item` and `--status`, and none of them exist on the
  connector's write surface — `create_invoice` has no document type at all. A
  model following the documented translation would create a real invoice when
  the user asked for a quote, and nothing would report an error. The two-path
  routing, the CLI-to-tool translation table and the connector fallback are all
  gone; when no CLI is reachable the skill now says so and stops.
- **The plugin no longer declares the connector**, reversing the addition below.
  A plugin install is the skill plus the CLI it fetches on first use. The hosted
  connector at `https://mcp.bookipi.com/mcp` is unchanged and still serving —
  it is now added deliberately by people who want it, rather than arriving with
  a plugin install. If you installed 0.38.0, the declaration stays in your
  config until you update; `claude mcp list` shows it as
  `plugin:bookipi:bookipi`.

## 0.38.0 — 2026-09-02

### Fixed
- **The hosted connector asked you to reconnect about 45 minutes after signing
  in.** Renewal used the standard OIDC refresh grant, which Bookipi's auth
  module implements for confidential clients only — a public client posting it
  got `invalid_client`, so every renewal failed and the client discarded its
  tokens. It now renews through the same endpoint the CLI has always used. The
  45-minute access token was the real session length; the refresh token never
  got a chance to be used.
- The connector's refresh token expired at 30 days while the credentials it
  wraps expire at 14, leaving a fortnight in which a client held a token it
  believed was good and every renewal failed. It is now 14 days, matching.

### Added
- All three manifests declared the hosted MCP connector, so installing the
  plugin connected it. **Superseded** — see Unreleased.
- The Codex listing describes the connector and no longer says writes need the
  CLI.
- A Privacy section in the README: what the CLI collects, where it goes, how
  long it lives, and how to switch analytics off
  (`BOOKIPI_NO_ANALYTICS=1` or `DO_NOT_TRACK=1`).
- The README's Commands section now lists the actual command surface.
- Issue templates, this changelog, and a CI guard covering version drift across
  the manifests, a tag mismatch, the two skill copies diverging, and a declared
  connector URL that is not answering.

### Changed
- The plugin manifests declared `MIT` while `LICENSE` reserves all rights. They
  now say `Proprietary`, which is what the licence has always said.
- The skill's MCP path was teaching a dispatcher that 0.37.0 retired and still
  called the connector read-only, which ended in 0.36.0. Both corrected — and
  then removed entirely in the next release, see Unreleased.
- `LICENSE` points at the [Terms of Service](https://bookipi.com/terms-of-service/)
  rather than the separate website Terms & Conditions page.

## 0.37.1 — 2026-09-01

### Fixed
- Relay login silently discarded its session in sandboxed agents, so sign-in
  could never complete there.

## 0.37.0 — 2026-08-31

### Added
- Codex and Gemini CLI manifests: the plugin now installs on Codex (with the
  Bookipi icon and starter prompts) and as a Gemini CLI extension.
- Every MCP read is advertised as its own tool. The `search_tools` /
  `describe_tools` / `execute_tool` dispatcher is retired.
- Analytics record which LLM platform is calling, and how.

### Fixed
- The same skill could register twice in Claude Code — once from
  auto-discovery, once from the manifest — and was charged twice in the context
  budget.
- A server boot was reported as `CLI Command Completed`.

## 0.36.0 — 2026-08-21

### Added
- Invoice previews rendered as the customer will see them, each on one stable
  link.
- The MCP write surface: 24 operations across 16 tools, packaged by entity,
  plus `create_invoice`, `update_invoice`, `delete_invoice` and `send_invoice`
  with before/after previews on the ones that change existing records.
- Dashboards, website previews, site and app links over MCP.
- `document_numbering`, and ten further read operations.
- Writes are advertised by default; `--allow-writes` is gone.

### Fixed
- OAuth refresh did not actually renew the Bookipi token.
- The duplicate guard refused legitimate second invoices.
- Dates were reported as UTC instants rather than dates.
- Deal `per_page` multiplied the result set instead of bounding it; digest
  stage counts reported the fetch cap.
- Login: one mechanism, the credential folder is created, and the CLI no longer
  writes `~/.bookipi.json`.

## 0.35.3 — 2026-08-20

### Added
- The skill bootstraps the CLI from the public release when none is installed,
  so a plugin install needs nothing else.

## 0.35.2 — 2026-08-20

### Fixed
- Credentials were written into the skill source tree.

## 0.35.1 — 2026-08-20

### Added
- The skill is path-aware and ships as a plugin.
- MCP reads for customers, items, expenses, deals, proposals, contracts,
  invoice and customer detail, paylinks and reports; any company per call via
  an optional `company_id`.

### Fixed
- GraphQL errors leaked the backend's stack trace.
- Invoice numbering was invented rather than read from the company.
- The default company resolved by array order instead of from the account.
- Insights were addressed to a customer called "Unknown".

## 0.35.0 — 2026-08-19

### Changed
- Much smaller MCP tool responses.

### Added
- Per-conversation analytics sessions with real outcomes, and token cost
  reported on MCP tool calls.

### Fixed
- Benchmarks and tests were reporting to Amplitude as real usage.

## 0.34.0 — 2026-08-18

Earlier releases are listed under
[Releases](https://github.com/Bookipi-Group/bookipi-cli/releases).

> 0.18.0 – 0.33.x shipped without changelog entries.

## 0.17.0 — 2026-06-12

### Added
- `bookipi invoice preview --pdf` — renders the invoice and converts it to a
  real PDF via Bookipi's HTML-to-PDF service. Composes with `--output`,
  `--stdout` (pipes raw PDF bytes), and `--json` (adds `format: "pdf"`).
- New `PDF_SERVICE_URL` config key (baked from `.env.staging` / `.env.prod`,
  overridable via `.env` or the environment at runtime).
- Smoke tests for `invoice send`, `invoice create`, and `invoice preview`
  (the highest-stakes commands; `invoice send` had no coverage despite
  emailing customers).
- A Node-runtime guard: on Node older than 22.12 the CLI now exits with a
  clear message instead of crashing opaquely inside undici.

### Changed
- Skill docs now steer invoice preview/print/render requests to `--pdf`
  first, with the offline HTML preview as the fallback when the PDF service
  is unreachable.
- Project tooling migrated from npm to pnpm: `pnpm-lock.yaml` replaces
  `package-lock.json`, scripts/CI/docs use pnpm commands, and the pnpm
  version is pinned via the `packageManager` field.
- `engines.node` raised to `>=22.12.0` to match the real dependency floor.
- Skill/docs corrections: the `expense` verb list now reflects the real
  commands (`list`/`delete` exist; no `get`/`update`); the `contract send`
  routing note explains the web-editor prerequisite for signers/tags.
- `package.json` `files` narrowed to ship only `docs/REFERENCE.md` (not the
  whole `docs/` dir) so internal guides never leak via `npm publish`.

### Fixed
- `invoice preview` now prints an absolute `file://` link even when
  `--output` is given a relative path (was an unclickable `file://./…`).
- Added a 30s timeout to GraphQL and token-refresh requests — a hung backend
  no longer stalls the agent turn indefinitely.
- The packaged `.skill` now ships `bin/package.json` (`type: module`) so the
  bundle parses as ESM on any Node and the version guard can fire (instead of
  a raw `SyntaxError`) on older runtimes.
