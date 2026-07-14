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
- **Safe defaults** — first install creates `discord.com` as the starter hostlist and an exclude list for Apple, ChatGPT/OpenAI, Claude/Anthropic, Gemini/Google and common Cloudflare auth/CDN hosts
- **First-run setup wizard** — checks zapret, hostlist, exclude list, recommended `hostlist` mode and service readiness with quick actions to install, test and start
- **Blockcheck** runner (background) + status/lock handling + **log viewer**
- **Profiles** — save and restore named settings profiles in the browser, or on the router itself with a **scheduler** to auto-apply a profile on a daily time window (overnight windows like 22:00–06:00 supported)
- **Safe apply** — backs up config and hostlist, verifies the *live process* actually reflects the new settings (not just that some `nfqws` is running), and automatically rolls back if the restart fails, hangs, or doesn't take effect
- **Concurrency-safe** — config/hostlist edits, enable/disable/restart and blockcheck's start check are all serialized against each other, so a GUI submit racing a scheduled profile apply (or two rapid clicks) can't interleave or corrupt state
- **Optional installer** — a button to download zapret if it isn't installed yet (experimental)
- Config is **backed up** to `config.bak-gui` on every apply; self-updates are **atomic** and validated beyond a bare syntax check
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

On first open, the **Kurulum Kontrolü** card walks through the basic setup:

1. Checks whether zapret is installed.
2. Checks whether the starter hostlist exists.
3. Checks whether the exclude list exists.
4. Recommends `hostlist` mode.
5. Offers quick actions to install/apply recommended settings, run a `discord.com` blockcheck and start zapret.

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

### Default hostlists

On first mount/install, the addon creates the zapret hostlist only when it is missing or empty:

- `/opt/zapret/ipset/zapret-hosts-user.txt` starts with the common Discord domains (`discord.com`, `discordapp.com`, `discord.gg`, `gateway.discord.gg` and CDN/media domains)
- `/opt/zapret/ipset/zapret-hosts-user-exclude.txt` starts with Apple/App Store/iCloud update domains, OpenAI/ChatGPT domains, Claude/Anthropic domains, Gemini/Google domains and common Cloudflare auth/CDN dependencies

The default mode is intended to keep zapret scoped: only domains in the hostlist are processed, while Apple and common AI tools are kept out of zapret matching. The GUI allows saving an intentionally empty hostlist; this clears the file instead of silently keeping old entries.

### Safety / concurrency

This firmware's shell (`/bin/sh`) has no `flock`, `mktemp` or `timeout` binary, so the addon builds its own primitives on top of what's actually available:

- **Locking** — `mkdir` is the only atomic operation on hand (create-or-fail, no race window), so it's used as a mutex with a staleness timeout (a timestamp file written right after acquiring; a holder that's `kill -9`'d or the router losing power never runs a cleanup trap, so a stuck lock self-heals after ~90s instead of wedging forever). Config-mutating operations (applying settings, enable/disable/restart) share one lock; blockcheck's start-check uses a separate one, so a long blockcheck run never blocks a config apply or the scheduler's tick, and vice versa.
- **Restart timeout** — `"$ZAPRET_INIT" restart` is wrapped with a background-subshell watchdog (the same idiom blockcheck's own watchdog uses) so a hang surfaces as a failure and triggers rollback, instead of blocking the whole apply forever.
- **Health check** — after a restart, the live process's `/proc/<pid>/cmdline` is checked against what was just written to the config (not just "does *some* `nfqws` exist"), so a `stop` that silently failed to kill the old process can't be mistaken for a successful apply.
- **Replay safety** — the settings/profile blob files are deleted immediately after being read, so a stray or duplicated apply event can't silently re-apply stale data.
- **Atomic self-update** — `Do_Update` downloads into a same-directory temp file (not `/tmp`, which is a different filesystem here) so the final swap is a true atomic rename, and validates the download's size range and presence of core functions beyond a bare `sh -n` syntax check before committing to it.

### Persistence hooks

| Event | Hook |
|-------|------|
| httpd restart (tmpfs `/www` rebuilt) | `service-event-end` re‑mounts the page + menu |
| Reboot | `services-start` re‑mounts |

## Notes & limitations

- The UI text is **Turkish**. It's plain HTML/JS — translate the labels in `zapret-gui.asp` if you like.
- The menu is injected after `Advanced_Wireless_Survey.asp` (Network Tools → Site Survey). If your firmware's `menuTree.js` differs, change `MENU_ANCHOR` at the top of `zapret-gui.sh`.
- Assumes the standard zapret layout: `/opt/zapret/config`, `/opt/zapret/init.d/sysv/zapret`, `/opt/zapret/ipset/zapret-hosts-user.txt`.
- Firewall status uses `iptables -L` NFQUEUE detection for compatibility with AsusWRT builds where vendor targets can make `iptables -S` fail.
- The *Install* button is best-effort/experimental. Blockcheck runs in the background with a single-run lock, basic timeout support, clear missing-script errors and progress in the log viewer.
- Profiles are stored in the browser's local storage on the device used to access the GUI; they are not shared between browsers.
- Applying an enabled profile creates `config.bak-gui` and `zapret-hosts-user.txt.bak-gui`. If zapret fails to restart, hangs, or `nfqws` comes back up without actually reflecting the new settings, both files are restored automatically.
- Router-side scheduled profiles support overnight windows (e.g. `22:00`–`06:00`); a window where start equals end is treated as active all day.
- Tested on RT-BE92U (Merlin 3.0.0.6.102.8). Should work on other Merlin builds; open an issue if the menu doesn't appear.

## Credits

- Developed by [x.com/yigitech](https://x.com/yigitech)
- [zapret](https://github.com/bol-van/zapret) by **bol-van**
- [Asuswrt‑Merlin](https://www.asuswrt-merlin.net/) by **RMerl**

## License

MIT — see [LICENSE](LICENSE).
