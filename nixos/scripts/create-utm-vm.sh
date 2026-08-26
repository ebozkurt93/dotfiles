#!/usr/bin/env bash
# Create a fresh UTM VM (QEMU backend, HVF-accelerated) via UTM's AppleScript
# scripting suite -- this only creates the empty machine (disk + ISO
# attached, ready to boot the installer); it does not install NixOS.
# Requires UTM.app and its scripting permission granted once (macOS will
# prompt on first run: System Settings > Privacy & Security > Automation).
# UTM's scripting "make new virtual machine" strips display devices by
# default (headless-first design) -- we add a virtio-gpu-pci display back
# explicitly below, otherwise the VM boots with no video output and no
# window ever appears in UTM.
# Network is "emulated" (QEMU usermode/slirp NAT), not UTM's "shared"
# (vmnet) mode -- UTM's "port forwards" property is only honored in
# emulated mode; setting it under shared mode is silently ignored, so
# --ssh-port would never actually listen.
set -euo pipefail

NAME="utm-aarch64"
ARCH="aarch64"
ISO=""
DISK_GB=50
RAM_MB=8192
CPU_CORES=4
SSH_HOST_PORT=2222
START=false

usage() {
  cat <<'USAGE'
Usage: create-utm-vm.sh --iso PATH [options]

  --iso PATH          Path to the NixOS installer ISO (required)
  --name NAME          VM name (default: utm-aarch64)
  --arch ARCH          aarch64 or x86_64 (default: aarch64)
  --disk-size GB        Fixed disk size in GB (default: 50)
  --ram MB             RAM in MiB (default: 8192)
  --cpu N              CPU cores (default: 4)
  --ssh-port PORT      Host port forwarded to guest:22 (default: 2222)
  --start              Start the VM after creating it
  -h, --help           Show this help

Example:
  create-utm-vm.sh --iso ~/Downloads/nixos-minimal-aarch64-linux.iso \
    --ram 12288 --start
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    --disk-size) DISK_GB="$2"; shift 2 ;;
    --ram) RAM_MB="$2"; shift 2 ;;
    --cpu) CPU_CORES="$2"; shift 2 ;;
    --ssh-port) SSH_HOST_PORT="$2"; shift 2 ;;
    --start) START=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$ISO" ]]; then
  echo "error: --iso is required" >&2
  usage >&2
  exit 1
fi
if [[ ! -f "$ISO" ]]; then
  echo "error: iso not found: $ISO" >&2
  exit 1
fi
if ! osascript -e 'id of application "UTM"' >/dev/null 2>&1; then
  echo "error: UTM.app not found/not scriptable" >&2
  exit 1
fi

ISO_ABS="$(cd "$(dirname "$ISO")" && pwd)/$(basename "$ISO")"
DISK_MB=$((DISK_GB * 1024))

osascript <<APPLESCRIPT
tell application "UTM"
  set newVM to make new virtual machine with properties {backend:qemu, configuration:{name:"$NAME", architecture:"$ARCH", memory:$RAM_MB, cpu cores:$CPU_CORES, hypervisor:true, uefi:true, drives:{{removable:true, source:POSIX file "$ISO_ABS"}, {removable:false, guest size:$DISK_MB, raw:false}}, network interfaces:{{mode:emulated, port forwards:{{host port:$SSH_HOST_PORT, guest port:22}}}}, displays:{{hardware:"virtio-gpu-pci"}}}}
  if $START then
    start newVM
    activate
  end if
end tell
APPLESCRIPT

echo "Created UTM VM '$NAME' ($ARCH, ${RAM_MB}MiB RAM, ${DISK_GB}GB disk, ISO attached)."
echo "SSH once installed: ssh -p $SSH_HOST_PORT erdembozkurt@localhost"
echo "After install, eject the ISO drive in UTM (VM settings > Drives) before rebooting."
