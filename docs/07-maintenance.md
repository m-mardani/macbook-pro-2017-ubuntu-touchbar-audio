# 07 — Keeping it working

Both fixes live outside the kernel, so they need a little attention when the kernel changes or the disk is reinstalled.

## What is installed, and where

| Area | What | Where it lives | Survives a kernel update? |
|---|---|---|---|
| Speakers, headphone jack, microphone | `snd_hda_macbookpro` (DKMS) | `/usr/src/snd_hda_macbookpro-0.1` | yes, if the matching `linux-source` package is installed |
| Audio defaults | stereo profile, speakers as default output | `~/.local/state/wireplumber/` | yes |
| Touch Bar firmware | three files written by t1-revive | `/boot/efi/EFI/APPLE/EMBEDDEDOS/` | yes (not kernel-related) |
| Touch Bar driver | `apple-ib-drv` (DKMS) | `/usr/src/apple-ib-drv-0.1`, `/etc/modprobe.d/apple-touchbar.conf`, `/etc/modules-load.d/apple-touchbar.conf`, `/etc/udev/rules.d/99-ibridge.rules` | yes (DKMS autoinstall) |
| iPhone service kept off the T1 | udev override | `/etc/udev/rules.d/39-usbmuxd.rules` | yes |
| T1 reset helper | `acpi-call-dkms` | apt package | yes; only needed for t1-revive |
| t1-revive state | private chip data, firmware cache, logs | `/var/lib/t1-revive`, `/var/cache/t1-revive`, `/var/log/t1-revive` | — |
| Fan control | `mbpfan` | `/etc/mbpfan.conf` | yes |
| Remote access | `openssh-server` | `ssh.socket` | yes |

"Survives" here means checked by inspection: both DKMS packages have `AUTOINSTALL=yes` and the kernel headers meta-package is installed. See the [verification status](../README.md#verification-status--read-this).

## After every kernel update

```bash
dkms status
```

Both `apple-ib-drv` and `snd_hda_macbookpro` must say `installed` **for the new kernel**. A failed DKMS rebuild is easy to miss: apt carries on, and you only notice when the bar stays dark or the speakers are silent after the reboot.

| Symptom after an update | Fix |
|---|---|
| No sound | `sudo apt install linux-source-$(uname -r \| cut -d- -f1) && sudo dkms autoinstall && sudo reboot` |
| Touch Bar dark, `lsusb` shows `05ac:8600` | `sudo dkms autoinstall && sudo reboot`; if the build fails, check the [t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) repository for a newer commit |
| Touch Bar dark, `lsusb` shows `05ac:1281` | not a kernel problem: the firmware files are missing or were not loaded ([04](04-touch-bar.md#1-which-case-are-you-in)) |

Run `scripts/check.sh` after the reboot for the whole picture.

A kernel that jumps to a new major or minor version can break either out-of-tree driver until its maintainer catches up. Keep the previous kernel installed and protected ([02](02-safety-net.md#2-know-how-to-boot-the-previous-kernel-without-a-menu)) so you can keep working in the meantime.

## Before you reinstall or repartition

An installer that erases the disk recreates the EFI partition and deletes the Touch Bar firmware again. Before you do that:

```bash
sudo tar -C /boot/efi -cf EFI-APPLE-touchbar-firmware.tar EFI/APPLE
```

Put the file somewhere that is not this disk, and keep it private. After the reinstall:

```bash
sudo tar -C /boot/efi -xf EFI-APPLE-touchbar-firmware.tar
```

then a full power-off and power-on. If you have no copy, repeat [04](04-touch-bar.md) from the start; that works for as long as Apple's servers still sign this firmware.

Keeping the existing EFI System Partition during the install (manual partitioning, reuse it without formatting) should avoid the problem altogether. I have not tested that.

## Extras installed along the way

Not required for sound or the Touch Bar, but useful on this hardware:

```bash
# Fan speed follows temperature
sudo apt install mbpfan && sudo systemctl enable --now mbpfan

# Temperatures and fan speeds
sudo apt install lm-sensors && sensors

# Hardware video decoding on both GPUs
sudo apt install va-driver-all intel-media-va-driver i965-va-driver vainfo vulkan-tools
vainfo
```

With `mbpfan` the fans reached about 5,000 RPM at 77 °C package temperature under load and dropped back afterwards.

## Health check

```bash
bash scripts/check.sh
```

It reads state and changes nothing. It asks for `sudo` once, to list the EFI partition.

Next: [08 — Troubleshooting](08-troubleshooting.md)
