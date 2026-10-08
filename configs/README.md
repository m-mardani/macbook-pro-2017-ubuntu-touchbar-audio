# Config examples

The small files used in this guide. Read the page that explains each one before copying it.

| File | Goes to | Explained in |
|---|---|---|
| `logind/50-ignore-lid.conf` | `/etc/systemd/logind.conf.d/` | [06 — No internal display](../docs/06-no-internal-display.md#2-lid-switch-and-sleep) |
| `gnome/monitors.xml.example` | `~/.config/monitors.xml` and `/var/lib/gdm3/seat0/config/monitors.xml` | [06 — No internal display](../docs/06-no-internal-display.md#1-the-phantom-display) |
| `keyd/macbook-fn.conf` | `/etc/keyd/` | [05 — Life without Esc and F-keys](../docs/05-keyboard-workarounds.md#2-fn--number-row-as-f1f12-keyd) (temporary) |
| `libinput/local-overrides.quirks` | `/etc/libinput/` | same page (temporary) |

Not included on purpose:

- **`/etc/udev/rules.d/39-usbmuxd.rules`** — generated from your own distribution's file with one `sed` command ([04, step 4](../docs/04-touch-bar.md#4-keep-ubuntus-iphone-service-away-from-the-t1)), so it always matches your usbmuxd version.
- **The Touch Bar driver's files** (`apple-touchbar.conf`, `99-ibridge.rules`) — written by the `t1-touchbar` installer; get them from that project.
- **Anything from `EFI/APPLE` or `/var/lib/t1-revive`** — specific to one chip and private.
