# Changelog

User-facing changes to Bookipi CLI, the skill bundle, and the plugin manifests.
Each version is a [release](https://github.com/Bookipi-Group/bookipi-cli/releases)
with a `bookipi-cli.skill` attached.

A note on upgrading: the plugin cache is keyed by version, so content published
under a version you already have will not reach you. `claude plugin update`
reports "already at the latest version" and keeps serving the cached copy —
refresh the marketplace first (`/plugin marketplace update bookipi-cli`).

## Unreleased

### Changed
- The plugin manifests declared `MIT` while `LICENSE` reserves all rights. They
  now say `Proprietary`, which is what the licence has always said.
- The skill's MCP path was teaching a dispatcher that 0.37.0 retired, and still
  described the connector as read-only. It now calls the operation tools
  directly, and writes are documented as available on both paths.
- `LICENSE` points at the [Terms of Service](https://bookipi.com/terms-of-service/)
  rather than the separate website Terms & Conditions page.

### Added
- The plugin declares the hosted connector: installing it in Claude Code
  (`mcpServers`) or as a Gemini CLI extension (`httpUrl`) now connects
  `https://mcp.bookipi.com/mcp` as well as installing the skill. Sign-in is the
  browser OAuth flow, discovered from the server — no client ID to configure.
- A Privacy section in the README: what the CLI collects, where it goes, how
  long it lives, and how to switch analytics off
  (`BOOKIPI_NO_ANALYTICS=1` or `DO_NOT_TRACK=1`).
- The README's Commands section now lists the actual command surface.

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
