# NixOS Install Runbook — VM Practice + Real Hardware

One runbook for both: practice the exact same flow in the UTM VM first,
then reuse it on the real machine later. Steps that differ are marked
**[VM]** / **[HW]**; everything else is identical on both.

This is *not* a from-scratch example flake — it's this repo
(`~/personal-repositories/dotfiles-nixos`, github.com/ebozkurt93/dotfiles,
branch `nixos`). The VM host (`utm-aarch64`) already exists in
`flake.nix` / `nixos/hosts/utm-aarch64/` from prior work. Installing to a
fresh VM disk mostly means: partition, regenerate
`hardware-configuration.nix` for the new disk, install, boot. You do not
need to invent a new host or flake output for the VM.

For real hardware you *will* add a new host (new hostname, new
`nixos/hosts/<name>/`), following the same `mkNixosHost` pattern already
used by `utm-aarch64` and `x86_64-generic` in `flake.nix`.

---

# 0. Environment

**[VM]**
```text
Tooling:    UTM.app, VM created via nixos/scripts/create-utm-vm.sh
            (UTM's own AppleScript scripting suite — QEMU backend, HVF
            hypervisor). Not the plain-QEMU run-vm.sh this doc used to
            describe — that script was never actually written; the real
            utm-aarch64 VM referenced throughout MIGRATION.md was always a
            UTM-managed VM, controlled afterward with utmctl.
Arch:       aarch64-linux
Firmware:   UEFI (UTM's bundled edk2-aarch64)
Disk:       new fixed 50G qcow2, created inside the .utm bundle
Network:    UTM shared/NAT network, host port 2222 forwarded to guest 22
ISO:        NixOS minimal, aarch64
```
Create the VM (just the empty machine — disk + ISO attached, ready to boot
the installer; does not touch NixOS at all):
```bash
nixos/scripts/create-utm-vm.sh --name utm-aarch64 \
  --iso ~/Downloads/<nixos-minimal-aarch64...>.iso --ram 12288 --start
```
(`--ram` is in MiB — 12288 = 12GB. Default is 8192/8GB if you omit it. See
`create-utm-vm.sh --help` for the rest of the flags: `--disk-size`, `--cpu`,
`--ssh-port`.)
This calls UTM's scripting suite (`osascript`, not `utmctl` — `utmctl` can
start/stop/clone/delete VMs but can't create one from scratch). First run
prompts macOS for Automation permission (System Settings > Privacy &
Security > Automation > this terminal app > UTM) — approve it once.

Manage the VM afterward the same way as before: `utmctl start/stop
utm-aarch64`, or the UTM GUI. If you re-run the practice install from
scratch (section 24, step 11), delete the old VM first —
`utmctl delete utm-aarch64` — then re-run `create-utm-vm.sh`.

**[HW]**
```text
Arch:       whatever the real CPU is (check before assuming x86_64)
Firmware:   UEFI, Secure Boot off initially (see section 28)
Disk:       real disk — confirm you have the RIGHT one before partitioning
Network:    real NIC — see section 3 for wifi/firmware notes
ISO:        NixOS minimal ISO written to a USB stick
```

---

# 1. Confirm UEFI boot

Run this as the `nixos` user (no root needed yet):

```bash
test -d /sys/firmware/efi && echo "UEFI boot confirmed"
bootctl status
```

Do not continue if the installer booted in legacy BIOS mode.

---

# 2. Networking

Still as `nixos`, no root needed:

```bash
ip addr
ping -c 3 nixos.org
```

**[VM]** Just works — QEMU's usermode NAT hands the guest a DHCP address
automatically. No action needed.

**[HW]**
- Wired ethernet: normally just works the same way (DHCP via
  NetworkManager, already enabled on the live ISO).
- WiFi: run `nmtui` to pick an SSID and enter the password before the
  `ping` will succeed — the VM never exercises this path.
