# Dev/test VM

QEMU + WHPX launch script for the disposable VM used to develop and test the
JAZZ install profile/script. This VM is never the shipped artifact — it's a
throwaway target for iterating on `install/` before anyone runs it against
real hardware.

## Why this boots the way it does (read before changing anything here)

The original plan was a normal graphical UEFI boot (`-bios OVMF...`). That
does not work on this host: **WHPX cannot render an OVMF/UEFI graphical
framebuffer at all**, confirmed through extensive testing on 2 Sept 2026 (see
`docs/Research-Reference-List.md` section 0 for the full diagnostic trail).
This is broader than the well-documented WHPX+pflash MMIO bug (QEMU GitLab
#513) — even a verified-correct monolithic OVMF build (confirmed working,
rendering the real UEFI boot-device menu, under `-accel tcg`) drew nothing at
all under WHPX, across every firmware/device/machine-type combination tried.
The firmware runs fine (confirmed via real CPU burn); WHPX just never
displays it.

**The fix:** boot via QEMU's direct kernel boot (`-kernel`/`-initrd`/
`-append`), which loads the archiso's own kernel and initramfs straight into
guest memory via SeaBIOS (legacy BIOS) instead of OVMF — no firmware boot
menu is ever rendered, so the broken WHPX graphics path is never touched.
Output goes over a serial console (`console=ttyS0`) as plain text over a TCP
socket, not a framebuffer.

**Consequence for later tasks:** this boots the *live installer environment*
via legacy BIOS, not UEFI. `/sys/firmware/efi` will not exist in that live
session. SPEC.md requires the *installed target system* to be UEFI-bootable
(systemd-boot) regardless — Task 4/5 need to explicitly verify archinstall
still produces a correct UEFI target (ESP partition, systemd-boot install)
even though the live environment that runs it booted via BIOS. Don't assume
this "just works" — check it.

## First-time setup

Download the official vanilla Arch ISO (not committed — see `.gitignore`):

```powershell
Invoke-WebRequest -Uri "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso" -OutFile "vm\archlinux-x86_64.iso"
```

Extract the kernel and initramfs the direct-boot path needs (Windows can
mount ISOs natively, no extra tools required):

```powershell
$img = Mount-DiskImage -ImagePath "vm\archlinux-x86_64.iso" -PassThru
$drive = ($img | Get-Volume).DriveLetter
Copy-Item "${drive}:\arch\boot\x86_64\vmlinuz-linux" "vm\vmlinuz-linux"
Copy-Item "${drive}:\arch\boot\x86_64\initramfs-linux.img" "vm\initramfs-linux.img"
Dismount-DiskImage -ImagePath "vm\archlinux-x86_64.iso"
```

The `archisosearchuuid` value baked into `launch-dev-vm.ps1` must match the
ISO you downloaded — find it in `${drive}:\loader\entries\01-archiso-linux.conf`
(the `archisosearchuuid=` option) after mounting, and update the script if it
differs from what's currently there.

## Usage

```powershell
# Boot (attaches the ISO automatically; direct kernel boot needs it for the root filesystem)
.\vm\launch-dev-vm.ps1

# Reset to a clean disk (Task 6's reproducibility check)
.\vm\launch-dev-vm.ps1 -Fresh
```

Once it's running, connect to the serial console in a separate terminal:

```powershell
python vm\serial-console.py       # two-way, line-buffered: type commands, see output
python vm\serial-console-raw.py   # two-way, raw mode: required for archinstall's TUI
python vm\watch-serial.py         # read-only viewer
```

`serial-console.py` is line-buffered (sends a line once you press Enter) -
fine for running shell commands, but confirmed (2 Sept 2026, live probe)
unable to drive `archinstall`: it's a full-screen Textual app that enables
the alternate screen buffer and mouse tracking the instant it starts, which
needs every keystroke forwarded immediately, not batched per line. Use
`serial-console-raw.py` for the interactive archinstall session in Task 4 -
it puts the Windows console into raw mode (`ENABLE_VIRTUAL_TERMINAL_INPUT`)
so arrow keys, Tab, and single-key selections all forward correctly. Ctrl+]
quits it (Ctrl+C is forwarded to the guest instead of killing the client).

Only one client can hold the serial connection at a time.

## Design notes (don't rediscover these — see docs/Research-Reference-List.md section 0 for sourcing)

- **Disk layout:** `arch-base.qcow2` is an empty 20G canvas, created once.
  `arch-dev-overlay.qcow2` is a qcow2 overlay backed by it and is the actual
  VM disk. `-Fresh` deletes and recreates the overlay — instant, since it's
  just a small header referencing the base — instead of re-provisioning a
  multi-GB disk on every reset.
- **Networking:** `-netdev user` (SLIRP/user-mode NAT). No admin rights or
  TAP driver needed. **Known limitation: ICMP isn't proxied, so `ping` to the
  guest from the host will not work** — expected, not a bug. Guest-to-internet
  access and host→guest port forwarding both work normally.
- **RAM:** defaults to 4096 MB. Override with `-RamMB`.
- **A verified working monolithic OVMF build** (`RELEASEX64_OVMF.fd`, from
  `retrage/edk2-nightly` — audited before download, see chat history/decision
  log) is kept in this directory (gitignored) in case UEFI graphical boot is
  worth retrying later (different QEMU version, different host, etc.) — it is
  not used by the current launch script.
