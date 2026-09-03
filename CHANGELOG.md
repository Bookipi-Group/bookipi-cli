# Changelog

User-facing changes to Bookipi CLI, the skill bundle, and the plugin manifests.
Each version is a [release](https://github.com/Bookipi-Group/bookipi-cli/releases)
with a `bookipi-cli.skill` attached.

A note on upgrading: the plugin cache is keyed by version, so content published
under a version you already have will not reach you. `claude plugin update`
reports "already at the latest version" and keeps serving the cached copy —
refresh the marketplace first (`/plugin marketplace update bookipi-cli`).

## 0.38.1 — 2026-09-02

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
