#!/usr/bin/env bash
# Read-only health check for a 2016/2017 Touch Bar MacBook Pro (Apple T1) on Linux.
#
# It changes nothing. Run it as your normal user:
#     bash scripts/check.sh
# It uses sudo once, only to list the EFI System Partition (which is normally
# readable by root only). Run with --no-sudo to skip that part.
#
# Exit status: 0 if nothing needs attention, 1 if at least one WARN was printed.

set -u

USE_SUDO=1
[ "${1:-}" = "--no-sudo" ] && USE_SUDO=0

warnings=0
ok()   { printf '  ok    %s\n' "$*"; }
info() { printf '  info  %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; warnings=$((warnings + 1)); }
have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n== %s\n' "$*"; }

# ---------------------------------------------------------------- machine
section "Machine"
model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)
info "model:  $model"
info "kernel: $(uname -r)"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  info "distro: $(. /etc/os-release && echo "${PRETTY_NAME:-unknown}")"
fi
case "$model" in
  MacBookPro13,2|MacBookPro13,3|MacBookPro14,2|MacBookPro14,3) ok "a T1 Touch Bar model" ;;
  *) warn "not one of MacBookPro13,2 / 13,3 / 14,2 / 14,3: the T1 checks below may not apply" ;;
esac

# ---------------------------------------------------------------- T1 on USB
section "T1 chip (USB)"
t1=unknown
if have lsusb; then
  if lsusb -d 05ac:8600 >/dev/null 2>&1; then
    t1=booted;   ok "T1 booted: 05ac:8600 (iBridge)"
  elif lsusb -d 05ac:1281 >/dev/null 2>&1; then
    t1=recovery; warn "T1 in recovery: 05ac:1281. Its firmware was not loaded (see docs/04-touch-bar.md)"
  else
    t1=absent;   warn "no T1 on the USB bus (neither 05ac:8600 nor 05ac:1281)"
  fi
else
  warn "lsusb not found (sudo apt install usbutils)"
fi

# ---------------------------------------------------------------- firmware files
section "T1 firmware on the EFI System Partition"
esp_dir=/boot/efi/EFI/APPLE/EMBEDDEDOS
run_root() { "$@"; }
can_look=1
if [ ! -r /boot/efi/EFI ]; then
  if [ "$USE_SUDO" -eq 1 ] && have sudo; then
    run_root() { sudo "$@"; }
  else
    can_look=0
    info "skipped (the EFI partition is readable by root only; run without --no-sudo)"
  fi
fi
if [ "$can_look" -eq 1 ]; then
  if ! findmnt /boot/efi >/dev/null 2>&1; then
    warn "/boot/efi is not a mount point"
  else
    missing=0
    for f in combined.memboot FDRData version.plist; do
      if run_root test -s "$esp_dir/$f"; then
        size=$(run_root stat -c %s "$esp_dir/$f" 2>/dev/null || echo "?")
        ok "$f present ($size bytes)"
      else
        missing=$((missing + 1))
        warn "$f missing from $esp_dir"
      fi
    done
    if [ "$missing" -eq 0 ] && [ "$t1" = recovery ]; then
      warn "files are present but the T1 is in recovery: do a full power-off, wait 20 s, power on; compare with t1-revive issue #7"
    fi
  fi
fi

# ---------------------------------------------------------------- Touch Bar driver
section "Touch Bar driver"
for m in apple_ibridge apple_touchbar; do
  if [ -d "/sys/module/$m" ]; then ok "$m loaded"; else warn "$m not loaded"; fi
done
if grep -rqs 'skip_acpi_power=1' /etc/modprobe.d/ 2>/dev/null; then
  ok "skip_acpi_power=1 is set in /etc/modprobe.d"
elif [ -d /sys/module/apple_ibridge ] || [ -d /usr/src/apple-ib-drv-0.1 ]; then
  warn "skip_acpi_power=1 not found in /etc/modprobe.d (the ACPI power-on call can freeze these models)"
else
  info "driver not installed; no skip_acpi_power setting expected"
fi
if [ -e /etc/udev/rules.d/99-ibridge.rules ]; then
  ok "udev rule 99-ibridge.rules present"
else
  info "no /etc/udev/rules.d/99-ibridge.rules (written by the t1-touchbar installer)"
fi

# ---------------------------------------------------------------- usbmuxd
section "usbmuxd udev rule"
rule=""
for p in /etc/udev/rules.d/39-usbmuxd.rules /usr/lib/udev/rules.d/39-usbmuxd.rules /lib/udev/rules.d/39-usbmuxd.rules; do
  if [ -e "$p" ]; then rule=$p; break; fi
