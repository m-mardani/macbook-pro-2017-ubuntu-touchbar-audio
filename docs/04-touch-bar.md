# 04 — Touch Bar

**Problem:** the Touch Bar is black. No Esc, no F-keys, no brightness or volume keys.
**Cause:** two things are missing: the T1 chip's firmware files on the EFI partition, and a Linux driver for the T1 Touch Bar ([background](01-background.md#touch-bar-missing-firmware-and-a-missing-driver)).
**Fix:** restore the firmware with [t1-revive](https://github.com/niconistal/t1-revive), then install the [t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) driver. **In that order.**

> **This is a firmware recovery, not a driver install.** t1-revive talks to Apple's servers, writes new factory data into the T1 and writes three files to the EFI System Partition. Its README says the chip "cannot end up worse than recovery mode, which is where it started", and also that there is no undo other than restoring an earlier copy of `EFI/APPLE`. Read [its caution block](https://github.com/niconistal/t1-revive#readme) yourself. t1-revive officially supports Arch-based distributions only; what follows is how it ran on Ubuntu.

Time needed: about 20 minutes, of which the restore itself is 5.

## 1. Which case are you in?

```bash
lsusb -d 05ac:
sudo ls -l /boot/efi/EFI/APPLE/EMBEDDEDOS
```

| `lsusb` | `EFI/APPLE/EMBEDDEDOS` | Do this |
|---|---|---|
| `05ac:1281` (Recovery Mode) | missing | Everything below. This was my case. |
| `05ac:8600` (iBridge) | present | Firmware is fine. Skip to [step 6](#6-install-the-driver--after-the-restore-not-before). |
| `05ac:1281` | present | Do one full power-off (not a reboot), wait 20 s, power on, look again. If it stays at `1281`, see [t1-revive issue #7](https://github.com/niconistal/t1-revive/issues/7). |
| neither | — | The T1 is not on the USB bus at all. Try a full power-off first. Not covered here. |

If the Mac **dual-boots macOS**, there are two EFI partitions and Apple's is not the one mounted at `/boot/efi`. t1-revive handles that layout (version 0.1.1 or later); I have a Linux-only disk and did not test it.

## 2. Preparation

Do [02 — Safety net](02-safety-net.md) first. In particular:

- the EFI partition backup exists,
- the charger is connected and the machine will not sleep,
- you have SSH or a USB keyboard.

The restore needs HTTPS access to `gs.apple.com` and `swcdn.apple.com`. If you test that with `curl`, a "self-signed certificate in certificate chain" error from `gs.apple.com` is expected: that server uses Apple's private root CA, which is not in the system trust store.

## 3. Ubuntu packages

t1-revive checks and installs packages only on Arch. These are the Ubuntu equivalents that satisfied both its build and the restore:

```bash
sudo apt install build-essential git dkms linux-headers-generic \
                 autoconf automake libtool pkgconf patch \
                 libzip-dev libusb-1.0-0-dev libssl-dev libcurl4-openssl-dev \
                 zlib1g-dev libreadline-dev acpi-call-dkms

sudo modprobe acpi_call
ls /proc/acpi/call            # must exist: the T1 reset goes through it
```

## 4. Keep Ubuntu's iPhone service away from the T1

Ubuntu ships `usbmuxd`, the service that talks to iPhones. Its udev rule also matches the T1 (`05ac:8600`), sets it to "unconfigured" and starts `usbmuxd` on it. That fights both the restore and the Touch Bar driver.

Create an override in `/etc` with the T1 removed. A file in `/etc/udev/rules.d` replaces the file of the same name in `/lib` and survives package updates; iPhones keep working through the remaining matches.

```bash
sudo sed 's#|5ac/8600/\*##g' /lib/udev/rules.d/39-usbmuxd.rules \
  | sudo tee /etc/udev/rules.d/39-usbmuxd.rules >/dev/null
grep 8600 /etc/udev/rules.d/39-usbmuxd.rules      # must print nothing
sudo udevadm control --reload
```

Two details that are easy to get wrong:

- **Do not add a comment to that file that mentions the T1** (`iBridge`, `05ac`, `8600`, `Touch Bar`). t1-revive's preflight will take the file for a Touch Bar driver rule; see step 5.
- `t1-touchbar`'s README suggests `sudo sed -i '/05ac.*8600/d' /lib/udev/rules.d/39-usbmuxd.rules` instead. On Ubuntu 26.04.1 that pattern matches nothing, because the packaged rule spells the T1 as `5ac/8600` (no leading zero) inside a list of products. The `sed` above matches that spelling.

t1-revive starts its own private `usbmuxd`, and its preflight checks that no system one is running. Switch the system service off for the duration of the restore:

```bash
sudo systemctl mask --now usbmuxd.service
```

## 5. Build and run t1-revive

```bash
mkdir -p ~/src && cd ~/src
git clone https://github.com/niconistal/t1-revive && cd t1-revive
git checkout eb70a63              # v0.1.5, the version used here
bash build.sh                     # no root: builds patched libimobiledevice tools into ./prefix
sudo bin/t1-revive preflight      # read-only checks
sudo bin/t1-revive regenerate     # the restore; asks before it starts and again before it writes
```

### What preflight says on Ubuntu

One "NO" line is expected on Ubuntu:

- `package checks are implemented for Arch-based systems only; make sure the equivalents of 'libzip libusb curl openssl readline dkms acpi_call-dkms' and the headers … are installed`. Step 3 covers it; the lines below it (`kernel headers`, `acpi_call loaded`) must say `ok`.

My own run ended with `23 ok, 2 problems`. The second "NO" was self-inflicted:

- `an older Touch Bar stack is still on this machine: udev /etc/udev/rules.d/39-usbmuxd.rules`. The check (`legacy_t1_stack` in t1-revive's `lib/discover.sh`) flags any file in `/etc/udev/rules.d` that contains `bConfigurationValue` and also matches `05ac`, `8600`, `ibridge` or `touch bar` anywhere in the file. The override sets `bConfigurationValue` for iPhones, and I had put a comment at the top of mine that said "T1 iBridge 05ac:8600 removed". The comment tripped the check; the file has no rule for the T1. The restore ran clean with the file in place.

If you create the override exactly as in step 4, without such a comment, this line should not appear. I verified that by running the check's two `grep` tests against both variants of the file, not by a second restore.

Any other "NO" is real: fix it before you continue.

`regenerate` runs preflight again and proceeds after you confirm.

### What regenerate does

| Step | What happens | Time here |
|---|---|---|
| firmware | downloads `EmbeddedOSFirmware.pkg` (about 56 MB) from Apple's CDN and verifies it | — |
| provision | resets the T1; the chip fetches its own factory data from Apple | 127 s |
| reset-1 | T1 reset through ACPI `FRST` | 15 s |
| personalize | captures a boot image and ticket signed for this chip | 97 s |
| reset-2 | | 15 s |
| boot | boots the T1 from the captured image; **the Touch Bar may light up here** | 40 s |
| stage | asks again, then writes the three files to the EFI partition and verifies them | 1 s |
| handover | passes the T1 to `t1bridge` if installed; skipped here | 0 s |
| **Total** | | **4 min 55 s** |

It ended with `regenerate complete. T1: 8600`. Every step succeeded at the first attempt. The boot step reported `05ac:8600 stable for 30 s and no fallback to recovery`, and the kernel log showed the T1's keyboard interface, sensor hub and camera (`uvcvideo … iBridge`) appearing.

The closing message tells you to install t1bridge next. That is the other route; see [the last section](#touch-id-and-the-other-route).

### Check the result

```bash
lsusb -d 05ac:8600                                # Apple, Inc. iBridge
sudo ls -l /boot/efi/EFI/APPLE/EMBEDDEDOS
#   combined.memboot   about 30 MB
#   FDRData            about 150 KB
#   version.plist      517 bytes
```

### If it stops

t1-revive stops at the first failure and names the step. Its documented fallback is always the same: full shutdown, wait 20 seconds, power on, then

```bash
sudo bin/t1-revive regenerate --from STEP     # provision | reset-1 | personalize | reset-2 | boot | stage | handover
```

Its own [troubleshooting page](https://github.com/niconistal/t1-revive/blob/main/docs/troubleshooting.md) is organised by symptom and exit code.

## 6. Install the driver — after the restore, not before

A Touch Bar driver stack that binds the T1 and pins its USB configuration makes the restore's boot step reach `8600` and then hang ([t1-revive issue #10](https://github.com/niconistal/t1-revive/issues/10)). `t1-touchbar` installs exactly such a udev rule. So: install it only once `regenerate` has finished and `lsusb` shows `05ac:8600`.

```bash
cd ~/src
git clone https://github.com/AJ-dev-i60/t1-touchbar && cd t1-touchbar
git checkout 20d65c7
sudo ./install.sh --dry-run       # shows every action without doing it
sudo ./install.sh
sudo systemctl unmask usbmuxd.service
```

The installer writes four things, in this order:

| File | Purpose |
|---|---|
| `/etc/modprobe.d/apple-touchbar.conf` | `options apple_ibridge skip_acpi_power=1` — written first, before the module can load |
| DKMS module `apple-ib-drv/0.1` in `/usr/src` | the driver (`apple_ibridge`, `apple_touchbar`) |
| `/etc/udev/rules.d/99-ibridge.rules` | puts the T1 into USB configuration 1 and disables USB autosuspend for it |
| `/etc/modules-load.d/apple-touchbar.conf` | loads `apple-ibridge` at boot |

**Never set `skip_acpi_power=0`.** The ACPI call it skips hard-freezes these models; only the power button gets you out.

Upstream says a reboot is needed before the driver binds, because generic HID drivers already hold the device on a running system. On my machine it bound immediately, a few minutes after the restore had booted the T1, although `hid-generic` had claimed the T1's HID interfaces by then. I cannot say whether that is repeatable. If your bar stays dark after the install, reboot once before you look for another cause.

Check:

```bash
lsmod | grep -E 'apple_touchbar|apple_ibridge'
sudo dmesg | grep -i skip_acpi_power              # "skip_acpi_power: NOT running ASOC.SOCW(1)…"
sudo dmesg | grep -iE 'apple-touchbar.*input:'    # Touch Bar HID created
dkms status | grep apple-ib-drv
```

### Result

Esc, screen brightness, keyboard backlight, media and volume keys on the bar. **Hold Fn to get F1–F12.**

If holding Fn does nothing, a key remapper is in the way: see [05](05-keyboard-workarounds.md#3-remove-the-workarounds-once-the-touch-bar-works).

## 7. The cold-boot test

Everything above happens in one running session. What it does not prove is that the Mac's firmware loads the staged files **by itself at power-on**. On one other MacBookPro14,3 it does not ([issue #7](https://github.com/niconistal/t1-revive/issues/7), open).

Test:

1. Shut down completely (not a reboot).
2. Wait 20 seconds.
3. Power on, log in, and run:

```bash
lsusb -d 05ac:
sudo dmesg | grep -iE '05ac|ibridge|apple-touchbar' | head -20
bash scripts/check.sh            # from this repository
```

| Outcome | Meaning |
|---|---|
| `05ac:8600`, bar lit | The firmware loads the files at power-on. Done. |
| `05ac:8600`, bar dark | Firmware fine, driver not bound: see [08](08-troubleshooting.md). |
| `05ac:1281` | The files were not loaded at power-on. Check that they are still on the EFI partition, then compare with issue #7. |

**Result on this machine (2026-10-09): passed.** After a full power-off and power-on the Touch Bar is lit and works, so the firmware loaded the restored files by itself. This was checked by use; I did not record the `lsusb` and `dmesg` output.

## 8. Back up the restored firmware — off this disk

The restored files are specific to this one chip, and any reinstall that erases the disk destroys them again. A copy lets you put them back in seconds instead of repeating the restore, and it is the only route left if Apple ever stops signing this firmware.

```bash
sudo tar -C /boot/efi -cf ~/EFI-APPLE-touchbar-firmware.tar EFI/APPLE
sha256sum ~/EFI-APPLE-touchbar-firmware.tar
```

Copy that file to a USB stick or other storage. **Keep it private**: do not post it, and do not post anything from `/var/lib/t1-revive/private` either.

Restore after a reinstall:

```bash
sudo tar -C /boot/efi -xf EFI-APPLE-touchbar-firmware.tar
```

followed by a full power-off and power-on.

## 9. If you ever run `regenerate` again

The Touch Bar driver is now exactly the kind of stack that wedges the restore. Take it out of the way first and put it back afterwards:

```bash
sudo mv /etc/udev/rules.d/99-ibridge.rules /root/99-ibridge.rules.off
sudo modprobe -r apple_touchbar apple_ibridge
sudo systemctl mask --now usbmuxd.service
# … run t1-revive …
sudo mv /root/99-ibridge.rules.off /etc/udev/rules.d/99-ibridge.rules
sudo systemctl unmask usbmuxd.service
sudo udevadm control --reload
```

I have not had to do this; it follows from issue #10 and from what the driver installs.

## Touch ID and the other route

I chose the `apple-ib-drv` fork because it was already reported working on exactly this model, distribution and kernel line, and because it is a single DKMS module.

t1-revive itself points to a different stack afterwards: [t1bridge](https://github.com/standardagents/t1bridge), which provides the Touch Bar, the camera **and Touch ID**. It ships packages for Arch and Omarchy. I have not tried it on Ubuntu, so Touch ID is "not attempted" here, not "impossible".

## Undo

```bash
cd ~/src/t1-touchbar && sudo ./uninstall.sh && sudo reboot        # driver
sudo rm -r /boot/efi/EFI/APPLE                                    # firmware files: T1 returns to recovery at the next cold boot
sudo rm /etc/udev/rules.d/39-usbmuxd.rules && sudo udevadm control --reload
```

Removing the files from the EFI partition does not undo the factory data written into the chip. That has no undo.

Next: [05 — Life without Esc and F-keys](05-keyboard-workarounds.md)
