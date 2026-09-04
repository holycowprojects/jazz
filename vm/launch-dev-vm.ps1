<#
Launch script for the JAZZ dev/test VM (QEMU + WHPX on Windows).
See vm/README.md for the full story and the reasoning behind each choice below.

Boots via OVMF (genuine UEFI firmware) + QEMU's direct kernel boot
(-kernel/-initrd/-append), with serial console output (console=ttyS0)
captured as text over a TCP socket. No firmware boot menu is ever rendered
and no GRUB is involved at all - QEMU's fw_cfg kernel loader hands the
kernel+initrd straight to OVMF, which jumps directly into it. This sidesteps
two separate problems discovered during Task 3/4 testing (full trail in
docs/Research-Reference-List.md section 0):
  1. WHPX cannot render an OVMF/UEFI graphical framebuffer on this host at
     all (confirmed 2 Sept 2026 - broader than the documented pflash MMIO
     bug, QEMU GitLab #513). Never an issue here since no boot menu is drawn.
  2. GRUB's raw serial input can't be driven unattended - scripted Ctrl+X/F10
     byte injection never worked, only a real human keypress did (3 Sept
     2026). Never an issue here since GRUB is skipped entirely.
Confirmed 4 Sept 2026: this combination reaches `archiso login:` fully
unattended, and `/sys/firmware/efi` exists in the resulting session
(config_table, efivars, fw_platform_size, runtime, runtime-map, systab all
present) - genuine UEFI, verified directly over serial. This is what makes
Task 5's unattended `archinstall --silent` viable: archinstall's bootloader
step should offer systemd-boot with no "UEFI not detected" warning, matching
what Task 4 saw when driven interactively through OVMF+GRUB.

`-vga none` matters even though no framebuffer is ever drawn here - carried
over from the Task 4 finding that OVMF's console splitter stalls before
producing any output (even serial) if a VGA-capable display device exists
at all, regardless of whether it's ever rendered to.

Networking uses -netdev user (SLIRP). Known limitation: ICMP is not proxied,
so `ping` to the guest from the host will not work. Guest-to-internet access
and host->guest port forwarding both work fine; use those instead of ping
for reachability checks.
#>

param(
    [switch]$Fresh,      # delete and recreate the overlay disk for a clean install
    [int]$RamMB = 4096,
    [int]$Cpus = 4,
    [int]$SerialPort = 4445,
    [int]$MonitorPort = 4444,
    [string]$DiskName = "arch-dev-overlay.qcow2"   # override for a second independent overlay (Task 6 reproducibility)
)

$ErrorActionPreference = "Stop"
$VmDir = $PSScriptRoot
$QemuDir = "C:\Program Files\qemu"
$QemuExe = Join-Path $QemuDir "qemu-system-x86_64.exe"
$QemuImg = Join-Path $QemuDir "qemu-img.exe"
$BaseDisk = Join-Path $VmDir "arch-base.qcow2"
$Overlay = Join-Path $VmDir $DiskName
$Iso = Join-Path $VmDir "archlinux-x86_64.iso"
$Kernel = Join-Path $VmDir "vmlinuz-linux"
$Initrd = Join-Path $VmDir "initramfs-linux.img"
$Ovmf = Join-Path $VmDir "RELEASEX64_OVMF.fd"

if (-not (Test-Path $QemuExe)) {
    throw "qemu-system-x86_64.exe not found at $QemuExe - is QEMU installed? (see Task 2)"
}
foreach ($f in @($Iso, $Kernel, $Initrd, $Ovmf)) {
    if (-not (Test-Path $f)) {
        throw "Required file not found: $f - see vm/README.md for how to obtain it"
    }
}

# Base disk: an empty canvas. Created once; the overlay is what actually gets written to.
# 80G (not 20G) since Task 13 found 20G isn't enough headroom once real AI
# containers (CUDA-enabled PyTorch, Ollama models) enter the picture - see
# docs/Research-Reference-List.md section 0. NOTE: this only affects a
# brand-new base disk. install/base-profile.json's own disk_config still
# hardcodes a ~19GiB Btrfs partition size from when it was exported against
# a 20G disk - a fresh archinstall run (Task 6-style) against this bigger
# base disk will still only use ~19GiB unless that's addressed too (not yet
# done - flagged, not fixed, as of this comment).
if (-not (Test-Path $BaseDisk)) {
    Write-Host "Creating base disk (80G, empty, sparse) at $BaseDisk"
    & $QemuImg create -f qcow2 $BaseDisk 80G | Out-Null
}

if ($Fresh -and (Test-Path $Overlay)) {
    Write-Host "Removing existing overlay for a fresh disk"
    Remove-Item $Overlay
}
if (-not (Test-Path $Overlay)) {
    Write-Host "Creating overlay disk backed by $BaseDisk"
    & $QemuImg create -f qcow2 -F qcow2 -b $BaseDisk $Overlay | Out-Null
}

# archisosearchuuid must match the mounted ISO's own UUID (see D:\boot\loader\entries\*.conf
# after mounting the ISO, or D:\boot\*.uuid) - it changes per ISO release/download.
$ArchIsoSearchUuid = "2026-09-01-17-09-43-00"

$qemuArgs = @(
    "-accel", "whpx"
    "-m", "$RamMB"
    "-smp", "$Cpus"
    "-bios", "$Ovmf"
    "-kernel", "$Kernel"
    "-initrd", "$Initrd"
    "-append", "archisobasedir=arch archisosearchuuid=$ArchIsoSearchUuid console=ttyS0,115200"
    "-drive", "file=$Overlay,if=virtio"
    "-cdrom", "$Iso"
    "-netdev", "user,id=n0"
    "-device", "virtio-net,netdev=n0"
    "-vga", "none"
    "-nographic"
    "-serial", "tcp:127.0.0.1:$SerialPort,server,nowait"
    "-monitor", "tcp:127.0.0.1:$MonitorPort,server,nowait"
)

Write-Host "Launching: $QemuExe $($qemuArgs -join ' ')"
Write-Host "Serial console: connect to tcp:127.0.0.1:$SerialPort once running (see vm/_watch-serial.py for a read-only viewer)"
& $QemuExe @qemuArgs
