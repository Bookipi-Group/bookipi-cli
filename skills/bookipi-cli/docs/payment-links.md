# Payment Links (BPay)

A **payment link** is a shareable URL that lets anyone pay the company a set
(or customer-entered) amount. Backed by Bookipi's BPay service — a separate
host from the main API. The CLI exposes create / list / get.

## Commands

```bash
bookipi paylink create --title "Deposit" --price 100 --currency USD   # create a link
bookipi paylink create --title "Donate" --allow-custom-amount         # payer enters the amount
bookipi paylink list                                                  # most recent links
bookipi paylink get <id>                                              # one link by _id
bookipi paylink status <id>                                           # has it been paid? amount collected + attempts
bookipi paylink send <id> --customer @c1 --to maria@acme.com          # email the link to a customer
```

## Creating a link

- `--title` is **required**. Provide either `--price` **or** `--allow-custom-amount`.
- `--price` takes a currency value (`100`, `100.00`) and is ×100 into minor
  units. If you already have integer minor units, use `--price-cents 10000`.
- `--currency` defaults to the company's currency; pass an ISO code (e.g. `USD`)
  to override.
- `--allow-custom-amount` lets the payer type their own amount; `--price` is
  then optional.
- The company is derived from the logged-in session automatically — there is no
  `--company` flag.
- **Payment-readiness gate:** `create` first verifies the company can actually
  collect. On the **BPay endpoint** it resolves the company via
  `whoami.defaultCompany` then requires `isStripeMerchant === true` **and**
  `stripeOnboardingStatus === "approved"` on `companiesOne`. Uses the same
  `BPAY_TOKEN` (no main session). If Stripe isn't connected + approved it
  refuses with a clear message — finish Stripe setup in BookiPay first. (Note:
  the main API's `bookipayOnboardingStatus` is **not** used — it doesn't reflect
  Stripe. `list`/`get` are not gated.)

On success the CLI prints the **shareable URL** (`{BPAY_APP_URL}/pay/{shortCode}`).
That link is the whole point — surface it to the user:

> Created a payment link for **$100.00** ("Deposit") — share it to get paid:
> https://app.bookipay.com/pay/nC7Gj1QZZZ0g

## Checking payment status

`bookipi paylink status <id>` shows what a link has **collected** — total
collected, number of payments, and each attempt.

⚠️ **A payment link is reusable** — it can collect many payments over time (e.g.
a "pay here" / donation link). So treat it as a **running collection, not a
one-time paid/unpaid** like an invoice. A payment counts when its `status` is
`"success"`; failed attempts show their `failedReason`.

```bash
bookipi paylink status 6760d3f6d74147618fe4ce9b
```
> Collected **$19.98** across 2 payments.

Report it as a collection: lead with the **total collected and payment count**
(not "paid/unpaid"); mention failed attempts only if relevant. For a link with
no successful payments yet, say "no payments yet". `--json` returns
`{ link, payments, summary }` (`summary.totalCollectedCents`, `successfulCount`,
`attempts`).

If the user wants to track this **on a schedule**, offer two options: schedule just
this link's check, or fold it into **one daily status sweep** that also covers
invoices, proposals, and contracts — see `docs/morning-brief.md` § Scheduling.

## Sending a link to a customer

`bookipi paylink send <id> --customer <handle|id|name> --to <email>` emails the
link via the app's customer-email channel (`customersSendEmail`). It composes
the subject + body from the link (title, amount, the `/pay/…` URL); `--message`
adds a note, `--subject` overrides the subject, `--cc` adds CCs.

```bash
bookipi paylink send 6a395a7f37ea7b75e924c2f2 --customer @c1 --to maria@acme.com --message "Thanks for your business!"
```

⚠️ Customer email currently depends on a backend recaptcha-bypass for
authenticated CLI requests — until that ships the server may return a recaptcha
error. If so, fall back to just handing the user the `/pay/…` URL (from `create`
or `get`). There is no native BPay "send payment link" endpoint; this is a thin
wrapper over the main app's customer email.

## Presentation rules

- Refer to a link by its **title and amount**, and always give the user the
  **share URL**. Don't dump the raw `_id`, `shortCode`, or full JSON.
- For `list`, summarise (title — amount — status — link), newest first.

## Notes & current limits

- **Amount unit:** `price` is integer minor units (e.g. `10000` == `$100.00`),
  the same ×100 convention as the rest of the CLI.
- **No update / delete yet** — only create / list / get are wired. To change a
  link, recreate it (and ask the user before creating duplicates).
- **Auth:** the CLI **mints a BPay token automatically from your main Bookipi
  session** — it calls `BOOKIPI_URL/payment-links/auth?token=<bookipiToken>&companyId=<companyId>`
  and reads the BPay token (and `onboardStatus`/`acceptCardPayments`) from the
  302 redirect. So just `bookipi login`; no manual token. (`BPAY_TOKEN` env
  still overrides the mint for testing.)
- **Hosts:** API `BPAY_URL`, public links `BPAY_APP_URL` — note these are on
  the **`bookipay.com`** domain in prod, not `bookipi.com`. Staging:
  `bpay-dev.bkpi.co` / `bpay-app.bkpi.co`. Prod: `s.bookipay.com` /
  `app.bookipay.com` (both verified to resolve + the API responds). Both are
  env-overridable.
