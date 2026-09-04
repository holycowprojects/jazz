# Dev/test VM

QEMU + WHPX launch script for the disposable VM used to develop and test the
JAZZ install profile/script. This VM is never the shipped artifact — it's a
throwaway target for iterating on `install/` before anyone runs it against
real hardware.

## Why this boots the way it does (read before changing anything here)

The original plan was a normal graphical UEFI boot (`-bios OVMF...`, letting
GRUB/systemd-boot show its own menu). That doesn't fully work on this host:
**WHPX cannot render an OVMF/UEFI graphical framebuffer at all**, confirmed
through extensive testing on 2 Sept 2026 (see `docs/Research-Reference-List.md`
section 0 for the full diagnostic trail) — broader than the documented
WHPX+pflash MMIO bug (QEMU GitLab #513); even a verified-correct monolithic
OVMF build (confirmed working, rendering the real UEFI boot-device menu,
under `-accel tcg`) drew nothing at all under WHPX. Separately, GRUB's raw
serial input can't be driven unattended — scripted Ctrl+X/F10 byte injection
never triggers a real boot, only an actual human keypress does (3 Sept 2026
finding).

**The fix (current, since 4 Sept 2026): OVMF firmware + QEMU's direct kernel
boot (`-kernel`/`-initrd`/`-append`) together, skipping any bootloader menu
entirely.** QEMU's fw_cfg kernel loader hands the kernel+initrd straight to
OVMF, which jumps directly into it — no boot menu is ever drawn, so neither
problem above is ever triggered. `-vga none` is required too (any VGA-capable
device stalls OVMF's console splitter even if nothing ever renders to it).
Confirmed directly, not assumed: `/sys/firmware/efi` is genuinely present in
the resulting live session — real UEFI, verified over serial, not a fallback.
Output goes over a serial console (`console=ttyS0`) as plain text over a TCP
socket, not a framebuffer, throughout.

**This is also how Task 5 rebooted the actual installed target** — same
OVMF+`-vga none` firmware, but *without* `-kernel`/`-initrd`/`-cdrom`, letting
UEFI's real boot manager find systemd-boot on the ESP. systemd-boot's own
countdown rendered fine over serial too (same "no VGA device" property
applies to its menu as much as GRUB's), reaching a real `jazz login:` prompt
with no human keypress needed anywhere in the chain.

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

The script also needs a monolithic OVMF build (not committed — see
`.gitignore`) at `vm\RELEASEX64_OVMF.fd`. The one currently in use came from
[`retrage/edk2-nightly`](https://github.com/retrage/edk2-nightly)'s releases
(a plain, unmodified `tianocore/edk2` build via public CI — audited before
use). Download its `RELEASEX64_OVMF.fd` release asset and place it there.

## Running the unattended install (Task 5/6)

```powershell
.\vm\launch-dev-vm.ps1 -Fresh   # or -DiskName for an independent second disk
python vm\run-unattended-install.py [SerialPort]
```

This pushes `install/base-profile.json` and `install/base-credentials.json`
into the guest over the serial socket (no shared filesystem exists) and runs
`archinstall --config ... --creds ... --silent`. **`base-credentials.json`
is gitignored (`install/*-credentials.json` - it holds a plaintext root/user
password) and is not in the repo** - copy `install/base-credentials.json.example`
to `install/base-credentials.json` and fill in real values before running
this. The schema (`!root-password`, `!users[].{username,!password,sudo}`) is
archinstall's own credentials-export format, documented on the
[ArchWiki Archinstall page](https://wiki.archlinux.org/title/Archinstall).

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
  log) lives in this directory (gitignored) and **is used by the current
  launch script**, paired with direct kernel boot rather than a graphical
  firmware boot menu (see above).
