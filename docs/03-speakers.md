# 03 — Speakers

**Problem:** the sound card appears, the volume slider moves, the speakers stay silent.
**Cause:** the in-kernel CS8409 driver does not power Apple's speaker amplifiers ([background](01-background.md#speakers-a-missing-driver)).
**Fix:** [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro), a patched build of that driver, installed through DKMS.

## 1. Confirm the chip

```bash
grep -iE 'codec:|subsystem id' /proc/asound/card*/codec#*
```

Expected on a MacBookPro14,3: `Codec: Cirrus Logic CS8409` with `Subsystem Id: 0x106b3900`. Other Macs with a CS8409 have other subsystem IDs; check the upstream README for yours.

## 2. Install

```bash
sudo apt install dkms build-essential git wget patch linux-headers-generic \
                 linux-source-$(uname -r | cut -d- -f1)

sudo git clone https://github.com/davidjo/snd_hda_macbookpro /usr/src/snd_hda_macbookpro-0.1
cd /usr/src/snd_hda_macbookpro-0.1
sudo ./install.cirrus.driver.sh -i
```

Notes:

- **`linux-source-…` is the part people miss on Ubuntu.** The installer patches the kernel's own `cs8409` source files, so it needs the source package that matches the running kernel: `linux-source-7.0.0` for kernel `7.0.0-38-generic`. Without it the build stops and tells you which package to install.
- `-i` installs through DKMS, `-r` removes it. Upstream's README does not require a particular clone location; I cloned straight into `/usr/src/snd_hda_macbookpro-0.1`.
- On kernel 7.0 the installer prints `Kernel version later than implemented version - there may be build problems`, and the patches apply with offsets and fuzz (`Hunk #1 succeeded at 1594 (offset 159 lines)`). The build completed and the driver works. Compiler and `pahole` version warnings are harmless.
- The commit I used is `89b22ff`. To pin it: `sudo git checkout 89b22ff` before running the installer.

## 3. Activate

Reboot. That is the simple way.

Without a reboot (what I did), replace the loaded module while the sound server is stopped:

```bash
systemctl --user stop pipewire.socket pipewire-pulse.socket wireplumber pipewire pipewire-pulse
sudo modprobe -r snd_hda_intel
sudo modprobe -r snd_hda_codec_cs8409
sudo modprobe snd_hda_intel
systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber pipewire pipewire-pulse
```

`snd_hda_intel` also carries the HDMI/DisplayPort audio of the graphics card, so monitor audio drops for a moment. The picture is not affected.

## 4. Verify that the new driver is the one loaded

```bash
dkms status                                           # snd_hda_macbookpro/0.1, <kernel>, x86_64: installed
modinfo -F filename snd_hda_codec_cs8409              # …/updates/dkms/snd-hda-codec-cs8409.ko.zst
modinfo -F srcversion snd_hda_codec_cs8409
cat /sys/module/snd_hda_codec_cs8409/srcversion       # must equal the line above
aplay -l | grep -i cs8409                             # card 0: … CS8409/CS42L83 Analog
```

`dkms status` adds `(Original modules exist)`. That is normal: the stock module stays on disk and the DKMS one in `updates/dkms` takes priority.

If the two `srcversion` values differ, the old module is still in memory: reboot, or repeat step 3.

## 5. Pick the stereo profile

GNOME chose a 4.0 surround profile on my machine. Switch to plain stereo:

```bash
pactl list cards short
pactl set-card-profile alsa_card.pci-0000_00_1f.3 output:analog-stereo+input:analog-stereo
```

WirePlumber remembers the profile and the default output.

## 6. Test

Set the volume immediately before you play anything. A test tone at 100% on these speakers is loud.

```bash
pactl set-sink-volume @DEFAULT_SINK@ 30%
paplay /usr/share/sounds/alsa/Front_Left.wav
paplay /usr/share/sounds/alsa/Front_Right.wav
```

Microphone:

```bash
arecord -d 5 -f cd /tmp/mic.wav && aplay /tmp/mic.wav
```

## Results on this machine

| | Stock driver | With `snd_hda_macbookpro` |
|---|---|---|
| Internal speakers | silent | working, left and right correct (by ear) |
| Headphone jack | not exposed | exposed as a port; not tested with headphones |
| Internal microphone | noise (peak 1.0, RMS 0.40) | quiet noise floor (RMS 0.002) with clear events up to 0.52; not confirmed by ear |
| HDMI/DP audio to the monitor | present | present; not confirmed by ear |

Upstream describes input as unfinished ("Sound input still needs work"), so treat the microphone result with care.

## After a kernel update

DKMS rebuilds the driver for each new kernel, but only if the matching `linux-source` package is installed. A point release inside 7.0.0 needs nothing new; a jump to another kernel version needs `linux-source-<that version>`. If sound is gone after an update:

```bash
sudo apt install linux-source-$(uname -r | cut -d- -f1)
sudo dkms autoinstall
sudo reboot
```

## Undo

```bash
cd /usr/src/snd_hda_macbookpro-0.1 && sudo ./install.cirrus.driver.sh -r && sudo reboot
```

Next: [04 — Touch Bar](04-touch-bar.md)
