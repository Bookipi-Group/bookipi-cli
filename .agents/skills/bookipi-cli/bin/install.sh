#!/bin/sh
# Bookipi CLI installer — for using the `bookipi` command on its own, without
# the Claude skill or plugin (which already ship the CLI inside them).
#
#   curl -fsSL https://github.com/Bookipi-Group/bookipi-cli/releases/latest/download/install.sh | sh
#
# It installs the latest release (BOOKIPI_VERSION=x.y.z picks another), and
# checks the download against the SHA-256 published with that release.
#
# It installs to ~/.local/share/bookipi-cli and puts a `bookipi` launcher in
# ~/.local/bin. It needs Node 22.12+ and never installs Node, and it never
# edits shell profile files — if ~/.local/bin isn't on PATH it says what to add.
#
# Re-running it: if this version is already installed it does nothing; if
# another one is, it asks first (BOOKIPI_YES=1 answers yes, for runs with no
# terminal to ask on — without it they exit 2 and change nothing).
#
# A copy also ships in the skill's bin/ (and the archive's), beside bookipi.js.
# Run from there (`sh <dir>/install.sh`) it installs that CLI instead of
# downloading one, never asks (it updates an older copy and keeps a newer one),
# and does nothing in Cowork, whose home folder doesn't outlive the session.
# The skill uses this to give its user a `bookipi` command (SKILL.md Step 1).
#
# Overrides: BOOKIPI_VERSION, BOOKIPI_INSTALL_DIR, BOOKIPI_BIN_DIR, BOOKIPI_YES,
# and BOOKIPI_ARCHIVE (a local archive, with its .sha256 beside it, to install
# instead of downloading — the release pipeline's own test; needs
# BOOKIPI_VERSION).

set -eu

INSTALL_DIR="${BOOKIPI_INSTALL_DIR:-$HOME/.local/share/bookipi-cli}"
BIN_DIR="${BOOKIPI_BIN_DIR:-$HOME/.local/bin}"

fail() {
  echo "bookipi install: $*" >&2
  exit 1
}

# Node 22.12+ — the CLI's own floor (src/assertNodeVersion.ts).
command -v node >/dev/null 2>&1 ||
  fail "Node.js 22.12 or newer is required. Install it from https://nodejs.org, then run this again."
node -e '
  const [maj, min] = process.versions.node.split(".").map(Number);
  process.exit(maj > 22 || (maj === 22 && min >= 12) ? 0 : 1);
' || fail "Node.js 22.12 or newer is required (found $(node --version)). Update it from https://nodejs.org, then run this again."

# For the skill: from a bundle, the last line says how this shell reaches the
# installed `bookipi` — directly, or only with BIN_DIR put first on PATH.
how_to_run() {
  [ -n "$BUNDLE" ] || return 0
  if [ "$(command -v bookipi)" = "$BIN_DIR/bookipi" ]; then
    echo "Run it as: bookipi"
  else
    echo "Run it as: export PATH=\"$BIN_DIR:\$PATH\"; bookipi"
  fi
}

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$1" -O "$2"
  else
    fail "curl or wget is required."
  fi
}

# Run from beside a bookipi.js (and not asked for a release), install that one.
# Piped from curl, $0 is the shell, so this never triggers.
BUNDLE=""
case "$0" in
  install.sh | */install.sh) BUNDLE="$(cd "$(dirname "$0")" && pwd)" ;;
esac
[ -z "${BOOKIPI_VERSION:-}${BOOKIPI_ARCHIVE:-}" ] && [ -f "$BUNDLE/bookipi.js" ] || BUNDLE=""
[ -n "$BUNDLE" ] && [ -d /sessions ] && exit 0

# Which release to install: the bundle's, else the one asked for, else the
# latest. The latest is read from where github.com/…/releases/latest redirects
# (…/tag/vX.Y.Z), not the API, which rate-limits shared IPs (offices, CI,
# sandboxes); curl and wget also honour the user's proxy settings.
if [ -n "$BUNDLE" ]; then
  VERSION="$(cat "$BUNDLE/.version" 2>/dev/null)" || fail "no .version beside $0 — rebuild the skill."
elif [ -n "${BOOKIPI_VERSION:-}" ]; then
  VERSION="${BOOKIPI_VERSION#v}"
elif [ -n "${BOOKIPI_ARCHIVE:-}" ]; then
  fail "BOOKIPI_ARCHIVE needs BOOKIPI_VERSION set to the archive's version."
else
  latest="https://github.com/Bookipi-Group/bookipi-cli/releases/latest"
  if command -v curl >/dev/null 2>&1; then
    tag_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$latest")" || tag_url=""
  elif command -v wget >/dev/null 2>&1; then
    tag_url="$(wget -S --spider "$latest" 2>&1 | sed -n 's/^ *[Ll]ocation: *\([^ ]*\).*/\1/p' | tail -n 1 | tr -d '\r')"
  else
    fail "curl or wget is required."
  fi
  case "$tag_url" in
    */tag/v*) VERSION="${tag_url##*/tag/v}" ;;
    *) fail "couldn't look up the latest Bookipi release on GitHub. Check your connection, or set BOOKIPI_VERSION." ;;
  esac
fi
case "$VERSION" in
  "" | *[!0-9.]*) fail "unexpected release version '$VERSION'." ;;
esac
RELEASE_URL="https://github.com/Bookipi-Group/bookipi-cli/releases/download/v$VERSION"

