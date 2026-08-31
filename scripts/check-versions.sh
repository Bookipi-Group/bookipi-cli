#!/usr/bin/env bash
#
# Every provider manifest carries its own version string. A publish that bumps
# one and forgets another ships mismatched metadata to that provider's listing.
# This asserts they all agree.
#
# Usage: scripts/check-versions.sh

set -euo pipefail

cd "$(dirname "$0")/.."

table=$(python3 - <<'PY'
import json

# (file, dotted path to the version string)
FIELDS = [
    ('.claude-plugin/plugin.json',      'version'),
    ('.claude-plugin/marketplace.json', 'metadata.version'),
    ('.claude-plugin/marketplace.json', 'plugins.0.version'),
    ('.codex-plugin/plugin.json',       'version'),
    ('gemini-extension.json',           'version'),
]

def dig(doc, path):
    cur = doc
    for part in path.split('.'):
        cur = cur[int(part)] if part.isdigit() else cur[part]
    return cur

for path, field in FIELDS:
    with open(path) as fh:
        doc = json.load(fh)
    try:
        print(f'{dig(doc, field)}\t{path} ({field})')
    except (KeyError, IndexError):
        print(f'MISSING\t{path} ({field})')
PY
)

echo "$table" | while IFS=$'\t' read -r version where; do
  printf '  %-10s %s\n' "$version" "$where"
done

distinct=$(echo "$table" | cut -f1 | sort -u | wc -l | tr -d ' ')

if [ "$distinct" -ne 1 ]; then
  echo
  echo "error: manifest versions disagree — see the table above" >&2
  exit 1
fi

echo
echo "ok: all manifests at $(echo "$table" | head -1 | cut -f1)"
