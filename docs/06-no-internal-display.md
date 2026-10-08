# 06 — Running without the internal display

Only relevant if the lid is gone or the panel is dead and an external monitor is the only screen. My MacBook has no lid at all: the whole display assembly was removed.

The rule that shaped everything on this page: **any change that can black out the one working monitor needs a way back that does not depend on that monitor.** Set up SSH first ([02](02-safety-net.md)).

## What goes with the lid

On this model the lid holds more than the panel:

| Part | Effect of removing the lid |
|---|---|
| Display panel | gone, but the graphics card may still report it as connected (below) |
| Camera, ambient light sensor | gone |
| Wi-Fi antennas | built-in Wi-Fi drops to a 9–15% signal; I use a USB Wi-Fi adapter |
| Bluetooth antenna | Bluetooth still finds devices; range is probably reduced (not measured) |
| Lid sensor | may still send "lid closed" |

## 1. The phantom display

```bash
for c in /sys/class/drm/card*-*; do
  printf '%-18s %-13s %s\n' "$(basename "$c")" "$(cat "$c/status")" "$(cat "$c/enabled")"
done
```

On my machine the AMD card listed `eDP-1` as `connected` at 2880×1800 although no panel exists. GNOME mirrored the desktop onto it, and on one of the ports it had also stored a 1.67× scale for the mirrored pair.

All four USB-C ports hang off the **AMD** GPU (`DP-3` … `DP-6` here). Do not switch `gmux` to the Intel GPU and do not disable `amdgpu`: the external ports would go dark.

### Turn it off in GNOME

The setting lives in `~/.config/monitors.xml`. The safe way to produce it is the Settings app: **Settings → Displays**, choose a single-display layout on the external monitor, apply. GNOME asks "Keep changes?" and reverts by itself after 20 seconds if you do not confirm, so a wrong choice cannot lock you out.

I applied the same change over D-Bus and then wrote the file by hand. Whichever way you get there, the result should look like this for each output ([full example](../configs/gnome/monitors.xml.example)):

```xml
<configuration>
  <layoutmode>logical</layoutmode>
  <logicalmonitor>
    <x>0</x>
    <y>0</y>
    <scale>1</scale>
    <primary>yes</primary>
    <monitor>
      <monitorspec>
        <connector>DP-5</connector>
        <vendor>…</vendor>
        <product>…</product>
        <serial>…</serial>
      </monitorspec>
      <mode>
        <width>1920</width>
        <height>1080</height>
        <rate>60.000</rate>
      </mode>
    </monitor>
  </logicalmonitor>
  <disabled>
    <monitorspec>
      <connector>eDP-1</connector>
      <vendor>APP</vendor>
      <product>Color LCD</product>
      <serial>0x00000000</serial>
    </monitorspec>
  </disabled>
</configuration>
```

Two details:

- **Back up first:** `cp -a ~/.config/monitors.xml ~/.config/monitors.xml.bak`.
- **One `<configuration>` per port.** GNOME stores a layout for the exact set of connected outputs. If you only have an entry for `DP-5` and plug the cable into another port, the phantom display is back. I added one block each for `DP-3`, `DP-4`, `DP-5` and `DP-6`. Take `vendor`, `product` and `serial` from the file GNOME wrote for your monitor.

Check afterwards:

```bash
cat /sys/class/drm/card*-eDP-1/enabled        # disabled
```

### The login screen

The login screen (GDM) has its own copy of the layout. On Ubuntu 26.04 it is **not** where older guides say:

- GDM 50 runs the greeter as a dynamic user, so `/var/lib/gdm3/.config/monitors.xml` is ignored.
- The file belongs in `/var/lib/gdm3/seat0/config/monitors.xml`, owned like that directory.

```bash
d=/var/lib/gdm3/seat0/config
sudo install -m 0644 -o "$(sudo stat -c %u "$d")" -g "$(sudo stat -c %g "$d")" \
     ~/.config/monitors.xml "$d/monitors.xml"
```

It takes effect the next time the login screen starts. The machine has been power-cycled since, but whether `eDP-1` is really off at the login screen has not been confirmed separately.

### The kernel option I did not use

`video=eDP-1:d` on the kernel command line disables the connector for everything, including the boot splash and text consoles. I planned it together with a visible GRUB menu and then dropped it: it can only be tested by rebooting, and if it goes wrong the only monitor shows nothing. The GNOME layout was enough. If you try it, have SSH working first. Untested here.

## 2. Lid switch and sleep

Two ways to lose the machine without warning:

- the lid sensor reports "closed" and logind suspends;
- the machine suspends on idle and does not wake its USB-C controllers. Then there is no picture, and with a USB Wi-Fi adapter no network either, so SSH cannot help.

Ignore the lid switch ([file](../configs/logind/50-ignore-lid.conf)):

```ini
# /etc/systemd/logind.conf.d/50-ignore-lid.conf
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo cp configs/logind/50-ignore-lid.conf /etc/systemd/logind.conf.d/
sudo systemctl kill -s HUP systemd-logind       # reload without ending the session
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
       org.freedesktop.login1.Manager HandleLidSwitch              # s "ignore"
```

Do not `restart` logind from inside a desktop session; the HUP signal reloads the configuration and keeps you logged in.

Stop GNOME from suspending:

```bash
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power lid-close-battery-action 'nothing'
```

Suspend and resume were never tested on this machine. t1-revive's README lists suspend/resume as not working with its T1 stack, so even with a lid I would test it carefully.

## Undo

```bash
cp ~/.config/monitors.xml.bak ~/.config/monitors.xml
sudo rm /var/lib/gdm3/seat0/config/monitors.xml
sudo rm /etc/systemd/logind.conf.d/50-ignore-lid.conf && sudo systemctl kill -s HUP systemd-logind
gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type
gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
gsettings reset org.gnome.settings-daemon.plugins.power lid-close-ac-action
gsettings reset org.gnome.settings-daemon.plugins.power lid-close-battery-action
```

Next: [07 — Keeping it working](07-maintenance.md)