# What's installed already: each install writes current/.version. A copy with
# missing files falls through and is reinstalled, so re-running also repairs.
installed="$(cat "$INSTALL_DIR/current/.version" 2>/dev/null || :)"
if [ -n "$installed" ] && [ -x "$BIN_DIR/bookipi" ] && [ -f "$INSTALL_DIR/current/bin/bookipi.js" ]; then
  if [ "$installed" = "$VERSION" ]; then
    echo "Bookipi CLI $VERSION is already installed and up to date. Nothing to do."
    how_to_run
    exit 0
  fi
  older="$(printf '%s\n%s\n' "$installed" "$VERSION" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)"
  if [ "$older" = "$VERSION" ]; then
    if [ -n "$BUNDLE" ]; then
      echo "Kept Bookipi CLI $installed, which is newer than this one ($VERSION)."
      how_to_run
      exit 0
    fi
    question="Bookipi CLI $installed is installed, which is newer than the release being installed ($VERSION). Install $VERSION instead?"
    choices="[y/N]"
  else
    question="Bookipi CLI $installed is installed. Update to $VERSION?"
    choices="[Y/n]"
  fi
  if [ "${BOOKIPI_YES:-}" != "1" ] && [ -z "$BUNDLE" ]; then
    # Piped from curl, stdin is this script, so ask on the terminal itself —
    # but only when output goes to it too, or a captured run (an agent's shell)
    # would wait on a question nobody sees. No terminal fails loudly (exit 2)
    # rather than looking done.
    { [ -t 1 ] && printf '%s %s ' "$question" "$choices" >/dev/tty && read -r answer </dev/tty; } 2>/dev/null || {
      echo "$question There's no terminal to ask on: run this again in one, or with BOOKIPI_YES=1." >&2
      exit 2
    }
    [ "$choices" = "[Y/n]" ] && answer="${answer:-y}"
    case "$answer" in
      [Yy] | [Yy][Ee][Ss]) ;;
      *)
        echo "Kept $installed."
        exit 0
        ;;
    esac
  fi
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    fail "sha256sum or shasum is required to verify the download."
  fi
}

# The bundle's files are already here; anything else is fetched and checked.
if [ -z "$BUNDLE" ]; then
  command -v tar >/dev/null 2>&1 || fail "tar is required."
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  archive="$tmp/bookipi-cli.tar.gz"
  if [ -n "${BOOKIPI_ARCHIVE:-}" ]; then
    cp "$BOOKIPI_ARCHIVE" "$archive"
    cp "$BOOKIPI_ARCHIVE.sha256" "$archive.sha256"
  else
    download "$RELEASE_URL/bookipi-cli.tar.gz" "$archive" ||
      fail "couldn't download $RELEASE_URL/bookipi-cli.tar.gz. Releases from before the standalone installer don't have one."
    download "$RELEASE_URL/bookipi-cli.tar.gz.sha256" "$archive.sha256" ||
      fail "couldn't download the checksum for Bookipi $VERSION. Nothing was installed."
  fi
  expected="$(cut -d' ' -f1 <"$archive.sha256")"
  actual="$(sha256_of "$archive")"
  [ -n "$expected" ] && [ "$actual" = "$expected" ] ||
    fail "checksum mismatch for bookipi-cli.tar.gz (expected $expected, got $actual). Nothing was installed."
fi

# Unpack next to the old version, then swap it in, so a failed install leaves
# the previous one working.
mkdir -p "$INSTALL_DIR" "$BIN_DIR" 2>/dev/null ||
  fail "can't create $INSTALL_DIR or $BIN_DIR. Nothing was installed."
# Absolute, so the launcher works from any directory.
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
BIN_DIR="$(cd "$BIN_DIR" && pwd)"
staging="$INSTALL_DIR/.v$VERSION.partial"
rm -rf "$staging"
mkdir -p "$staging"
if [ -n "$BUNDLE" ]; then
  mkdir "$staging/bin"
  cp -R "$BUNDLE/." "$staging/bin/"
else
  tar -xzf "$archive" -C "$staging"
  [ -f "$staging/bin/bookipi.js" ] || fail "the archive has no bin/bookipi.js. Nothing was installed."
fi
echo "$VERSION" >"$staging/.version"
if [ -d "$INSTALL_DIR/current" ]; then
  rm -rf "$INSTALL_DIR/.previous"
  mv "$INSTALL_DIR/current" "$INSTALL_DIR/.previous"
fi
mv "$staging" "$INSTALL_DIR/current"
rm -rf "$INSTALL_DIR/.previous"

# The launcher passes its own dirs to the CLI, so the update notice can give the
# re-install command for this install (custom dirs included). A copy from a
# bundle is updated by updating the skill instead, so it leaves them out and
# the notice names the ways a skill is updated.
launcher="$BIN_DIR/bookipi"
dirs="BOOKIPI_INSTALL_DIR=\"$INSTALL_DIR\" BOOKIPI_BIN_DIR=\"$BIN_DIR\" "
[ -z "$BUNDLE" ] || dirs=""
cat >"$launcher" <<EOF
#!/bin/sh
${dirs}exec node "$INSTALL_DIR/current/bin/bookipi.js" "\$@"
EOF
chmod 755 "$launcher"

echo "Installed $("$launcher" --version) to $INSTALL_DIR/current"

# From a bundle, the skill handles sign-in, so there's no login step to suggest.
login=" and run \`bookipi login\`"
[ -z "$BUNDLE" ] || login=""
case ":$PATH:" in
  *":$BIN_DIR:"*) [ -z "$login" ] || echo "Run \`bookipi login\` to sign in." ;;
  *)
    echo
    echo "$BIN_DIR is not on your PATH. Add this line to your shell profile (~/.zshrc or ~/.bashrc):"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo "Then open a new terminal$login."
    ;;
esac
how_to_run
