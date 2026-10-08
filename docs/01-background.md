# 01 — Background: why sound and the Touch Bar die on Linux

You do not need this page to follow the guide. It explains what is broken and why the fixes come from outside the kernel.

## The machine

| Part | What it is | Linux support out of the box (Ubuntu 26.04, kernel 7.0) |
|---|---|---|
| Keyboard, trackpad | SPI devices | works (`applespi`, in the kernel since 5.3) |
| Keyboard backlight | via `applespi` | works |
| Graphics | Intel HD 630 + AMD Radeon Pro 560, switched by `gmux` | works (`i915`, `amdgpu`) |
| External ports | 4 × USB-C/Thunderbolt 3, wired to the **AMD** GPU | works |
| SSD | Apple NVMe | works |
| Bluetooth | Broadcom, UART | works |
| Wi-Fi | Broadcom BCM43602 | driver loads (`brcmfmac`); see the note below |
| Fans, temperatures | Apple SMC | readable (`applesmc`); fan control needs `mbpfan` |
| **Speakers, headphone jack, microphone** | Cirrus CS8409 bridge + CS42L83 codec + speaker amplifiers | **driver loads, speakers silent** |
| **Touch Bar, Touch ID, camera, light sensor** | Apple **T1** chip ("iBridge") | **dead after an "erase disk" install** |

Wi-Fi note: t1-revive's README says a fresh install on the 15-inch 2017 can show no wireless networks at all because `linux-firmware` carries no calibration file for this chip, and it documents a fix. I could not judge the built-in Wi-Fi on my machine (its antennas were in the lid, which is gone), so this guide does not cover it.

Secure Boot is not available on these Macs, so the out-of-tree (DKMS) modules below load without key enrolment. The kernel logs a "module verification failed / tainting kernel" line; that is expected.

## Speakers: a missing driver

The audio chip is a Cirrus Logic **CS8409**. The kernel has a driver for it (`snd_hda_codec_cs8409`), written for other laptops. On a Mac it loads, creates a sound card with a generic layout, and never powers the speaker amplifiers Apple wired behind the chip. The result is a sound card that plays into silence, and a microphone that records noise.

[davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) is a patched build of that driver with the Apple amplifier setup added. It is not in the mainline kernel. It installs through DKMS, so it is rebuilt for each new kernel.

How to recognise the two states:

```bash
sudo dmesg | grep -i cs8409
aplay -l
```

With the Apple driver, `aplay -l` lists the card as `CS8409/CS42L83 Analog`, and a headphone jack and an internal microphone appear as ports.

## Touch Bar: missing firmware *and* a missing driver

The Touch Bar is not a simple display. It is driven by the **T1**, a small separate computer inside the Mac that also handles Touch ID, the camera and the ambient light sensor. To Linux the T1 is a USB device:

| `lsusb` shows | Meaning |
|---|---|
| `05ac:8600 Apple, Inc. iBridge` | T1 has booted its own system. A driver can talk to it. |
| `05ac:1281 Apple, Inc. Mobile Device (Recovery Mode)` | T1 has nothing to boot. No driver can help. |

The T1 does not carry its operating system inside itself. At every power-on the Mac's firmware reads three files from the EFI System Partition and hands them to the T1:

```
EFI/APPLE/EMBEDDEDOS/combined.memboot   (about 30 MB, the boot image)
EFI/APPLE/EMBEDDEDOS/FDRData            (about 150 KB, factory data signed for this one chip)
EFI/APPLE/EMBEDDEDOS/version.plist
```

A Linux installer that is told to "erase disk and install" creates a new, empty EFI System Partition. Those files are gone, and from the next boot the T1 sits in USB recovery mode: dark Touch Bar, no camera, no Touch ID. The factory data and the boot image are personalised for the individual chip, so a copy from another Mac is not a fix.

So there are two separate problems, and they must be solved in this order:

1. **Firmware.** Put a valid file set back on the EFI partition. [niconistal/t1-revive](https://github.com/niconistal/t1-revive) does this from Linux: it drives Apple's own restore protocol, lets the chip fetch its factory data and a personalised boot image from Apple's servers, boots the chip, and writes the three files. The other known route is a macOS reinstall, which recreates them.
2. **Driver.** With the T1 booted, Linux still needs a driver for the Touch Bar. For T1 Macs that driver has never been in the mainline kernel (next section).

## What the mainline kernel supports

There are two generations of Touch Bar Macs:

- **T1** — MacBookPro13,2 / 13,3 / 14,2 / 14,3 (2016, 2017)
- **T2** — 2018 and later Intel Macs

The mainline kernel has Touch Bar drivers **for T2 only**:

- `hid-appletb-kbd` and `hid-appletb-bl` were merged for Linux 6.15. Both commit messages say: "Note that currently only T2 Macs are supported."
- The companion display driver `appletbdrm`, from the same patch series, was tested on T2 Macs only and carries only their USB ID. Its author asked for testing on T1 Macs.

The T1 driver has a long history outside the kernel:

| When | What |
|---|---|
| 2017–2018 | Ronald Tschalär (roadrunner2) reverse-engineers the T1 and writes `apple-ibridge` / `apple-ib-tb` in the out-of-tree `macbook12-spi-driver` |
| Apr 2019 | First submission to the kernel list: "Apple iBridge support" |
| Jun 2019 | v2, reworked as a HID driver |
| Feb 2021 | "Touch Bar and ALS support for MacBook Pro's" (13,\*, 14,\*, 15,\*) |
| Feb 2023 | Aditya Garg resubmits the T1 patches with T2 work added |
| 2025 | Only the T2 part is merged (6.15) |
| 2023 → | A HID change in the kernel breaks the out-of-tree T1 driver on newer kernels |
| 2026 | [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) ports `apple-ib-drv` forward so it builds and binds on kernel 7 |

The same author's keyboard and trackpad driver (`applespi`) did get merged, in Linux 5.3, which is why typing works on a fresh install.

One detail of the T1 driver matters for safety. On these models an ACPI power-on call (`ASOC.SOCW(1)`) hard-freezes the machine. `t1-touchbar` skips it by default and its installer pins `skip_acpi_power=1`. `t1-revive` never calls it either; it resets the T1 with a different method (`FRST`).

## Sources

- Kernel list: [Apple iBridge support (Apr 2019)](https://lkml.iu.edu/hypermail/linux/kernel/1904.2/05194.html), [v2 (Jun 2019)](https://lkml.iu.edu/1906.1/04145.html), [Touch Bar and ALS support (Feb 2021)](https://lkml.iu.edu/hypermail/linux/kernel/2102.3/03558.html), [Touch Bar and Keyboard backlight driver for Intel Macs (Feb 2023)](https://lkml.iu.edu/hypermail/linux/kernel/2302.1/02825.html), [drm/tiny: add driver for Apple Touch Bars in x86 Macs (Feb 2025)](https://lkml.iu.edu/2502.3/01446.html)
- Phoronix: [Apple Touch Bar Linux driver hopes for upstream in 2021](https://www.phoronix.com/news/Apple-Touch-Bar-For-Linux), [Another attempt in 2024](https://www.phoronix.com/news/Apple-Touch-Bar-Linux-2024), [Mainline support for the MacBook keyboard/touchpad](https://www.phoronix.com/news/Linux-Finally-MBP-Key-Touchpad)
- The READMEs of [t1-revive](https://github.com/niconistal/t1-revive), [t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) and [snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)

Next: [02 — Safety net](02-safety-net.md)
