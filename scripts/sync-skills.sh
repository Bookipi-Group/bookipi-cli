#!/usr/bin/env bash
#
# Keep the published skill trees identical.
#
# Canonical source: skills/
#   Gemini CLI requires the tree at exactly ./skills/ (gemini-extension.json),
#   and both .claude-plugin/plugin.json and .codex-plugin/plugin.json point at
#   the same directory. Pointing them elsewhere double-registers the skill:
#   Claude Code auto-discovers ./skills/ on top of the manifest path, which cost
#   ~517 always-on tokens instead of ~259 when the two disagreed.
#
# Mirror: .agents/skills/
#   README documents this as the path other agents (Cursor, Copilot,
#   Antigravity, Windsurf) copy from, so it ships as a real directory rather
#   than a symlink. Claude Code does not auto-discover it, so it costs nothing.
#
# Usage:
#   scripts/sync-skills.sh           mirror canonical -> .agents/skills
#   scripts/sync-skills.sh --check   exit non-zero if the mirror has drifted

set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE=skills
TARGETS=(.agents/skills)

check_mode=false
case "${1:-}" in
  --check) check_mode=true ;;
  '') ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

if [ ! -d "$SOURCE" ]; then
  echo "error: canonical skill tree missing at $SOURCE" >&2
  exit 1
fi

status=0

for target in "${TARGETS[@]}"; do
  if $check_mode; then
    if [ ! -d "$target" ]; then
      echo "drift: $target is missing" >&2
      status=1
      continue
    fi
    if diff -rq "$SOURCE" "$target" >/dev/null 2>&1; then
      echo "ok: $target matches $SOURCE"
    else
      echo "drift: $target does not match $SOURCE" >&2
      diff -rq "$SOURCE" "$target" 2>&1 | sed 's/^/  /' >&2
      status=1
    fi
  else
    mkdir -p "$target"
    rsync -a --delete "$SOURCE"/ "$target"/
    echo "synced: $SOURCE -> $target"
  fi
done

if $check_mode && [ "$status" -ne 0 ]; then
  echo >&2
  echo "The skill copies have drifted. Edit $SOURCE, then run:" >&2
  echo "  scripts/sync-skills.sh" >&2
fi

exit "$status"
