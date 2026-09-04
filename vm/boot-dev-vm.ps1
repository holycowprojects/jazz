<#
Boots the already-installed JAZZ dev VM directly - no ISO, no archinstall
live environment. This is the recipe every task after Task 5/6 has actually
used to test the installed system, but it was never committed to the repo
before now (5 Sept 2026, Task 9) - every prior session hand-rolled this same
QEMU invocation ad hoc via direct tool calls, which is exactly the kind of
repeated, error-prone typing a real script should replace.

`launch-dev-vm.ps1` is a different script with a different job: it always
attaches the archiso (`-cdrom`) and boots via direct kernel/initrd, since
that's what the unattended `archinstall` run (Task 5/6) needs. This script
is for every task afterward, once the OS is actually installed on disk.

`-device virtio-gpu-pci` (added for Task 9): a real virtual display device,
needed for Hyprland to get genuine KMS/CRTC capabilities - Aquamarine 0.14.0
hard-requires DRM_CAP_CRTC_IN_VBLANK_EVENT even in headless mode, which the
`vgem` dummy-GPU approach (the officially documented Hyprland "no display
output" workaround) cannot provide - confirmed live via strace, not
assumed. Confirmed separately that this does NOT reintroduce the WHPX/OVMF
firmware graphics stall that `-vga none` exists to avoid (see
docs/Research-Reference-List.md section 0): `virtio-gpu-pci` is added only
as a runtime PCI device and never touches OVMF's own boot-time console
splitter the way a `-vga std/cirrus/qxl` device would - a full cold boot
with it attached reached `jazz login:` exactly as fast as without it.
#>

param(
    [int]$RamMB = 4096,
    [int]$Cpus = 4,
    [int]$SerialPort = 4445,
    [int]$MonitorPort = 4444,
    [string]$DiskName = "arch-dev-overlay.qcow2"
)

$ErrorActionPreference = "Stop"
$VmDir = $PSScriptRoot
$QemuDir = "C:\Program Files\qemu"
$QemuExe = Join-Path $QemuDir "qemu-system-x86_64.exe"
$Overlay = Join-Path $VmDir $DiskName
$Ovmf = Join-Path $VmDir "RELEASEX64_OVMF.fd"

if (-not (Test-Path $QemuExe)) {
    throw "qemu-system-x86_64.exe not found at $QemuExe - is QEMU installed? (see Task 2)"
}
if (-not (Test-Path $Overlay)) {
    throw "Disk not found: $Overlay - run launch-dev-vm.ps1 + the unattended install first (Task 5/6)"
}

$qemuArgs = @(
    "-accel", "whpx"
    "-m", "$RamMB"
    "-smp", "$Cpus"
    "-bios", "$Ovmf"
    "-drive", "file=$Overlay,if=virtio"
    "-device", "virtio-gpu-pci"
    "-netdev", "user,id=n0"
    "-device", "virtio-net,netdev=n0"
    "-vga", "none"
    "-nographic"
    "-serial", "tcp:127.0.0.1:$SerialPort,server,nowait"
    "-monitor", "tcp:127.0.0.1:$MonitorPort,server,nowait"
)

Write-Host "Booting installed disk: $Overlay"
Write-Host "Serial console: tcp:127.0.0.1:$SerialPort (see vm/README.md for viewer scripts)"
& $QemuExe @qemuArgs
