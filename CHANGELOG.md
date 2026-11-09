# Changelog

User-facing changes to Bookipi CLI, the skill bundle, and the plugin manifests.
Each version is a [release](https://github.com/Bookipi-Group/bookipi-cli/releases)
with a `bookipi-cli.skill` attached.

A note on upgrading: the plugin cache is keyed by version, so content published
under a version you already have will not reach you. `claude plugin update`
reports "already at the latest version" and keeps serving the cached copy —
refresh the marketplace first (`/plugin marketplace update bookipi-cli`).

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
