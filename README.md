# Asus-Merlin-Zapret-GUI

A web UI addon for managing [zapret](https://github.com/bol-van/zapret) (DPI bypass) directly from the **AsusWRT‑Merlin** router interface — no more editing config files over SSH.

It adds a **zapret** tab under **Network Tools** with live status, one‑click control, an editable strategy/hostlist editor, a blockcheck runner and a log viewer.

> 🇹🇷 zapret'i (DPI atlatma) **AsusWRT‑Merlin** router arayüzünden yönetmek için bir web eklentisi. Artık config dosyalarını SSH'tan düzenlemenize gerek yok — **Ağ Araçları → zapret** sekmesinden her şeyi yönetin.

---

## Features / Özellikler

- **Live status** — enabled, `nfqws` running/PID, iptables NFQUEUE rules, packet counter, mode, ports
- **One‑click control** — Enable / Disable / Restart
- **Editable settings** — desync strategy (`fake`, `fakedsplit`, `fakeddisorder`, `disorder2`, `split2`, `multisplit`), TTL, TCP ports, filter mode (`hostlist` / `autohostlist` / `all`)
- **Hostlist editor** — edit the user hostlist in a textarea with a live line counter; works for lists of any size (auto‑chunked)
- **Blockcheck** runner (background) + **log viewer**
- **Optional installer** — a button to download zapret if it isn't installed yet (experimental)
- Config is **backed up** to `config.bak-gui` on every apply
- **Survives** httpd restarts, firewall reloads and reboots (self re‑mounts)

## Requirements / Gereksinimler

- **AsusWRT‑Merlin** firmware (needs `/usr/sbin/helper.sh` and custom web pages support)
- **zapret** installed at `/opt/zapret` (standard Entware layout). If not installed, use the GUI's *Install* button or install it manually first.
- **Entware** with `curl` (`opkg install curl`) — for the installer
- **Enable JFFS custom scripts and configs**: *Administration → System* (for boot persistence)

## Installation / Kurulum

SSH into the router and run:

```sh
curl -fsSL https://raw.githubusercontent.com/Jarvis322/Asus-Merlin-Zapret-GUI/main/install.sh | sh
```

Then open the router web UI → **Network Tools → zapret** and **hard‑refresh** the browser (Ctrl/Cmd + Shift + R) so the menu reloads.

### Manual install

```sh
mkdir -p /jffs/addons/zapret-gui
cd /jffs/addons/zapret-gui
curl -fsSLO https://raw.githubusercontent.com/Jarvis322/Asus-Merlin-Zapret-GUI/main/zapret-gui.sh
curl -fsSLO https://raw.githubusercontent.com/Jarvis322/Asus-Merlin-Zapret-GUI/main/zapret-gui.asp
chmod +x zapret-gui.sh
./zapret-gui.sh install
```

## Uninstall / Kaldırma

```sh
/jffs/addons/zapret-gui/zapret-gui.sh uninstall
```

This removes the menu entry, the mounted page and the boot/service hooks. Your zapret install and config are left untouched.

## How it works / Nasıl çalışır

The addon page is mounted into a free `userN.asp` slot and injected into the `menuTree.js` Network Tools menu (re‑applied automatically after httpd restarts and reboots).

The interesting part is **how settings get from the browser to the router**. On some Merlin builds (observed on **RT‑BE92U 3.0.0.6.102.8**) the built‑in `httpd` will fire an `rc_service` event from a web POST **but does not persist custom nvram / `amng_custom` / `custom_settings` fields** — so the usual "save settings" mechanisms silently do nothing.

The only reliable web→backend channel that survives is the **`rc_service` event name** itself. So `zapret-gui`:

1. Encodes the settings + hostlist as a `base64url` blob in the browser.
2. Splits it into `<128`‑char chunks (httpd truncates long `rc_service` names).
3. Streams the chunks through sequential events: `restart_zgR<chunk>` (reset), `restart_zgA<chunk>` (append), `restart_zgZ` (apply).
4. The backend reassembles the blob, decodes it and rewrites `/opt/zapret/config` + the hostlist, then restarts zapret.

If your firmware *does* persist web POST fields, this still works — it just uses a channel that always works.

### Persistence hooks

| Event | Hook |
|-------|------|
| httpd restart (tmpfs `/www` rebuilt) | `service-event-end` re‑mounts the page + menu |
| Reboot | `services-start` re‑mounts |

## Notes & limitations

- The UI text is **Turkish**. It's plain HTML/JS — translate the labels in `zapret-gui.asp` if you like.
- The menu is injected after `Advanced_Wireless_Survey.asp` (Network Tools → Site Survey). If your firmware's `menuTree.js` differs, change `MENU_ANCHOR` at the top of `zapret-gui.sh`.
- Assumes the standard zapret layout: `/opt/zapret/config`, `/opt/zapret/init.d/sysv/zapret`, `/opt/zapret/ipset/zapret-hosts-user.txt`.
- The *Install* and *Blockcheck* buttons are best‑effort/experimental (blockcheck is normally interactive).
- Tested on RT‑BE92U (Merlin 3.0.0.6.102.8). Should work on other Merlin builds; open an issue if the menu doesn't appear.

## Credits

- [zapret](https://github.com/bol-van/zapret) by **bol-van**
- [Asuswrt‑Merlin](https://www.asuswrt-merlin.net/) by **RMerl**

## License

MIT — see [LICENSE](LICENSE).
