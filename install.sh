#!/bin/sh
##############################################################################
# zapret-gui installer for AsusWRT-Merlin
# Run over SSH:
#   curl -fsSL https://raw.githubusercontent.com/Jarvis322/Asus-Merlin-Zapret-GUI/main/install.sh | sh
##############################################################################
REPO="https://raw.githubusercontent.com/Jarvis322/Asus-Merlin-Zapret-GUI/main"
DIR="/jffs/addons/zapret-gui"

echo "==> zapret-gui installer"

# sanity checks
[ -f /usr/sbin/helper.sh ] || { echo "ERROR: this is not AsusWRT-Merlin (no helper.sh)"; exit 1; }
[ -x /opt/zapret/init.d/sysv/zapret ] || echo "WARN: zapret not found at /opt/zapret (you can still install the GUI and use its 'Install' button)"
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found (install Entware / 'opkg install curl')"; exit 1; }
[ "$(nvram get jffs2_scripts)" = "1" ] || echo "WARN: enable 'Administration -> System -> Enable JFFS custom scripts and configs' for boot persistence"

mkdir -p "$DIR"
for f in zapret-gui.sh zapret-gui.asp; do
	echo "  downloading $f ..."
	curl -fsSL "$REPO/$f" -o "$DIR/$f" || { echo "ERROR: download failed for $f"; exit 1; }
done
chmod 0755 "$DIR/zapret-gui.sh"

"$DIR/zapret-gui.sh" install

echo
echo "Done. Open the router web UI -> 'Network Tools' -> 'zapret' tab."
echo "Hard-refresh the browser (Ctrl/Cmd+Shift+R) so the menu reloads."
echo "Uninstall any time with:  $DIR/zapret-gui.sh uninstall"
