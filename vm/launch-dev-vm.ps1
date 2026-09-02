<#
Launch script for the JAZZ dev/test VM (QEMU + WHPX on Windows).
See vm/README.md for the full story and the reasoning behind each choice below.

IMPORTANT — this boots via direct kernel boot + serial console, NOT the
graphical UEFI path the project originally planned. Confirmed via extensive
testing (2 Sept 2026, see docs/Research-Reference-List.md section 0):
WHPX cannot render an OVMF/UEFI graphical framebuffer on this host at all —
not just the documented pflash MMIO bug (QEMU GitLab #513), but GOP/VGA
rendering itself under WHPX. This was confirmed with a known-good, verified
monolithic OVMF build: firmware ran correctly (proven under -accel tcg,
which rendered the real UEFI boot-device menu with the exact same firmware),
but drew nothing at all under WHPX, in every device/machine-type combination
tried.

The workaround: QEMU's direct kernel boot (-kernel/-initrd/-append) loads
the archiso's own kernel and initramfs straight into guest memory and jumps
to it, using QEMU's built-in SeaBIOS rather than OVMF. No firmware boot menu
is ever rendered, so the broken WHPX graphics path is never exercised. Serial
console output (console=ttyS0) is captured directly as text over a TCP
socket - no framebuffer involved at any point.

Consequence to carry into later tasks: this boots the LIVE INSTALLER
environment via legacy BIOS, not UEFI - archinstall (Task 4/5) needs to be
checked/forced to still produce a UEFI-bootable TARGET system regardless,
since that's what SPEC.md requires for the final installed OS. Flagged in
tasks/todo.md's Task 4 entry - don't assume this is automatic.

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
    [int]$MonitorPort = 4444
)

$ErrorActionPreference = "Stop"
$VmDir = $PSScriptRoot
$QemuDir = "C:\Program Files\qemu"
$QemuExe = Join-Path $QemuDir "qemu-system-x86_64.exe"
$QemuImg = Join-Path $QemuDir "qemu-img.exe"
$BaseDisk = Join-Path $VmDir "arch-base.qcow2"
$Overlay = Join-Path $VmDir "arch-dev-overlay.qcow2"
$Iso = Join-Path $VmDir "archlinux-x86_64.iso"
$Kernel = Join-Path $VmDir "vmlinuz-linux"
$Initrd = Join-Path $VmDir "initramfs-linux.img"

if (-not (Test-Path $QemuExe)) {
    throw "qemu-system-x86_64.exe not found at $QemuExe - is QEMU installed? (see Task 2)"
}
foreach ($f in @($Iso, $Kernel, $Initrd)) {
    if (-not (Test-Path $f)) {
        throw "Required file not found: $f - see vm/README.md for how to obtain it"
    }
}

# Base disk: an empty canvas. Created once; the overlay is what actually gets written to.
if (-not (Test-Path $BaseDisk)) {
    Write-Host "Creating base disk (20G, empty, sparse) at $BaseDisk"
    & $QemuImg create -f qcow2 $BaseDisk 20G | Out-Null
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
    "-kernel", "$Kernel"
    "-initrd", "$Initrd"
    "-append", "archisobasedir=arch archisosearchuuid=$ArchIsoSearchUuid console=ttyS0,115200 console=tty0"
    "-drive", "file=$Overlay,if=virtio"
    "-cdrom", "$Iso"
    "-netdev", "user,id=n0"
    "-device", "virtio-net,netdev=n0"
    "-nographic"
    "-serial", "tcp:127.0.0.1:$SerialPort,server,nowait"
    "-monitor", "tcp:127.0.0.1:$MonitorPort,server,nowait"
)

Write-Host "Launching: $QemuExe $($qemuArgs -join ' ')"
Write-Host "Serial console: connect to tcp:127.0.0.1:$SerialPort once running (see vm/_watch-serial.py for a read-only viewer)"
& $QemuExe @qemuArgs
