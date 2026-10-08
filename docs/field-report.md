# Field report

What was actually done on one machine, in order, with the numbers. The guide pages are the cleaned-up version of this.

- **Machine:** MacBookPro14,3, Ubuntu 26.04.1 LTS, kernel `7.0.0-38-generic` (fallback `7.0.0-30-generic`), Linux-only disk, internal display removed
- **When:** 2026-10-08 evening to shortly after midnight, about 3 h 40 min in total
- **How:** diagnosis, research and planning with Claude Code; I ran by hand the commands that execute third-party code as root

## Starting point

| | |
|---|---|
| T1 | `05ac:1281` (recovery), chip ID `8002`; `/boot/efi/EFI/APPLE` missing |
| Sound | stock `snd_hda_codec_cs8409` loaded; speakers silent; microphone noise (peak 1.0, RMS 0.40) |
| Display | external monitor on the AMD GPU; `eDP-1` reported connected and mirrored |
| Keyboard | typing fine; no Esc, no F-keys |
| Working and left alone | keyboard, trackpad, Bluetooth, fans, battery, both GPUs, a USB Wi-Fi adapter |
| Rescue path | none: no SSH server, hidden GRUB menu, no Esc key |

## Timeline

| # | Stage | What happened | Result |
|---|---|---|---|
| 1 | First driver pass | `ubuntu-drivers` found nothing proprietary to install. Installed video decoding, `mbpfan`, build tools. Built the audio driver. | Audio driver installed (not yet loaded) |
| 2 | Diagnosis, read-only | Model, T1 vs T2, PCI/USB, modules, kernel log, sound cards, displays, lid state, network, sensors, battery, kernels | Root causes found: missing audio driver, missing T1 firmware, phantom display, no rescue path |
| 3 | Research | A maintained fix for each component on this model and kernel | Choices in the table below |
| 4 | Plan | Nine steps, each with risk and undo | — |
| 5 | Apply | SSH; lid and sleep safety; audio module reload; audio tests; phantom display off; Bluetooth and backlight checks; sensors | Speakers working. Two steps dropped (below). |
| 6 | Interim keys | Caps Lock = Esc; Fn + number row = F1–F12 with `keyd` | Usable without a Touch Bar |
| 7 | Touch Bar restore | EFI partition backup; Ubuntu packages; usbmuxd override; `t1-revive regenerate`; `t1-touchbar` install | Touch Bar working |
| 8 | Fn fix | Holding Fn did not switch the bar; `keyd` was holding the keyboard | `keyd` disabled; Fn shows F1–F12 |
| 9 | Persistence | DKMS autoinstall checked; fallback kernel protected from `autoremove`; firmware and configs copied | — |
| 10 | Clean-up | Caps Lock = Esc removed again | Keys back to normal |

## Choices

| Component | Chosen | Why |
|---|---|---|
| Audio | davidjo/snd_hda_macbookpro | Maintained, DKMS, supports this codec subsystem ID (`0x106b3900`) |
| T1 firmware | niconistal/t1-revive 0.1.5 | Rebuilds the firmware from Apple's servers without macOS; writes only three files to the EFI partition; never calls the ACPI method that freezes these Macs; its main test machine is a 14,3 |
| Touch Bar driver | AJ-dev-i60/t1-touchbar | Reported working on MacBookPro14,3 + Ubuntu 26.04 + kernel 7.0; a single DKMS module; writes the anti-freeze option before the module can load |
| Phantom display | GNOME display layout | No reboot needed to test, reverts by itself |

Both T1 projects were read before running: what they write as root, which ACPI methods they call, and in which order the driver installer creates its files.

## Numbers

**t1-revive `regenerate`** (v0.1.5, commit `eb70a63`), from a wiped EFI partition:

| Step | Seconds |
|---|---|
| provision | 127 |
| reset-1 | 15 |
| personalize | 97 |
| reset-2 | 15 |
| boot | 40 |
| stage | 1 |
| handover (skipped, no t1bridge) | 0 |
| **Total** | **295 (4 min 55 s)** |

No step was retried. Preflight: 23 ok, 2 "NO" (Arch-only package check; false positive on the usbmuxd override).

**Builds on kernel 7.0.0-38:**

| Module | DKMS build time |
|---|---|
| `snd_hda_macbookpro` 0.1 | 32 s to fetch and patch, 3 s to compile |
| `apple-ib-drv` 0.1 | 2 s |
| `acpi-call` 1.2.2 | 1 s |

**Microphone**, 5 s recording at 100% capture and maximum boost:

| | Stock driver | Patched driver |
|---|---|---|
| Peak | 1.0 (clipping) | 0.52 on the loudest events, no clipping |
| RMS | 0.40 | 0.0019 noise floor |

**Fans** with `mbpfan`: about 5,180 / 4,850 RPM at 77 °C package temperature during a package install, about 3,600 / 3,400 RPM at 70 °C later in the evening.

## What went wrong, and what it taught me

| What happened | Lesson |
|---|---|
| The first rescue instruction was "press Esc at boot for the GRUB menu". This Mac had no Esc key. | On a Touch Bar Mac, plan every recovery path without Esc: SSH and `grub-reboot`, or a USB keyboard. |
| It was assumed that Fn + number row already produced F-keys. It does not. | Measure the keyboard (`evtest`, `keyd monitor`) before relying on it. |
| A speaker test tone played at 100% because the volume had been changed between two tests. | Set the volume in the same command line as the test. |
| The login-screen layout was first copied to `/var/lib/gdm3/.config/`, where GDM 50 no longer reads it. | Check where the running version keeps its files; older guides are wrong here. |
| GNOME's "Keep changes?" dialog timed out and reverted the display change. | Useful, in the end: it proved that the monitor stays lit with `eDP-1` off before anything was made permanent. |
| `xkb-options` changed in settings but not in the live keymap. | Verify with the compositor's own keymap, not with the setting. |
| The usbmuxd override made t1-revive's preflight report an "older Touch Bar stack". | Read what a check actually tests before trusting or ignoring it. |
| `keyd`, installed to get F-keys, later stopped the Touch Bar from providing them. | Temporary workarounds need an owner and an end date. |
| `apt autoremove` was one command away from deleting the only fallback kernel. | `apt-mark manual` the kernel you rely on. |

## Deliberately not done

- **`video=eDP-1:d` kernel option and a visible GRUB menu.** It needs a reboot to test, and a mistake means no picture on the only monitor.
- **Suspend/resume test.** Same reason: a failed resume leaves no screen and, with a USB Wi-Fi adapter, no network.
- **Anything touching Wi-Fi, partitions or the boot loader.**

## Still open

- Reboot and cold power-on with the restored firmware ([README](../README.md#verification-status--read-this)).
- Headphone jack with headphones; microphone by ear; audio over HDMI/DP; Bluetooth with a real device; Touch ID; suspend.
- Whether the driver's "binds without a reboot" behaviour is repeatable.

## What I would do differently

1. Set up SSH before the first change, not after the first scare.
2. Keep the EFI System Partition when installing Linux on a T1 Mac, or copy `EFI/APPLE` off it first. The whole Touch Bar problem starts with the installer erasing that folder.
3. Skip `keyd` if the Touch Bar fix is going to happen the same day.
