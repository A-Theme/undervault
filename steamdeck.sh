#!/usr/bin/env bash
# Lanterns of the Undervault: Steam Deck (and any Linux with Flatpak) installer.
#
# In Desktop Mode, open Konsole and run one of these:
#   curl -fsSL https://playundervault.com/steamdeck.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/A-Theme/undervault/main/steamdeck.sh | bash
#
# It makes a "Lanterns of the Undervault" app that opens the game full-screen in a browser, with its icon and
# Steam artwork, and adds it to your Steam library so it starts from Game Mode like any other game. If you have no
# browser it installs Chromium from Flathub, for your user only. Nothing needs sudo. Run it again to update it;
# run it with --uninstall to remove it. Your saves live in that browser: Menu > Export save backs a hero up.
set -euo pipefail

URL="https://playundervault.com/"
NAME="Lanterns of the Undervault"
APPS="$HOME/.local/share/applications"
ICON="$HOME/.local/share/icons/hicolor/512x512/apps/undervault.png"
HOME_DIR="$HOME/.local/share/undervault"
DESKTOP="$APPS/undervault.desktop"
say(){ printf '\033[1;33m%s\033[0m\n' "$*"; }

if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$DESKTOP" "$ICON"; rm -rf "$HOME_DIR"
  say "Removed the launcher. If Steam still lists the game, remove it from your library there."
  exit 0
fi

command -v flatpak >/dev/null || { echo "This needs Flatpak, which SteamOS has in Desktop Mode."; exit 1; }
command -v curl >/dev/null || { echo "This needs curl."; exit 1; }

# A Chromium-based browser gives the cleanest window (no address bar); Firefox works too.
BROWSER=""
for app in com.google.Chrome org.chromium.Chromium com.microsoft.Edge com.brave.Browser org.mozilla.firefox; do
  if flatpak info "$app" >/dev/null 2>&1; then BROWSER="$app"; break; fi
done
if [ -z "$BROWSER" ]; then
  say "No browser found, so installing Chromium from Flathub (for your user only)..."
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  flatpak install --user -y flathub org.chromium.Chromium
  BROWSER=org.chromium.Chromium
fi
say "Using $BROWSER."
# Controllers reach the browser through /dev/input, so make sure its sandbox can see them.
flatpak override --user --device=all "$BROWSER" || true

mkdir -p "$APPS" "$(dirname "$ICON")" "$HOME_DIR/art"
curl -fsSL "${URL}icon-512.png" -o "$ICON"
for f in capsule.png wide.png hero.png logo.png; do curl -fsSL "${URL}steam/$f" -o "$HOME_DIR/art/$f" || true; done

if [ "$BROWSER" = org.mozilla.firefox ]; then ARGS="--kiosk $URL"; else ARGS="--app=$URL --start-fullscreen"; fi
cat > "$HOME_DIR/undervault.sh" <<EOF
#!/usr/bin/env bash
# Starts $NAME full-screen in $BROWSER. Made by the Undervault installer.
exec flatpak run $BROWSER $ARGS
EOF
chmod +x "$HOME_DIR/undervault.sh"

cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
Comment=A text dungeon in the old MUD style
Exec=$HOME_DIR/undervault.sh
Icon=$ICON
Terminal=false
Categories=Game;RolePlaying;
EOF
chmod +x "$DESKTOP"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" >/dev/null 2>&1 || true

echo
if command -v steamos-add-to-steam >/dev/null; then
  steamos-add-to-steam "$DESKTOP" >/dev/null 2>&1 && say "Added to your Steam library." || say "Could not reach Steam: add it from Steam > Games > Add a Non-Steam Game."
else
  say "Now add it to Steam: Steam > Games > Add a Non-Steam Game to My Library, and tick \"$NAME\"."
fi
cat <<EOF

Done. In Game Mode it is in your library under Non-Steam.
 - Controller: if the buttons do nothing in the game, open its controller settings and pick the Gamepad layout.
 - Artwork: on its page, open Properties > Customization (or Manage > Set custom artwork) and pick the images in
   $HOME_DIR/art (capsule.png, wide.png, hero.png, logo.png).
 - Saves live in $BROWSER. In the game, Menu > Export save gives you a short code to back a hero up.
EOF
