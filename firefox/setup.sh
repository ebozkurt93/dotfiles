#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./setup.sh           — full setup (quarantine removal, native host, policy, extension)
#                          Run once after installing Firefox or when policies change.
#                          Requires terminal to have App Management + Full Disk Access
#                          in System Settings → Privacy & Security.
#   ./setup.sh --reload  — rebuild extension XPI and open install dialog in Firefox.
#                          Use after changing background.js. Click "Add" in Firefox.

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIREFOX_APP="/Applications/Firefox Developer Edition.app"
NATIVE_MESSAGING_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"

RELOAD_ONLY=false
[[ "${1:-}" == "--reload" ]] && RELOAD_ONLY=true

fail() { echo "ERROR: $*" >&2; exit 1; }

check_no_placeholder() {
  grep -q "__DOTFILES_DIR__" "$1" && fail "$1 still contains __DOTFILES_DIR__ placeholder" || true
}

check_nonempty() {
  [[ -s "$1" ]] || fail "$1 is empty"
}

if [[ "$RELOAD_ONLY" == false ]]; then
  # 0. Remove quarantine so the app bundle can be modified
  echo "Removing quarantine from Firefox Developer Edition..."
  sudo xattr -rd com.apple.quarantine "$FIREFOX_APP"
fi

# 1. Build unsigned XPI with auto-bumped version (minutes since epoch, max 8 digits)
echo "Building extension XPI..."
TMP_EXT=$(mktemp -d)
python3 -c "
import json, time
m = json.load(open('$DOTFILES_DIR/firefox/extension/manifest.json'))
m['version'] = '1.0.' + str(int(time.time() // 60))
print('  version:', m['version'])
json.dump(m, open('$TMP_EXT/manifest.json', 'w'), indent=2)
"
cp "$DOTFILES_DIR/firefox/extension/background.js" "$TMP_EXT/"
rm -f "$DOTFILES_DIR/firefox/extension/bridge.xpi"
(cd "$TMP_EXT" && zip "$DOTFILES_DIR/firefox/extension/bridge.xpi" manifest.json background.js)
rm -rf "$TMP_EXT"
check_nonempty "$DOTFILES_DIR/firefox/extension/bridge.xpi"
echo "  → $DOTFILES_DIR/firefox/extension/bridge.xpi"

if [[ "$RELOAD_ONLY" == false ]]; then
  # 2. Make native host scripts executable
  chmod +x "$DOTFILES_DIR/firefox/native-host/firefox_bridge.py"
  chmod +x "$DOTFILES_DIR/firefox/native-host/bridge_send.py"

  # 3. Install native messaging host manifest (substitute __DOTFILES_DIR__ placeholder)
  echo "Installing native messaging host manifest..."
  mkdir -p "$NATIVE_MESSAGING_DIR"
  rm -f "$NATIVE_MESSAGING_DIR/firefox_bridge.json"  # remove stale symlink if present
  sed "s|__DOTFILES_DIR__|$DOTFILES_DIR|g" \
    "$DOTFILES_DIR/firefox/native-host/firefox_bridge.json" \
    > "$NATIVE_MESSAGING_DIR/firefox_bridge.json"
  check_nonempty "$NATIVE_MESSAGING_DIR/firefox_bridge.json"
  check_no_placeholder "$NATIVE_MESSAGING_DIR/firefox_bridge.json"
  echo "  → $NATIVE_MESSAGING_DIR/firefox_bridge.json"

  # 4. Install enterprise policy into app bundle (substitute __DOTFILES_DIR__ placeholder)
  echo "Installing enterprise policy..."
  DIST_DIR="$FIREFOX_APP/Contents/Resources/distribution"
  mkdir -p "$DIST_DIR"
  sed "s|__DOTFILES_DIR__|$DOTFILES_DIR|g" \
    "$DOTFILES_DIR/firefox/policies/policies.json" \
    > "$DIST_DIR/policies.json"
  check_nonempty "$DIST_DIR/policies.json"
  check_no_placeholder "$DIST_DIR/policies.json"
  echo "  → $DIST_DIR/policies.json"
fi

# 5. Trigger extension install/update — opens install dialog in Firefox (one click)
echo "Opening extension in Firefox..."
open -a "Firefox Developer Edition" "$DOTFILES_DIR/firefox/extension/bridge.xpi"

echo ""
echo "Done. Click 'Add' in Firefox to install/update the extension."