done
if [ -z "$rule" ]; then
  info "usbmuxd rule not found (usbmuxd not installed?)"
elif grep -q '8600' "$rule"; then
  warn "$rule still matches the T1 (05ac:8600); see docs/04-touch-bar.md step 4"
else
  ok "$rule does not match the T1"
fi

# ---------------------------------------------------------------- key remappers
section "Key remappers"
if have systemctl && systemctl is-active --quiet keyd 2>/dev/null; then
  if [ -d /sys/module/apple_touchbar ]; then
    warn "keyd is running: holding Fn will not switch the Touch Bar to F1-F12 (sudo systemctl disable --now keyd)"
  else
    info "keyd is running (fine while the Touch Bar is dead; disable it afterwards)"
  fi
else
  ok "keyd not running"
fi

# ---------------------------------------------------------------- audio
section "Audio"
cs=/sys/module/snd_hda_codec_cs8409
if [ -d "$cs" ]; then
  loaded=$(cat "$cs/srcversion" 2>/dev/null || echo "?")
  ondisk=$(modinfo -F srcversion snd_hda_codec_cs8409 2>/dev/null || echo "?")
  file=$(modinfo -F filename snd_hda_codec_cs8409 2>/dev/null || echo "?")
  case "$file" in
    */updates/dkms/*) ok "module on disk is the DKMS build" ;;
    *) warn "module on disk is the stock one ($file): the Apple driver is not installed for this kernel" ;;
  esac
  if [ "$loaded" = "$ondisk" ] && [ "$loaded" != "?" ]; then
    ok "loaded module matches the one on disk"
  else
    warn "loaded module differs from the one on disk (reboot, or reload the module)"
  fi
else
  warn "snd_hda_codec_cs8409 not loaded"
fi
if have aplay; then
  if aplay -l 2>/dev/null | grep -q 'CS8409/CS42L83'; then
    ok "sound card: CS8409/CS42L83 Analog"
  else
    warn "no 'CS8409/CS42L83 Analog' device in aplay -l"
  fi
fi

# ---------------------------------------------------------------- DKMS
section "DKMS (for the running kernel $(uname -r))"
if have dkms; then
  status=$(dkms status 2>/dev/null)
  for pkg in apple-ib-drv snd_hda_macbookpro; do
    line=$(printf '%s\n' "$status" | grep "^$pkg/" | grep -F "$(uname -r)" | head -n1)
    if [ -z "$line" ]; then
      warn "$pkg: nothing built for this kernel"
    elif printf '%s' "$line" | grep -q 'installed'; then
      ok "$line"
    else
      warn "$line"
    fi
  done
else
  warn "dkms not found"
fi

# ---------------------------------------------------------------- displays
section "Displays"
found=0
for c in /sys/class/drm/card*-*; do
  [ -e "$c/status" ] || continue
  found=1
  st=$(cat "$c/status"); en=$(cat "$c/enabled" 2>/dev/null || echo "?")
  [ "$st" = connected ] || continue
  name=$(basename "$c")
  info "$name: connected, $en"
done
[ "$found" -eq 1 ] || info "no DRM connectors found"

# ---------------------------------------------------------------- services
section "Services"
if have systemctl; then
  for u in ssh.socket mbpfan keyd usbmuxd; do
    en=$(systemctl is-enabled "$u" 2>/dev/null | head -n1); [ -n "$en" ] || en="not installed"
    ac=$(systemctl is-active  "$u" 2>/dev/null | head -n1); [ -n "$ac" ] || ac="-"
    info "$(printf '%-11s enabled=%-13s active=%s' "$u" "$en" "$ac")"
  done
  if have busctl; then
    lid=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
          org.freedesktop.login1.Manager HandleLidSwitch 2>/dev/null | cut -d'"' -f2)
    [ -n "$lid" ] && info "logind HandleLidSwitch=$lid"
  fi
fi

# ---------------------------------------------------------------- kernels
section "Installed kernels"
if have dpkg-query; then
  dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'linux-image-*' 2>/dev/null \
    | awk '$1 == "ii" && $2 ~ /[0-9]/ { print "  info  " $2 }'
fi

printf '\n'
if [ "$warnings" -eq 0 ]; then
  echo "Nothing needs attention."
  exit 0
fi
echo "$warnings item(s) need attention (lines marked WARN)."
exit 1
