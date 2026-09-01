# bookipi-cli (public release repo)

## This repo is GENERATED — do not hand-edit the published paths

Almost everything here is produced by `scripts/publish-plugin.mjs` in the
**source** repo and committed by its release workflow. A hand-edit to a
generated path is silently overwritten by the next release.

**Source of truth:** `Bookipi-Group/bookipi-agent-cli`
(local checkout: `~/Development/bookipi/bookipi-cli` — the directory names are
crossed against the GitHub names, so confirm `git remote -v` before editing.)

### Generated — edit in the source repo instead

| Path | Authored at (source repo) |
| --- | --- |
| `skills/bookipi-cli/` | `.claude/skills/bookipi-cli/` |
| `.agents/skills/bookipi-cli/` | same — published twice, one source |
| `.claude-plugin/plugin.json`, `marketplace.json` | same path |
| `.codex-plugin/plugin.json` | same path |
| `gemini-extension.json` | same path |
| `assets/` | same path |

Version strings in all four manifests are **stamped at publish time** from the
source repo's `package.json`. Never bump them here — the plugin cache is keyed
by version, so a mismatch ships a manifest claiming the wrong release.

### Maintained here (safe to edit)

`README.md`, `SECURITY.md`, `LICENSE`, and `.github/workflows/release.yml`
(the `.skill` bundle smoke test — distinct from the source repo's release
pipeline of the same name).

## To change a skill or a manifest

1. Edit it in the source repo (`.claude/skills/bookipi-cli/` for skill content).
2. `node scripts/publish-plugin.mjs --dry-run` there to see the publish set.
3. Bump the version and tag `v*` — the release workflow regenerates this repo.

Content published under an unchanged version never reaches anyone who already
installed: `claude plugin update` reports "already at the latest version" and
serves the stale cache. So skill edits ship on a version bump, not on their own.

## Gotcha: the skill must not register twice

Claude Code auto-discovers `./skills/` **on top of** the path
`.claude-plugin/plugin.json` declares. If the manifest names a different
directory than the one auto-discovery finds, the same skill registers twice and
is charged twice (`Skills (2)`, ~517 tok instead of ~259 — check with
`claude plugin details bookipi@bookipi-cli`).

`skills/` is the shared directory: Gemini CLI only looks there, and both plugin
manifests point at it. Keep them pointing at the same place. `.agents/skills/`
is safe alongside it — Claude Code does not auto-discover that path.

Codex is also safe, though for a different reason, and it is worth writing down
because you cannot check it from disk — Codex resolves its skill registry at
runtime and persists nothing. Its spec says a declared `skills` path is
"supplemented on top of default component discovery", so `.codex-plugin`'s
`skills: "./skills/"` plus the `.agents/skills/` copy looks like the same
double-register trap. It is not: Codex de-duplicates by skill **name**. Verified
by hand on the 0.37.0 listing (`Manage › bookipi` reads `Skills 1`). The only
way to re-check is that screen.

## Install surfaces

Only the Codex manifest has a branding block (icon, logo, `brandColor`).
Claude Code's plugin schema has no icon field, and neither does Gemini CLI's
`gemini-extension.json` — so the logo is Codex-only by design, not an oversight.
