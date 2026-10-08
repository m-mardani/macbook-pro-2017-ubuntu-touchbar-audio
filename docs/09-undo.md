# 09 — Undo

One command per change. Paths assume the locations used in this guide (`~/src/…`, `/usr/src/snd_hda_macbookpro-0.1`).

| Change | Undo |
|---|---|
| Audio driver | `cd /usr/src/snd_hda_macbookpro-0.1 && sudo ./install.cirrus.driver.sh -r && sudo reboot` |
| Stereo profile | pick another profile in Settings → Sound, or `pactl set-card-profile …` |
| Touch Bar driver | `cd ~/src/t1-touchbar && sudo ./uninstall.sh && sudo reboot` |
| Touch Bar firmware files | `sudo rm -r /boot/efi/EFI/APPLE` — the T1 returns to recovery at the next cold boot |
| Whole EFI partition | restore the image from [02, step 3](02-safety-net.md#3-back-up-the-efi-system-partition) |
| usbmuxd override | `sudo rm /etc/udev/rules.d/39-usbmuxd.rules && sudo udevadm control --reload` |
| usbmuxd masked | `sudo systemctl unmask usbmuxd.service` |
| `acpi-call-dkms` | `sudo apt remove acpi-call-dkms` |
| t1-revive state and cache | `sudo rm -r /var/lib/t1-revive /var/cache/t1-revive /var/log/t1-revive` — **after** you have a copy of `EFI/APPLE` elsewhere |
| Phantom display off | `cp ~/.config/monitors.xml.bak ~/.config/monitors.xml; sudo rm /var/lib/gdm3/seat0/config/monitors.xml`, then log out |
| Lid switch ignored | `sudo rm /etc/systemd/logind.conf.d/50-ignore-lid.conf && sudo systemctl kill -s HUP systemd-logind` |
| GNOME power settings | `gsettings reset org.gnome.settings-daemon.plugins.power <key>` for each of `sleep-inactive-battery-type`, `sleep-inactive-ac-type`, `lid-close-ac-action`, `lid-close-battery-action` |
| Caps Lock = Esc | `gsettings set org.gnome.desktop.input-sources xkb-options "[]"` (or your earlier value), then log out |
| keyd | `sudo systemctl disable --now keyd; sudo apt remove keyd; sudo rm /etc/keyd/macbook-fn.conf /etc/libinput/local-overrides.quirks` |
| SSH server | `sudo apt purge openssh-server` |
| Fan control | `sudo systemctl disable --now mbpfan` |
| Fallback kernel protection | `sudo apt-mark auto <the packages you marked manual>` |

## What cannot be undone

The firmware restore writes new factory data **into the T1 chip**. Deleting the files from the EFI partition, or restoring the old partition image, does not reverse that. t1-revive's README states that the chip "cannot end up worse than recovery mode, which is where it started"; I have no independent way to check that. It is the one step in this guide that is not a file you can delete.

Back to the [README](../README.md).
