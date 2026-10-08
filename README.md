# Ubuntu 26.04 on a 2017 MacBook Pro 15" (MacBookPro14,3, Apple T1)

Working **speakers** and a working **Touch Bar** on kernel 7.0, plus notes for running the machine with its internal display removed.

> **What this is.** A tested recipe and field report from one machine. It contains no new driver. Everything here stands on three community projects (see [Credits](#credits)); my part is the order of the steps, the Ubuntu-specific workarounds, and the test results.
>
> **What this is not.** A guarantee. One machine, one kernel, one evening. Read the upstream warnings before you run anything as root.

## Is this your problem?

You installed Ubuntu (or another Linux) on a 2016/2017 Touch Bar MacBook Pro with "erase disk", and now:

- the speakers are silent, and
- the Touch Bar is a black strip, so you have **no Esc key and no F-keys**.

Check in ten seconds:

```bash
cat /sys/class/dmi/id/product_name     # MacBookPro13,2 / 13,3 / 14,2 / 14,3
lsusb -d 05ac:                          # 05ac:1281 "Mobile Device (Recovery Mode)" = Touch Bar chip has no firmware
sudo ls /boot/efi/EFI/APPLE             # "No such file" = the installer erased it
```

If you see `05ac:1281` and no `EFI/APPLE`, this guide is for you. Why that happens is explained in [docs/01-background.md](docs/01-background.md).

## Result

| Component | Fresh install | After this guide | How it was checked |
|---|---|---|---|
| Internal speakers | silent | working, left/right correct | by ear |
| Touch Bar | dark (T1 in USB recovery, `05ac:1281`) | Esc, brightness, media keys; hold Fn for F1–F12 | by use |
| Headphone jack | no jack exposed | jack exposed | not tested with headphones |
| Internal microphone | noise only | plausible signal | level analysis only, not by ear |
| Keyboard backlight | — | working | by eye |
| Keyboard, trackpad (`applespi`) | working | unchanged | by use |
| Fans | no control | `mbpfan` follows temperature | `sensors` under load |
| Bluetooth | working | unchanged | scan only |
| Touch ID | not working | not attempted | — |
| Suspend / resume | untested | untested, auto-suspend disabled | — |

### Verification status

The table above was first verified in the running session in which everything was set up: the audio driver was activated by reloading modules and the Touch Bar driver bound live.

The machine has since been through a **full power-off and power-on (2026-10-09), and the Touch Bar works afterwards.** That is the test that matters most. One other MacBookPro14,3 has a correct file set that its firmware does not load at power-on ([t1-revive issue #7](https://github.com/niconistal/t1-revive/issues/7)); on this machine the firmware loads the restored files by itself. The test is described in [docs/04-touch-bar.md](docs/04-touch-bar.md#7-the-cold-boot-test), and `scripts/check.sh` prints the facts after a boot.

| Test | Result |
|---|---|
| Cold power-on (full power-off, then on): Touch Bar comes up by itself | **passed** — checked by use; `lsusb` output not recorded |
| Sound after a boot | not separately confirmed |
| Login screen layout after a boot (`eDP-1` off at the greeter) | not separately confirmed |
| A kernel update with both DKMS drivers installed | has not happened yet |

## The short version

1. **Get a way back in first.** With a dead Touch Bar there is no Esc key, so no GRUB menu. Install an SSH server and know how to boot your older kernel from another device. → [docs/02-safety-net.md](docs/02-safety-net.md)
2. **Speakers:** install the `snd_hda_macbookpro` DKMS driver; it needs the `linux-source` package of your running kernel. → [docs/03-speakers.md](docs/03-speakers.md)
3. **Touch Bar, part 1 — firmware:** back up the EFI partition, keep Ubuntu's `usbmuxd` away from the T1, then run `t1-revive regenerate`. It took 4 min 55 s here. → [docs/04-touch-bar.md](docs/04-touch-bar.md)
4. **Touch Bar, part 2 — driver:** only after the firmware restore has finished, install `t1-touchbar`. Remove key remappers such as `keyd`, or Fn will not switch the bar to F-keys.
5. **Back up the restored firmware off the disk.** A reinstall erases it again.

## Guide

| | |
|---|---|
| [01 — Background](docs/01-background.md) | Why sound and the Touch Bar die on Linux, T1 vs T2, what the mainline kernel supports |
| [02 — Safety net](docs/02-safety-net.md) | SSH, fallback kernel without an Esc key, EFI partition backup |
| [03 — Speakers](docs/03-speakers.md) | CS8409 audio driver, activation without a reboot, tests |
| [04 — Touch Bar](docs/04-touch-bar.md) | T1 firmware restore on Ubuntu, driver, cold-boot test |
| [05 — Life without Esc and F-keys](docs/05-keyboard-workarounds.md) | Temporary Caps Lock = Esc and Fn + number row = F-keys, and why to remove them afterwards |
| [06 — No internal display](docs/06-no-internal-display.md) | Phantom `eDP-1`, login screen, lid switch, sleep, lost antennas |
| [07 — Keeping it working](docs/07-maintenance.md) | Kernel updates, DKMS, fallback kernel, firmware backup, reinstalling |
| [08 — Troubleshooting](docs/08-troubleshooting.md) | Symptom → cause → fix |
| [09 — Undo](docs/09-undo.md) | One command per change |
| [Field report](docs/field-report.md) | Timeline, timings, what went wrong, what is still open |

Also in this repository:

- [`scripts/check.sh`](scripts/check.sh) — read-only health check (T1 state, firmware files, drivers, DKMS, sound card, displays, services).
- [`configs/`](configs) — the small config files used here, as examples.

## Machine and versions

| | |
|---|---|
| Model | MacBookPro14,3 (15-inch, 2017), Apple T1, Intel HD 630 + Radeon Pro 560 |
| OS | Ubuntu 26.04.1 LTS, GNOME, kernel `7.0.0-38-generic` |
| Disk layout | Linux only: one 1 GiB EFI System Partition + ext4 root (no macOS) |
| Special condition | Internal display (whole lid) physically removed; an external monitor on USB-C is the only screen |
| Audio driver | [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) @ `89b22ff` |
| T1 firmware tool | [niconistal/t1-revive](https://github.com/niconistal/t1-revive) @ `eb70a63` (v0.1.5) |
| Touch Bar driver | [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) @ `20d65c7` |
| Date | 2026-10-08 / 09 |

The Touch Bar part should apply to MacBookPro13,2 / 13,3 / 14,2 as well (same T1 chip, all listed as tested by t1-revive), but only the 14,3 was tested here.

## Open items

- **Sound and the login-screen layout after a boot** — not separately confirmed; see [Verification status](#verification-status).
- **Touch ID** — not attempted. [t1bridge](https://github.com/standardagents/t1bridge) reports Touch ID on T1 Macs and ships Arch packages; I used the `apple-ib-drv` fork instead and have not tried t1bridge on Ubuntu.
- **Suspend / resume** — untested, and deliberately disabled on this machine.
- **Headphones, HDMI/DP audio, microphone by ear** — not confirmed.
- **Built-in Wi-Fi** — not a fair test here: the antennas left with the lid. I use a USB adapter.

Corrections and results from other machines are welcome: open an issue.

## Credits

- **davidjo** — [`snd_hda_macbookpro`](https://github.com/davidjo/snd_hda_macbookpro), the CS8409 driver that makes the speakers work.
- **niconistal** — [`t1-revive`](https://github.com/niconistal/t1-revive), which regenerates the T1 firmware from Linux alone; and the **[libimobiledevice](https://libimobiledevice.org/)** project underneath it.
- **AJ-dev-i60** — [`t1-touchbar`](https://github.com/AJ-dev-i60/t1-touchbar), the kernel-7 port of `apple-ib-drv`.
- **Ronald Tschalär (roadrunner2)** and the **t2linux** community — the original reverse engineering and the `apple-ib-drv` driver that T1 Touch Bar support on Linux descends from.
- Diagnosis and step planning were done with Claude Code. Commands that run third-party code as root were run by hand.

## License

Text, scripts and config examples in this repository: [MIT](LICENSE). The projects linked above have their own licenses.
