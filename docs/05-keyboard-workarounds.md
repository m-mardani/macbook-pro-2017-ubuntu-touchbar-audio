# 05 — Life without Esc and F-keys

While the Touch Bar is dead this Mac has no Esc and no F1–F12. These two workarounds made the machine usable in the meantime. **Both should come out again once the Touch Bar works** (section 3), and the second one actively breaks it.

Skip this page if you are going straight to the Touch Bar fix.

## 1. Caps Lock as Esc (GNOME)

```bash
gsettings get org.gnome.desktop.input-sources xkb-options        # note what is there
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:escape']"
```

If the first command printed existing options, keep them in the list, for example `"['grp_led:scroll', 'caps:escape']"`.

This applies to the GNOME session only, not to the login screen or a text console.

### The change did nothing?

On Ubuntu 26.04 the new option was stored but not applied: the setting showed `caps:escape`, the live keymap still had Caps Lock. GNOME Shell only rebuilt the keymap when the list of input sources was reloaded. Either log out and in, or, if you have two layouts, swap their order and swap it back:

```bash
gsettings get org.gnome.desktop.input-sources sources            # e.g. [('xkb', 'us'), ('xkb', 'ir')]
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'ir'), ('xkb', 'us')]"
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ir')]"
```

To see what the compositor is really using (package `libxkbcommon-tools`):

```bash
xkbcli dump-keymap-wayland | grep -m1 xkb_symbols     # contains "capslock(escape)" when the option is live
```

## 2. Fn + number row as F1–F12 (keyd)

The built-in keyboard sends Fn as a real key (`KEY_FN`), and Fn + 5 still arrives as a plain 5. So the mapping can be done below the desktop, for every program, with [keyd](https://github.com/rvaiya/keyd):

```bash
sudo apt install keyd
sudo journalctl -u keyd -b | grep -i 'Apple SPI Keyboard'        # shows the keyboard's id, e.g. 0000:0000:caea9b11
```

Create `/etc/keyd/macbook-fn.conf` ([copy in this repository](../configs/keyd/macbook-fn.conf)), using the id from your own log:

```ini
[ids]
0000:0000:caea9b11

[main]
fn = layer(fkeys)

[fkeys]
1 = f1
2 = f2
3 = f3
4 = f4
5 = f5
6 = f6
7 = f7
8 = f8
9 = f9
0 = f10
minus = f11
equal = f12
```

```bash
sudo systemctl restart keyd
sudo journalctl -u keyd -b | tail -5        # "DEVICE: match … (Apple SPI Keyboard)"
```

Listing only the built-in keyboard under `[ids]` leaves external keyboards alone. If the id ever stops matching, keyd ignores the keyboard: the F-keys are gone and typing is normal.

keyd replaces the built-in keyboard with a virtual one, and libinput then no longer knows it is an internal keyboard, which switches off "disable touchpad while typing". A quirk restores that ([copy](../configs/libinput/local-overrides.quirks)); it takes effect at the next login:

```ini
# /etc/libinput/local-overrides.quirks
[keyd virtual keyboard]
MatchUdevType=keyboard
MatchName=keyd virtual keyboard
AttrKeyboardIntegration=internal
```

If the keyboard ever misbehaves: `sudo systemctl stop keyd` (from the mouse and an on-screen terminal, or over SSH).

Result here: Fn + 1 … Fn + = gave F1 … F12.

## 3. Remove the workarounds once the Touch Bar works

**keyd must be stopped, or holding Fn will not switch the Touch Bar to F1–F12.** keyd takes exclusive hold of the built-in keyboard, so the Touch Bar driver (`apple_touchbar`) never sees the Fn key. The bar lights up, Esc and the media keys work, and the F-keys never appear. The same should be true of any other remapper that grabs the keyboard device.

```bash
sudo systemctl disable --now keyd
```

That is enough; the config files are inert while the service is off. To remove it completely:

```bash
sudo apt remove keyd
sudo rm /etc/keyd/macbook-fn.conf /etc/libinput/local-overrides.quirks
```

Caps Lock back to normal (put back whatever the first command in section 1 printed):

```bash
gsettings set org.gnome.desktop.input-sources xkb-options "[]"
```

followed by a log-out or the source swap from section 1.

Next: [06 — No internal display](06-no-internal-display.md)