- If the WiFi chip needs closed-source firmware and the live ISO can't
  see it at all (`ip addr` shows no wireless interface), that's a real
  gap the VM won't catch either — you may need
  `hardware.enableRedistributableFirmware = true;` in the installed
  config (not currently set anywhere in this repo — add it to the new
  host's `configuration.nix` if needed, see section 13).

Note: once installed, both cases are handled by the flake already —
`nixos/modules/desktop-hyprland.nix` sets
`networking.networkmanager.enable = true` for every host (needed for
Quickshell's network widget). Nothing extra to configure there.

## SSH in instead of typing in the console

Worth doing once here so the rest of this runbook can be copy-pasted from
a real terminal, instead of retyping everything into the VM window /
plugging in a keyboard on real hardware. Do this now, still as `nixos`
and still **before** the "become root" step below — running plain
`passwd` after `sudo -i` sets root's password instead of `nixos`'s, which
breaks the login below with "too many authentication failures".

```bash
passwd
```

**[VM]** From the Mac (`create-utm-vm.sh` forwards the guest's port 22 to
`localhost:2222`):
```bash
ssh -p 2222 nixos@localhost
```

**[HW]** Get the real IP first (`ip addr` above), then:
```bash
ssh nixos@<the-real-ip>
```

Do the rest of this runbook from that SSH session.

After install + reboot, the user is `erdembozkurt` instead — set its
password too (section 17), then use that user/port instead:
```bash
ssh -p 2222 erdembozkurt@localhost   # VM, post-install
ssh erdembozkurt@<ip>                # HW, post-install
```

---

# 3. Become root

From here on, run commands as root — inside the SSH session from above:

```bash
sudo -i
```

---

# 4. Identify the target disk

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

**[VM]** Only one virtio disk is attached — it'll be `/dev/vda`, ~50G.

**[HW]** Device naming varies (`/dev/sda`, `/dev/nvme0n1`, ...). **Check
the size carefully against what you expect** — this is the one step
where a wrong guess is destructive and unrecoverable.

```bash
DISK=/dev/vda   # adjust for HW
echo "$DISK"
lsblk "$DISK"
```

**The partitioning commands below destroy the selected disk.**

---

# 5. Partition the disk

GPT, 512M FAT32 ESP + ext4 root (matches the sizing already used by the
existing `utm-aarch64` host):

Run these step by step just in case something goes wrong, and inspect the output

```bash
parted "$DISK" --script -- mklabel gpt
parted "$DISK" --script -- mkpart ESP fat32 1MiB 513MiB
parted "$DISK" --script -- set 1 esp on
parted "$DISK" --script -- mkpart root ext4 513MiB 100%
parted "$DISK" -- print
lsblk "$DISK"
```

---

# 6. Set partition variables

```bash
# Whole-disk name doesn't end in a digit (vda, sda): just append the number.
# /dev/vda -> vda1 / vda2
# /dev/sda -> sda1 / sda2
# Whole-disk name ends in a digit (nvme0n1, mmcblk0): need a "p" separator
# first, otherwise the partition number is ambiguous.
# /dev/nvme0n1 -> nvme0n1p1 / nvme0n1p2
EFI=/dev/vda1
ROOT=/dev/vda2
printf 'DISK=%s\nEFI=%s\nROOT=%s\n' "$DISK" "$EFI" "$ROOT"
```

---

# 7. Format

```bash
mkfs.fat -F 32 -n boot "$EFI"
mkfs.ext4 -L nixos "$ROOT"
lsblk -f "$DISK"
```

---

# 8. Mount

```bash
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
findmnt /mnt
findmnt /mnt/boot
```

---

# 9. Decide the host

**[VM]** Reuse the existing host — `HOST=utm-aarch64`. It's already
defined in `flake.nix`'s `nixosConfigurations` and
`nixos/hosts/utm-aarch64/configuration.nix`. Skip straight to section 10.

**[HW]** Pick a real hostname (e.g. the machine's actual name), and note
it — you'll create `nixos/hosts/<name>/` for it in section 13.

```bash
HOST=utm-aarch64   # or your new hostname for HW
```

---

# 10. Get the repo onto the target filesystem

Convention in this repo (see `MIGRATION.md`): the flake lives at
`~/dotfiles` under the target user's home, **not** `/etc/nixos`, so the
same path works both during install (under `/mnt`) and after reboot
(`sudo nixos-rebuild switch --flake ~/dotfiles#<host>`).

```bash
mkdir -p /mnt/home/erdembozkurt
REPO=/mnt/home/erdembozkurt/dotfiles
```

**[VM]** Manual copy, not `git clone` — this repo has private submodules
(`personal`, `instabee`) and the active work is on an unpushed-verify
`nixos` branch, so a plain clone on the VM would hit auth/branch gaps.
From your Mac, over the VM's forwarded SSH port (set a password on the
`nixos` user first if you haven't, or use its existing authorized key):

```bash
# on the Mac, not in the VM:
rsync -avz --exclude .git -e "ssh -p 2222" \
  ~/personal-repositories/dotfiles-nixos/ nixos@localhost:/tmp/dotfiles/
```
`.git` excluded on purpose: `~/personal-repositories/dotfiles-nixos` is a
**git worktree**, not a full clone (`git worktree add ... -b nixos`, see
`MIGRATION.md`) — a worktree's `.git` is a small pointer *file* (not a
directory) referencing the real object database elsewhere on the Mac.
Copying that file anywhere else is useless, it just points at a path
that doesn't exist on the target. (This is specific to this worktree
setup, not a general rsync rule — a normal clone has a real `.git`
directory and including it would just work, no `git init` dance needed.)
Then inside the VM:
```bash
mkdir -p /mnt/home/erdembozkurt
cp -r /tmp/dotfiles /mnt/home/erdembozkurt/dotfiles
cd /mnt/home/erdembozkurt/dotfiles
git init
git add -A
```
`git init` here makes `$REPO` a real, self-contained local git repo (no
history, just the current tree staged) — no GitHub connection, nothing
pushed. That's enough for Nix's git-tracked-file filtering; section 12
still applies normally from here.

**[HW]** If the target is reachable over SSH from another machine (e.g.
the Mac, same LAN) — simplest option, no GitHub auth needed at all, same
as the VM path above:
```bash
# from the other machine, not on the target:
rsync -avz --exclude .git -e "ssh -p 22" \
  ~/personal-repositories/dotfiles-nixos/ nixos@<target-ip>:/tmp/dotfiles/
```
then on the target:
```bash
mkdir -p /mnt/home/erdembozkurt
cp -r /tmp/dotfiles /mnt/home/erdembozkurt/dotfiles
```

Otherwise, if the target machine is truly all you have — pull straight
from GitHub on it:
```bash
git clone git@github.com:ebozkurt93/dotfiles.git "$REPO"
cd "$REPO" && git checkout nixos   # if the work isn't merged to master yet
git submodule update --init
```
Needs an SSH key/GitHub auth already usable on that machine for the
private submodules — set that up before this step, not during.

**No second device to copy an existing key from?** Generate a fresh
keypair right there on the target machine and register its public half
with GitHub from any browser (phone is fine):

```bash
ssh-keygen -t ed25519 -C "install-$(hostname)-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

Paste that into github.com → Settings → SSH and GPG keys → New SSH key,
then run the `git clone` above. This is a separate key from
`~/.ssh/nixos_vm_utm` baked into `configuration.nix`'s `authorizedKeys`
(that one's for *logging into* the host later, not for *cloning from*
GitHub) — fine to delete this one from your GitHub account afterward,
it's only needed transiently for this install.

---

# 11. Regenerate hardware-configuration.nix for THIS disk

Never reuse one from another machine/disk — UUIDs won't match.

The existing file already documents the right invocation
(`nixos/hosts/utm-aarch64/hardware-configuration.nix`'s header comment):
write directly to the host's file instead of letting
`nixos-generate-config` also drop a stray `configuration.nix` you'd have
to clean up:

```bash
nixos-generate-config --root /mnt --show-hardware-config \
  > "$REPO/nixos/hosts/$HOST/hardware-configuration.nix"
```

**[HW]** if `$HOST` is new, `mkdir -p "$REPO/nixos/hosts/$HOST"` first.

Sanity check:
```bash
grep -A 10 'fileSystems."/"' "$REPO/nixos/hosts/$HOST/hardware-configuration.nix"
grep -A 10 'fileSystems."/boot"' "$REPO/nixos/hosts/$HOST/hardware-configuration.nix"
```

---

# 12. Stage it for the flake to see

Nix flakes evaluate the Git-tracked tree, so a freshly generated/changed
file needs to be staged even if not committed, or Nix won't see it:

```bash
cd "$REPO"
git status --short
git add "nixos/hosts/$HOST/hardware-configuration.nix"
git status --short
```

---

# 13. New host only [HW]

Skip this whole section for the VM — `utm-aarch64` already exists.

Add the host using the existing helper, matching the pattern already used
for `utm-aarch64`/`x86_64-generic` in `flake.nix`'s `nixosConfigurations`
block:

```nix
nixosConfigurations = {
  # ...existing hosts...
  my-new-host = self.mkNixosHost {
    hostPath = ./nixos/hosts/my-new-host/configuration.nix;
    system = "x86_64-linux"; # or aarch64-linux — check the real CPU
  };
};
```

Then write `nixos/hosts/<name>/configuration.nix` — copy
`nixos/hosts/utm-aarch64/configuration.nix` as the starting point (same
user, same `desktop-hyprland.nix` import) and adjust:
- `networking.hostName`
- Add `hardware.enableRedistributableFirmware = true;` if WiFi needed
  firmware in section 3
- Anything hardware-specific (GPU driver, power management) once you know
  what the machine actually needs

---

# 14. Check the flake before installing

```bash
cd "$REPO"
nix --extra-experimental-features 'nix-command flakes' flake show
nix --extra-experimental-features 'nix-command flakes' flake check
```

Confirm `nixosConfigurations.<HOST>` appears.

---

# 15. Build without installing (sanity check) — optional, can skip

**Careful with this one for a full desktop config (Hyprland/Firefox/VLC
etc.):** a bare `nix build` here builds into the *live ISO's own* Nix
store, which sits on a RAM-backed tmpfs, not your real disk — a full
desktop closure can easily blow past that (seen in practice: "No space
left on device" with an 8GB VM, even though the 50G target disk was
nearly empty). `nixos-install` in the next section doesn't have this
problem, it targets `/mnt`'s real disk-backed store directly. So: this
step is optional and safe to skip straight to section 16 — only run it
if you actually want a pre-check, and if you do, point it at the disk
instead of tmpfs:

```bash
nix --extra-experimental-features 'nix-command flakes' \
  build --store /mnt ".#nixosConfigurations.${HOST}.config.system.build.toplevel" \
  --print-out-paths
```

If a previous attempt already ran without `--store /mnt` and filled the
tmpfs, clear it first: `nix-collect-garbage -d`.

---

# 16. Install

```bash
nixos-install --flake "$REPO#${HOST}"
```

Set the root password when prompted.

**[VM]** With `create-utm-vm.sh`'s default 8GB RAM, this can get OOM-killed
partway through — seen in practice on `quickshell` (compiles from
source, heavy Qt6/MOC build, memory-hungry regardless of `nix build`'s
job count). Symptom: the build just says `Killed` and stops, no disk
space error. If it happens, add swap on the real disk (not the live
ISO's tmpfs root — that wouldn't help) and retry:

```bash
fallocate -l 8G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
free -h
nixos-install --flake "$REPO#${HOST}"   # retry — already-built paths are cached, so this resumes rather than restarting
```

This swapfile is **not** persistent config (`swapon` here is just for
this live session, nothing gets written to the installed
`configuration.nix`) — but the 8GB file itself physically sits on your
real disk, and `/mnt` is about to become `/`, so it outlives the install
unless you delete it. Clean up once `nixos-install` succeeds, either
still in the live session:
```bash
swapoff /mnt/swapfile
rm /mnt/swapfile
```
or after reboot from the installed system:
```bash
sudo rm /swapfile
```

**[HW]** Real hardware should have enough RAM that this doesn't come up
— skip the swapfile dance unless you actually hit the same `Killed`
symptom.

---

# 17. Set the normal user's password

```bash
nixos-enter --root /mnt -c 'passwd erdembozkurt'
```

(The existing host config's SSH `authorizedKeys` already has
`~/.ssh/nixos_vm_utm.pub` baked in — password login is just a fallback
for console access.)

---

# 18. Inspect boot files

```bash
bootctl --esp-path=/mnt/boot status
find /mnt/boot -maxdepth 4 -type f | sort
```

---

# 19. Reboot

```bash
reboot
```

**[VM]** Not yet verified under UTM (the old `-boot`-device-order reasoning
in earlier drafts of this doc was written for a plain-QEMU script that was
never actually built — don't trust it here). Safest path: before rebooting,
eject the ISO drive in UTM (VM settings > Drives > select the CD/DVD drive
> Eject, or `sudo eject /dev/sr0` from inside the VM if that's easier) so
there's nothing to boot from but the now-installed disk. If UTM's aarch64
`virt` firmware does reliably prefer the fixed disk once it's bootable
(untested claim, confirm empirically on the practice run and update this
note), the eject step becomes optional.

**[HW]** Remove/eject the install USB before or during reboot.

---

# 20. First boot checks

```bash
nixos-version
hostnamectl
lsblk -f
findmnt
bootctl status
systemctl --failed
ping -c 3 nixos.org
sudo whoami   # expect: root
```

---

# 21. Rebuild from the flake after install

If you see `home-manager-erdembozkurt.service` fail with `repository
path '/home/erdembozkurt/dotfiles' is not owned by current user (libgit2
error code 7)`: the copy/`git init` in sections 10-12 ran as root during
install, so `~/dotfiles` is still `root:root`-owned, but home-manager
activation runs as `erdembozkurt` and libgit2 refuses to trust a repo it
doesn't own. Fix once, then retry:

```bash
sudo chown -R erdembozkurt:users /home/erdembozkurt/dotfiles
```

If instead (or after fixing the above) you see `home-manager-erdembozkurt.
service` fail on `installTPM`, cloning `tpm` then erroring `unknown
variable: TMUX_PLUGIN_MANAGER_PATH` / `FATAL: Tmux Plugin Manager not
configured in tmux.conf`: this repo manages dotfiles via **stow**, not
home-manager's `home.file` (packages/activation only go through Nix,
configs stay in each tool's native format/location — deliberate repo
convention). Nothing has stowed anything onto `$HOME` yet on a fresh
install, so `~/.tmux.conf` doesn't exist and TPM's install script has
nothing to read. `stow` itself is already on `$PATH` at this point (the
`installPackages` activation step runs before `installTPM` and already
succeeded), so:

```bash
cd ~/dotfiles
./scripts/stow.sh
```

Then retry:

```bash
cd ~/dotfiles
sudo nixos-rebuild switch --flake ".#${HOST}"
```

`test`/`build` subcommands work the same way for dry-runs.

Home Manager is already wired in as a NixOS module via `mkNixosHost` in
`flake.nix` — a normal `nixos-rebuild switch` applies it too, no separate
`home-manager switch` needed.

---

# 22. What changes moving from VM to real hardware

```text
boot NixOS ISO
identify disk               <- same, but verify size on HW, no do-overs
partition / format / mount  <- identical commands both ways
copy/clone the flake        <- VM: rsync manual copy. HW: git clone
regenerate hardware-configuration.nix  <- identical command both ways
(HW only) add new host to flake.nix
nixos-install --flake ...#hostname
reboot                      <- VM: relies on disk-before-cdrom device order
```

Hardware-specific pieces to expect on real metal, none exercised by the
VM: WiFi `nmtui` + firmware, real GPU driver choice, power management
tuning, Secure Boot enrollment (below), possibly disk encryption.

---

# 23. Secure Boot — next stage (do after the plain install works)

**[HW] only — confirmed not possible in the UTM VM.** Checked directly on
the running `utm-aarch64` VM: `bootctl status` reports `Secure Boot:
disabled (unsupported)`, and `/sys/firmware/efi/efivars` has no
`SecureBoot`/`PK`/`KEK` variables at all — UTM's bundled aarch64 EDK2
firmware doesn't implement Secure Boot, so there's nothing for
`sbctl`/Lanzaboote to enroll into no matter how the NixOS config is
written. This section can only be exercised on real hardware.

Uses Lanzaboote. Add to `flake.nix` inputs:
```nix
lanzaboote = {
  url = "github:nix-community/lanzaboote/v1.1.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Host config:
```nix
{ lib, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.sbctl ];
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
```

```bash
sudo sbctl create-keys
sudo nixos-rebuild switch --flake ~/dotfiles#${HOST}
sudo sbctl verify
```

> **Important:** don't use firmware options like "Clear All Secure Boot
> Keys" — on some firmware this also wipes `dbx` (the revocation
> database), not just your keys. Prefer whichever firmware option puts
> Secure Boot into **Setup Mode** while preserving existing databases.
> Keep Microsoft's certificates enrolled too if you ever dual-boot or rely
> on signed option ROMs.

```bash
sudo sbctl enroll-keys --microsoft
```

Then, after reboot: `bootctl status`, `sudo sbctl status`. Don't enforce
Secure Boot until the system is confirmed signed.

---

# 24. Practice order in the VM before touching hardware

```text
1. Manual disk partitioning
2. Mount target filesystem
3. Copy the existing flake over
4. Regenerate hardware-configuration.nix for utm-aarch64
5. Install with nixos-install --flake
6. Boot successfully
7. Rebuild with nixos-rebuild switch --flake
8. Verify Home Manager / Hyprland came up
9. Break a config on purpose and roll back
10. Add Secure Boot/Lanzaboote -- [HW] only, VM firmware doesn't support it (see section 23)
11. Repeat the whole install from scratch, unassisted
```

---

# 25. Out of scope for now

```text
LUKS full-disk encryption / TPM unlock
Btrfs/subvolumes
swap/hibernation
dual boot
resizing existing partitions
NVIDIA-specific setup
impermanence / disko
```
