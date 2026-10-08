# 08 — Troubleshooting

Start with the health check; it answers most of the "which state am I in" questions below:

```bash
bash scripts/check.sh
```

Entries marked **(seen here)** happened on my machine. Entries marked **(upstream)** are documented by the projects themselves and are listed so you know where to look; I did not hit them.

## Touch Bar

| Symptom | Cause | Fix |
|---|---|---|
| Bar dark; `lsusb` shows `05ac:1281` **(seen here)** | The T1 has no firmware: `EFI/APPLE/EMBEDDEDOS` was erased with the EFI partition | Restore it: [04, steps 2–5](04-touch-bar.md#2-preparation). No driver can fix this state. |
| Bar dark; `lsusb` shows `05ac:8600`; right after installing the driver **(upstream)** | Generic HID drivers already hold the device | Reboot once |
| Bar dark; `05ac:8600`; still dark after a reboot **(upstream)** | `usbmuxd`'s udev rule grabbed the T1 first | The override in [04, step 4](04-touch-bar.md#4-keep-ubuntus-iphone-service-away-from-the-t1); `grep 8600 /etc/udev/rules.d/39-usbmuxd.rules` must print nothing |
| Bar dark after a kernel update; `05ac:8600` | DKMS did not rebuild `apple-ib-drv` for the new kernel | `dkms status`, then `sudo dkms autoinstall && sudo reboot` |
| Bar works, but **holding Fn does not show F1–F12** **(seen here)** | A key remapper (`keyd` here) holds the built-in keyboard exclusively, so the driver never sees Fn | `sudo systemctl disable --now keyd` ([05](05-keyboard-workarounds.md#3-remove-the-workarounds-once-the-touch-bar-works)) |
| After a cold power-on the T1 is back at `05ac:1281` although the three files are on the EFI partition **(upstream, open)** | The Mac's firmware did not load them | [t1-revive issue #7](https://github.com/niconistal/t1-revive/issues/7). Confirm the files are intact, then add your data there. |
| Machine freezes hard when the driver loads **(upstream)** | `skip_acpi_power=0`: the ACPI power-on call freezes these models | Hold the power button. Make sure `/etc/modprobe.d/apple-touchbar.conf` contains `options apple_ibridge skip_acpi_power=1` |
| Boot hangs after installing the driver **(upstream)** | — | With a USB keyboard: Esc at power-on → GRUB, then either press `e` and add `modprobe.blacklist=apple_ibridge,apple_touchbar` to the `linux` line, or pick the older kernel under "Advanced options" (it has no Touch Bar module unless DKMS built one for it). |

## T1 firmware restore (t1-revive)

| Symptom | Cause | Fix |
|---|---|---|
| Preflight: `NO package checks are implemented for Arch-based systems only` **(seen here)** | Expected on Ubuntu | Install the packages from [04, step 3](04-touch-bar.md#3-ubuntu-packages); the `kernel headers` and `acpi_call loaded` lines must say `ok` |
| Preflight: `NO an older Touch Bar stack is still on this machine: udev /etc/udev/rules.d/39-usbmuxd.rules` **(seen here)** | False positive from the usbmuxd override, which still sets `bConfigurationValue` for iPhones | Harmless if `grep 8600` on that file prints nothing. The restore ran clean with the file in place. |
| Preflight names a **different** file or a unit as "older Touch Bar stack" **(upstream, #10)** | A Touch Bar driver is already installed and pins the T1's USB configuration | Remove it for the duration of the restore: [04, step 9](04-touch-bar.md#9-if-you-ever-run-regenerate-again) |
| `boot` step reaches `8600`, then hangs or fails with `code=5` **(upstream, #10)** | Same as above | Same, then `sudo bin/t1-revive regenerate --from boot` |
| Stops at `reset-1` with exit 3 **(upstream, #4)** | `acpi_call` was not loaded at that moment | `sudo modprobe acpi_call`, check `/proc/acpi/call`, then `--from reset-1` |
| Preflight complains about a system `usbmuxd` | Ubuntu's service is running | `sudo systemctl mask --now usbmuxd.service`; unmask after the restore |
| `curl https://gs.apple.com` reports a self-signed certificate in the chain **(seen here)** | That server uses Apple's private root CA | Expected. It is not a sign of interception by itself. |
| Any step fails **(upstream)** | — | Full shutdown, wait 20 s, power on, `sudo bin/t1-revive regenerate --from STEP`. The provisioned data survives, so later steps do not repeat `provision`. |

For a failure, t1-revive asks for the output of `sudo bin/t1-revive report` and nothing else. Never post serial numbers, ECIDs, nonces, tickets, MAC addresses, logs from `/var/lib/t1-revive/private`, or anything from `EFI/APPLE`.

## Sound

| Symptom | Cause | Fix |
|---|---|---|
| Card present, speakers silent **(seen here)** | Stock `snd_hda_codec_cs8409` loaded | Install the driver: [03](03-speakers.md) |
| Driver installed, still silent, no reboot yet **(seen here)** | The old module is still in memory | Reboot, or reload the modules ([03, step 3](03-speakers.md#3-activate)); compare the two `srcversion` values |
| Installer stops and asks for kernel sources | `linux-source-<version>` missing | `sudo apt install linux-source-$(uname -r \| cut -d- -f1)` |
| `Kernel version later than implemented version` and "Hunk succeeded at … (offset …)" during the build **(seen here)** | The patches were written against an older kernel | Harmless if the build finishes and `dkms status` says `installed` |
| The output profile is "Analog Surround 4.0" **(seen here)** | GNOME's choice for this card | `pactl set-card-profile alsa_card.pci-0000_00_1f.3 output:analog-stereo+input:analog-stereo` |
| No sound after a kernel update | DKMS rebuild failed, usually for lack of the new `linux-source` package | [07](07-maintenance.md#after-every-kernel-update) |
| Microphone records noise | Stock driver; or input support, which upstream calls unfinished | Check that the DKMS module is the one loaded; beyond that, see the upstream issues |

## Display, lid, keyboard

| Symptom | Cause | Fix |
|---|---|---|
| The desktop is mirrored onto a display that does not exist **(seen here)** | The graphics card reports the missing internal panel (`eDP-1`) as connected | [06, section 1](06-no-internal-display.md#1-the-phantom-display) |
| Phantom display returns when the cable moves to another port | `monitors.xml` only has an entry for the old port | One `<configuration>` per port |
| `monitors.xml` copied to `/var/lib/gdm3/.config/` has no effect on the login screen **(seen here)** | GDM 50 uses a dynamic greeter user | Put it in `/var/lib/gdm3/seat0/config/` |
| Changing `xkb-options` with `gsettings` has no effect **(seen here)** | GNOME Shell did not rebuild the keymap | Log out and in, or swap the input sources and swap back ([05](05-keyboard-workarounds.md#the-change-did-nothing)) |
| Cannot open the GRUB menu **(seen here)** | Esc is on the dead Touch Bar | SSH + `grub-reboot`, or a USB keyboard ([02](02-safety-net.md)) |
| Built-in Wi-Fi barely connects on a machine without a lid **(seen here)** | The antennas were in the lid | USB Wi-Fi adapter |
| `apt autoremove` offers to remove your only older kernel **(seen here)** | It is marked as automatically installed | `sudo apt-mark manual <its packages>` ([02](02-safety-net.md#2-know-how-to-boot-the-previous-kernel-without-a-menu)) |

## Still stuck?

- Touch Bar firmware: [t1-revive issues](https://github.com/niconistal/t1-revive/issues) and its [troubleshooting page](https://github.com/niconistal/t1-revive/blob/main/docs/troubleshooting.md)
- Touch Bar driver: [t1-touchbar issues](https://github.com/AJ-dev-i60/t1-touchbar/issues)
- Sound: [snd_hda_macbookpro issues](https://github.com/davidjo/snd_hda_macbookpro/issues)
- Something in this guide is wrong or unclear: open an issue here.

Next: [09 — Undo](09-undo.md)
