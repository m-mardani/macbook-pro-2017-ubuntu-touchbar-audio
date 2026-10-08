# 02 — Safety net: do this before changing anything

Two facts make this Mac harder to rescue than a normal laptop:

- **There is no Esc key.** Esc lives on the Touch Bar, and the Touch Bar is dead. Ubuntu hides the GRUB menu and shows it when you tap Esc at power-on, so you cannot reach "Advanced options" from the built-in keyboard.
- **The fix touches the EFI System Partition**, the partition the Mac boots from.

Ten minutes here means every later step has a way back.

## 1. Remote access (SSH)

```bash
sudo apt install openssh-server
systemctl is-active ssh.socket      # active
ip -4 -brief addr                   # note the address of your network interface
```

From another computer or a phone on the same network:

```bash
ssh <user>@<address>
```

Try it now, while everything works.

An SSH server that accepts passwords is as strong as your password. Before you leave it running, set a long password (`passwd`) or switch to key-only login:

```bash
ssh-copy-id <user>@<address>        # run on the other computer
# then, on the Mac:
echo 'PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/10-keys-only.conf
sudo systemctl restart ssh
sudo sshd -T | grep -i '^passwordauthentication'     # must print "no"
```

Log in with the key from a second terminal before you close the first one.

A USB keyboard is the low-tech alternative: its Esc key works in GRUB.

## 2. Know how to boot the previous kernel without a menu

Keep one older kernel installed. List what you have:

```bash
dpkg -l 'linux-image-*' | awk '/^ii/ {print $2, $3}'
sudo grep -E "^\s*(menuentry|submenu) " /boot/grub/grub.cfg | cut -d"'" -f2
```

To boot an older kernel **once**, from the Mac itself or over SSH:

```bash
sudo grub-reboot 'Advanced options for Ubuntu>Ubuntu, with Linux 7.0.0-30-generic' && sudo reboot
```

Use the exact titles printed by the second command above. The next boot after that returns to the default kernel.

Two things to know about the fallback kernel:

- **DKMS drivers exist only for the kernels they were built for.** If you installed the audio and Touch Bar drivers while running the newer kernel, the older kernel may boot without sound and without Touch Bar. It is a rescue kernel, not a second working setup.
- **`apt autoremove` may want to delete it.** On my machine the only older kernel was marked as automatically installed and removable. Protect it:

  ```bash
  apt-mark showauto | grep -E '^linux-(image|modules|headers)'
  sudo apt-mark manual linux-image-unsigned-7.0.0-30-generic linux-modules-7.0.0-30-generic
  sudo apt autoremove --dry-run       # must no longer list them
  ```

  Use the package names from your own system, and include that kernel's headers packages if `showauto` lists them.

## 3. Back up the EFI System Partition

Needed before the Touch Bar firmware restore in [04](04-touch-bar.md). It takes a minute and about 1 GB.

```bash
ESP=$(findmnt -no SOURCE /boot/efi); echo "$ESP"      # e.g. /dev/nvme0n1p1
mkdir -p ~/esp-backup
sudo dd if="$ESP" of="$HOME/esp-backup/esp.img" bs=4M status=progress
sudo tar -C /boot/efi -cf "$HOME/esp-backup/esp-files.tar" .
( cd ~/esp-backup && sudo sha256sum esp.img esp-files.tar | tee SHA256SUMS )
```

Copy `~/esp-backup` to another disk if you can.

To put the whole partition back (only if you ever need to):

```bash
sudo umount /boot/efi
sudo dd if="$HOME/esp-backup/esp.img" of=/dev/nvme0n1p1 bs=4M conv=fsync    # the device printed above
sudo mount /boot/efi
```

## 4. Power and sleep

- Plug in the charger for the firmware restore.
- Do not let the machine sleep during it. If you run without the internal display, also read [06](06-no-internal-display.md) first: a suspend that does not wake cleanly leaves you with no screen and no network.

## Checklist

- [ ] I can log in over SSH from another device (or I have a USB keyboard).
- [ ] I know the exact `grub-reboot` line for my older kernel, and that kernel is protected from `autoremove`.
- [ ] `~/esp-backup/esp.img` exists and its checksum is written down.
- [ ] Charger is connected.

Next: [03 — Speakers](03-speakers.md)
