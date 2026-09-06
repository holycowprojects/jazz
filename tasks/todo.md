# Task List: JAZZ Phase 1

Companion to `tasks/plan.md`. Each task is sized S or M (per the planning skill's guidance, nothing here should run L+ — if a task turns out larger once started, split it rather than push through).

---

## Phase 0: Foundation

### Task 1: Repo scaffolding + Gitleaks
**Description:** Initialize the git repo at `jazz/`, create the directory structure SPEC.md defines, add a watertight `.gitignore` from the first commit, and install a Gitleaks pre-commit hook so no secret can enter history from commit #1 onward.

**Acceptance criteria:**
- [x] `git log` shows an initial commit
- [x] `docs/`, `tasks/`, `install/`, `scripts/`, `scripts/verify/`, `configs/`, `vm/` exist; the five existing docs are moved into `docs/`
- [x] `.gitignore` excludes `*.qcow2`, `*.iso`, venvs, model weights, secrets
- [x] `.pre-commit-config.yaml` runs the gitleaks hook and is installed as an active hook

**Verification:**
- [x] Manual check: a deliberately-staged fake secret (RSA private key block) was rejected by the pre-commit hook (exit code 1, commit blocked) before being removed; the real initial commit then passed cleanly
- [x] `git status` is clean after the initial commit

**Notes from execution (2 Sept 2026):** pre-commit (pip) and gitleaks (winget, `Gitleaks.Gitleaks`) were installed on the host after explicit go-ahead (SPEC.md "ask first" boundary). Both installers' bin dirs needed adding to the user PATH — noted here in case a fresh shell can't find `pre-commit`/`gitleaks`. First test used an invalid fake-AWS-key string (wrong length, silently didn't match gitleaks' rule) — not a hook failure, just a bad test string; corrected with a private-key block, which gitleaks caught immediately.

**Dependencies:** None

**Files likely touched:** `.gitignore`, `.pre-commit-config.yaml`, `docs/*` (moved), directory scaffolding

**Estimated scope:** S

---

### Task 2: QEMU installed, WHPX confirmed
**Description:** Install QEMU on the Windows host and confirm WHPX acceleration actually engages — this gates every VM task after it.

**Acceptance criteria:**
- [x] `qemu-system-x86_64 --version` succeeds — QEMU 11.1.0, installed via winget (`SoftwareFreedomConservancy.QEMU`)
- [x] A trivial boot with `-accel whpx` shows accelerated (not TCG-fallback) performance

**Verification:**
- [x] Manual check: a no-disk `-accel whpx`-only boot (no fallback accelerator available, so failure would be immediate and fatal) stayed running and printed host-CPUID-specific warnings (e.g. real SVM-bit feature check against actual host CPU). The identical command under `-accel tcg` produced zero such warnings — TCG has no real CPU to query. That asymmetry confirms WHPX is genuinely engaging hardware virtualization, not silently falling back to software emulation.

**Notes from execution (2 Sept 2026):** QEMU's installer put it in `C:\Program Files\qemu`, not on PATH by default — added to user PATH manually (per Task 1's pattern with pre-commit/gitleaks). Installed after explicit go-ahead per SPEC.md's "ask first" boundary on host installs.

**Dependencies:** None (independent of Task 1)

**Files likely touched:** none (host tooling only)

**Estimated scope:** XS

---

### Task 3: OVMF + launch script
**Description:** Source OVMF UEFI firmware and write the QEMU launch script, baking in the two confirmed fixes: `-bios OVMF_CODE.fd` (never the pflash drive syntax, which is broken under WHPX) and a qcow2 backing-file overlay workflow for fast resets between test runs.

**What actually shipped (differs from the original plan — see below):** extensive live testing found WHPX cannot render an OVMF/UEFI graphical framebuffer *at all* on this host, not just the documented pflash bug — confirmed with a hand-verified monolithic firmware build that rendered correctly under `-accel tcg` but drew nothing under WHPX in every configuration tried. The working fix is QEMU direct kernel boot (`-kernel`/`-initrd`/`-append`) via SeaBIOS with serial console output, which never touches firmware graphics at all. Full diagnostic trail in `docs/Research-Reference-List.md` section 0.

**Acceptance criteria:**
- [x] `vm/launch-dev-vm.ps1` exists, boots reliably under WHPX (revised: via direct kernel boot + serial console, not `-bios`/OVMF — see note above)
- [x] Script creates/uses a qcow2 overlay against a base image rather than booting the base directly
- [x] Networking uses `-netdev user` (documented limitation: no ICMP/ping to the guest — noted in the script's comments and `vm/README.md`)

**Verification:**
- [x] Running the script boots the Arch ISO installer environment to a shell prompt — confirmed via live serial session: logged in as root, ran `whoami && uname -a`, got `root` / `Linux archiso 7.2.2-arch1-1 ... x86_64 GNU/Linux`, then visually confirmed by the user watching the live console via `vm/watch-serial.py`

**Follow-up flagged for Task 4/5 (not resolved here — out of this task's scope):** the live installer environment now boots via legacy BIOS, not UEFI. SPEC.md requires the installed *target* system to be UEFI (systemd-boot). Must explicitly verify archinstall still produces a correct UEFI target (ESP partition, systemd-boot install) even though the live session itself has no `/sys/firmware/efi`.

**Dependencies:** Task 2

**Files likely touched:** `vm/launch-dev-vm.ps1`, `vm/README.md`, `vm/watch-serial.py`, `vm/serial-console.py`

**Estimated scope:** S (ran significantly over — extensive WHPX/OVMF diagnostic work was needed; see Research-Reference-List.md section 0 for why)

---

## Phase 1: Base system (Stage 1)

### Task 4: archinstall config generated
**Description:** Run archinstall interactively once, selecting the built-in Hyprland profile and a Btrfs subvolume layout (`@`, `@home`, `@snapshots`), then export the config via its "Save configuration" feature — never hand-author the JSON, per the confirmed finding that hand-edited configs crash `--silent` mode.

**Carried over from Task 3 — resolve here, don't skip:** the dev VM's live environment now boots via legacy BIOS (direct kernel boot, to work around a WHPX graphics bug — see `vm/README.md`), meaning `/sys/firmware/efi` won't exist in that live session. SPEC.md requires the *installed* system to be UEFI (systemd-boot). Explicitly check archinstall's disk/bootloader config to confirm it can still be told to produce a UEFI-bootable target (ESP partition + systemd-boot) regardless of the live environment's own boot mode — don't assume it "just follows" the live session's mode. If it can't, this needs a real solution (e.g. retrying the OVMF+direct-kernel-boot combination, which wasn't tested) before Task 5.

**Also carried over — interaction limitation:** `vm/serial-console.py` is line-buffered, not a raw terminal. archinstall's interactive TUI may not render correctly over it. Test this early in this task; if it doesn't work, the console client needs a raw-mode rewrite (noted in its own docstring) before proceeding.

**Done as of 3 Sept 2026:**
- Both Task 3 carried-over flags fully resolved:
  - **Raw-mode client** (`vm/serial-console-raw.py`) confirmed working end-to-end — drove the entire archinstall TUI (partitioning, menus, text fields) correctly over serial.
  - **UEFI blocker fixed and fully closed.** OVMF + `-accel whpx` + `-vga none` gives a genuinely UEFI live session. The previously-open piece — getting GRUB to actually boot with `console=ttyS0,115200` appended — is now also resolved: scripted Ctrl+X/F10 byte-injection never worked, but **a real human keypress (Ctrl+X) through `vm/serial-console-raw.py` worked on the first try.** Bootloader screen then showed `Systemd-boot` selected by default with no "UEFI not detected" warning, confirming the live session had a real `/sys/firmware/efi`.
  - **New gotcha found this session:** hot-adding a virtio disk to an already-running VM via the QEMU monitor (`drive_add` + `device_add virtio-blk-pci`) attaches at the QEMU level but the archiso kernel doesn't pick it up (archinstall still reports "No disks were detected"). Fix: always attach the disk at VM launch time (`-drive file=...,if=virtio`), never hot-add mid-session. Restarting the VM with the disk present from boot resolved it immediately.
- Manual partitioning redone on the new genuinely-UEFI VM (fast, ~2 minutes): `/dev/vda`, GPT, partition 1 = 1GiB FAT32 `/boot`, partition 2 = 19GiB Btrfs with subvolumes `@`→`/`, `@home`→`/home`, `@snapshots`→`/.snapshots`. Screenshots `SS-shots/14_ja.png` (partition table) and `SS-shots/ja_23.png` (bootloader confirmation).
- Full walkthrough completed: kernel `linux-lts` only (had to fix a `linux-ltsts` typo along the way — verified corrected), hostname `jazz`, user `holycowstudios` (sudo), Hyprland profile (`seat_access: seatd`, `ly` greeter, "All open-source" gfx driver), Pipewire audio, Bluetooth + print service + ufw firewall enabled, fonts (`noto-fonts`, `noto-fonts-emoji`, `ttf-dejavu`), `base-devel` + `git` added as extra packages (AI tooling deliberately deferred to the later idempotent script, per architecture decision), NetworkManager, Asia/Kolkata timezone, zstd zram swap.
- Exported via "Save configuration" → "Save all" → `/root` (credentials left unencrypted — throwaway VM, file is gitignored and never leaves the guest). Pulled `user_configuration.json` off the guest via `cat` over the serial line and saved to `install/base-profile.json` on the host.
- **Flag for Task 5:** the confirmed GRUB boot-trigger fix requires a *real keypress* — scripted/unattended boot of this same OVMF+`-vga none` path will hit the same Ctrl+X problem with no human there to press it. Task 5 will need the fallback discussed but not yet implemented: permanently bake `console=ttyS0,115200` into the ISO's own `grub.cfg` default entry (one-time mount-and-edit) so no runtime keystroke is needed at all.

**Acceptance criteria:**
- [x] `install/base-profile.json` (and credentials file, gitignored) exist, generated via export
- [x] Config specifies Btrfs subvolumes, the Hyprland desktop profile, target kernel 6.18 LTS (`linux-lts`)
- [x] Config produces a UEFI-bootable target (confirmed live: Bootloader screen defaulted to `Systemd-boot` with no UEFI warning)

**Verification:**
- [x] `python -m json.tool install/base-profile.json` confirms valid JSON

**Dependencies:** Task 3

**Files likely touched:** `install/base-profile.json`

**Estimated scope:** S

---

### Task 5: Unattended install boots to login
**Description:** The actual Stage 1 moment — run `archinstall --config install/base-profile.json --silent` against a fresh VM disk and confirm it reaches a working login prompt unattended.

**Done as of 4 Sept 2026 — and the Task 4 "will need a grub.cfg bake-in" plan turned out unnecessary:**
- **Key discovery: combine OVMF firmware with QEMU's direct kernel boot (`-kernel`/`-initrd`/`-append`), skipping GRUB entirely, instead of editing the ISO.** QEMU's fw_cfg kernel loader hands the kernel+initrd straight to OVMF, which jumps directly into it — no firmware boot menu, no GRUB, no human keypress needed. This sidesteps *both* open problems in one move: WHPX's broken OVMF graphics rendering (moot — no menu is ever drawn) and GRUB's un-scriptable raw serial input (moot — GRUB is never invoked). Confirmed directly: booted to `archiso login:` fully unattended, and `/sys/firmware/efi` was present (`config_table`, `efivars`, `fw_platform_size`, `runtime`, `runtime-map`, `systab` all there) — genuinely UEFI, verified over serial before trusting it. `vm/launch-dev-vm.ps1` updated to this combination (adds `-bios RELEASEX64_OVMF.fd` + `-vga none` to the existing direct-kernel-boot args); it no longer needs the legacy-BIOS caveat in its own docstring.
- **`install/base-profile.json` got one small, deliberate hand-edit** (the file's own `custom_commands: []` field, populated by archinstall itself, not authored from scratch): `sed -i 's/$/ console=ttyS0,115200/' /etc/kernel/cmdline` + `mkinitcpio -P`, so the *installed target* also gets a serial console baked into its UKI — needed since headless verification of the installed system has no other way to see output (no VGA device, no sshd enabled by default). This is the one exception to "never hand-author archinstall JSON" — a single-field, low-risk edit to a real schema field, not reconstructing the config.
- **`install/base-credentials.json` created** (gitignored, matches `install/*-credentials.json`) — the credentials export from Task 4 was never saved to the repo (only pulled via `cat` for the config), so this reconstructs it from the same schema (`!root-password`, `!users[].{username,!password,sudo}`) using the same values chosen in Task 4 (root `REDACTED-ROOT-PW`, user `holycowstudios`/`REDACTED-USER-PW`, sudo).
- **No shared filesystem trick used again:** both JSON files were pushed into the guest via a heredoc (`cat > /root/base-profile.json << 'JAZZEOF' ... JAZZEOF`) sent as raw bytes over the serial socket — same no-shared-filesystem constraint as Task 4, just scripted instead of human-typed since no interactive TUI was involved this time.
- **`archinstall --config /root/base-profile.json --creds /root/base-credentials.json --silent` ran fully unattended**, ~9 minutes (156 packages), and printed "Installation completed without any errors." Both custom commands executed successfully during the run.
- **Rebooted the VM booting from the installed disk only** (OVMF, no `-cdrom`, no `-kernel`/`-initrd` — letting UEFI's own boot manager find the ESP and boot systemd-boot for real, unlike the live-environment tests). systemd-boot's own countdown ("Boot in 2s... Boot in 1s...") rendered correctly over serial with no keypress needed — same `-vga none` trick that worked for GRUB in Task 4 apparently applies to systemd-boot too. Reached `jazz login:` unattended.
- **Verified via `scripts/verify/base-install.sh`** (new, pushed to guest and run over serial): 11/11 checks pass — `systemctl is-system-running` → `running`, hostname `jazz`, `/sys/firmware/efi` present on the *target* too, kernel `linux-lts`, all four Btrfs-related mountpoints (`/`, `/home`, `/.snapshots`, `/boot`) mounted, and `hyprland`/`base-devel`/`git` all installed. (One bug found and fixed along the way: minimal Arch has no `hostname` binary — the script uses `uname -n` instead.)
- Note for **Task 6**: since the OVMF+direct-kernel-boot combo is now the standard launch path, a second reproducibility install should be straightforward — same script, fresh overlay disk, same two JSON files.

**Acceptance criteria:**
- [x] Fresh qcow2 disk, unattended install completes without manual intervention
- [x] VM reboots into a login prompt

**Verification:**
- [x] `systemctl is-system-running` returns a healthy state after logging in
- [x] `scripts/verify/base-install.sh` created and passing

**Dependencies:** Task 4

**Files likely touched:** `scripts/verify/base-install.sh`

**Estimated scope:** M

---

### Task 6: Repeat install — reproducibility check
**Description:** Per the blueprint's own Stage 1 guidance ("install manually several times") and SPEC.md's success criterion #1, run the exact same unattended install a second time from a fresh disk and confirm it's reproducible.

**Done as of 4 Sept 2026:**
- `vm/launch-dev-vm.ps1` got a small addition to support this: a `-DiskName` param (default unchanged) so a second install can run against an independent overlay (`arch-dev-overlay2.qcow2`) without touching Task 5's disk — needed to keep both installs around long enough to diff them.
- Second install: `.\vm\launch-dev-vm.ps1 -DiskName arch-dev-overlay2.qcow2 -Fresh`, then the same `vm/run-unattended-install.py` pushed the *same* `install/base-profile.json` + `install/base-credentials.json` and ran `archinstall --silent` unattended again — "Installation completed without any errors," ~8m56s (nearly identical to Task 5's ~9min).
- Rebooted from the second disk only (same OVMF, no ISO/kernel args pattern as Task 5) — reached `jazz login:` unattended, no keypress needed, consistent with Task 5.
- `scripts/verify/base-install.sh` pushed and run on the second install: 11/11 checks pass, same as Task 5.
- **Package-list spot-check exceeded expectations: `pacman -Q` output was byte-for-byte identical between the two installs** — 623 packages, same versions, zero diff. Captured via the same "boot disk-only, log in, dump to a file, cat it back over serial" pattern used throughout; compared with a plain `diff` on the host after stripping terminal escape codes.
- Found and fixed one script bug along the way: `vm/run-unattended-install.py`'s "wait for the install to finish" loop was matching the shell's own echo of the *typed* command (which contains the literal, unexpanded marker text) instead of the real post-completion output — fixed by draining the echo first and only searching newly-arrived data afterward. (Caught immediately in Task 5 too, but only fixed once, before this task's run — see the file's own comments.)
- Debug artifacts (raw pkglists, install logs, boot captures) were written to `vm/` during this task and deleted afterward once the finding was recorded here — not meant to be tracked in the repo.

**Acceptance criteria:**
- [x] Second install, from the same config, on a fresh disk, also reaches a working login prompt

**Verification:**
- [x] `scripts/verify/base-install.sh` passes on both installs
- [x] No unintended differences between the two (spot-check package list/versions) — went further than a spot-check: full `pacman -Q` diff, zero differences

**Dependencies:** Task 5

**Files likely touched:** none new

**Estimated scope:** S

---

## Checkpoint: Foundation
- [x] `git log` shows commits; Gitleaks hook demonstrably active
- [x] VM boots via the launch script with confirmed WHPX acceleration
- [x] Two independent installs from the same config both reach login unattended
- [ ] **Review with Akash before proceeding to Phase 2** — not checked by design; this needs Akash's own sign-off, not an automated pass

---

## Phase 2, Track A: Filesystem/recovery

### Task 7: Snapper + snap-pac configured
**Description:** Confirm the Btrfs subvolume layout from archinstall, install and configure Snapper with `snap-pac` so every pacman transaction auto-snapshots.

**Done as of 4 Sept 2026:**
- `scripts/setup-snapper.sh` installs `snapper`+`snap-pac`, then does the standard reconciliation dance for a pre-existing `@snapshots` subvolume (archinstall already created and mounted one at `/.snapshots`, which conflicts with `snapper create-config`'s own default behavior): unmount, let Snapper create its own placeholder, discard that placeholder, remount the real subvolume in its place. Idempotent — checks for an existing `root` config first and skips the dance on re-run.
- Ran against the Task 5 disk (`arch-dev-overlay.qcow2`, now the ongoing dev VM going forward) over serial: `pacman -Sy snapper snap-pac` succeeded, the reconciliation ran cleanly, `snapper list-configs` showed the `root` config pointing at `/`.
- **First verify attempt caught two real bugs in `scripts/verify/snapper.sh` itself, not in the setup**: (1) `snapper list`'s table uses the Unicode box-drawing `│` character, not an ASCII `|` — the verify script's grep pattern silently matched zero rows regardless of how many snapshots existed. (2) using `--needed` in the test `pacman -S` meant a second run (package already installed) triggered no transaction at all, a false-negative trap. Diagnosed directly on the guest (not guessed): `snapper list` on its own showed real pre/post snapshot pairs tied to the `pacman -S ... tree` transaction, proving snap-pac was working correctly the whole time — confirmed via `pacman -Ql snap-pac` and its three hook files under `/usr/share/libalpm/hooks/`. Fixed both: match `^[0-9]+ ` instead of relying on the separator character, and remove-then-install the test package so re-runs always produce a real transaction.
- Re-ran the fixed verify script: both checks pass (`5 -> 7` snapshots across the remove+install round trip).

**Acceptance criteria:**
- [x] `snapper list` shows a snapshot configuration
- [x] A `pacman -S` (any small package) triggers a new automatic snapshot

**Verification:**
- [x] `scripts/verify/snapper.sh` created and passing

**Dependencies:** Task 5

**Files likely touched:** `scripts/setup-snapper.sh`, `scripts/verify/snapper.sh`

**Estimated scope:** S

---

### Task 8: Rollback tested
**Description:** Make a deliberate, clearly-breaking change, then roll back via Snapper and confirm the system is restored.

**Done as of 4 Sept 2026 — found two real bugs, both worth knowing before anyone relies on this:**
- Took an explicit pre-break snapshot (`snapper create --description pre-break-task8`, #7), then broke three independent things: `/etc/hostname` → `BROKEN`, removed the `git` package, and dropped a canary file. Confirmed all three took effect.
- **`snapper rollback 7` failed outright**: "Cannot detect ambit since default subvolume is unknown." Root cause: archinstall's fstab mounts root by a fixed subvolume *path* (`subvol=/@`, confirmed by reading `/etc/fstab` directly), not via btrfs's "default subvolume" mechanism — which is what `snapper rollback`'s automatic ambit-detection depends on. The error message's own suggested fix (`--ambit` option) doesn't even exist as a flag on this snapper version (0.13.1) — tried it, got "Unknown option '--ambit'". **This is a real gap in what Task 7 set up, not a fluke** — automatic rollback simply does not work on archinstall's default Btrfs+systemd-boot layout without extra tooling (e.g. `grub-btrfs`, which needs GRUB, not systemd-boot).
- **Built and used the standard manual-recovery procedure instead**, now codified as `scripts/rollback-manual.sh <snapshot-number>`: mount the btrfs top-level (`subvolid=5`), rename the current `@` out of the way, create a new writable `@` as a snapshot of the target restore point, unmount. Confirmed live-renaming a subvolume that is *currently mounted as root* is safe (the kernel's mount reference is by subvolume ID, not by name/path) — no need to boot into a rescue environment. Works cleanly with zero fstab edits specifically *because* fstab uses `subvol=/@` (name-based), not `subvolid=` (ID-based) — confirmed this before relying on it, not assumed.
- **Second, unrelated bug found along the way: warm reboot crashes OVMF.** Running `reboot` *inside* the guest (as opposed to killing and relaunching the QEMU process, which is how every prior "reboot" in this project actually happened) triggered `!!!! X64 Exception Type - 0E(#PF - Page Fault` during the ACPI reset and hung the guest — a new WHPX/OVMF issue, distinct from the already-documented graphics-rendering bug. The filesystem had already unmounted cleanly before the crash (confirmed from the shutdown log), so no data was at risk, but the QEMU process itself needed a hard `Stop-Process -Force` + fresh relaunch to recover. **Documented directly in `scripts/rollback-manual.sh`'s own comments and `docs/Research-Reference-List.md`: never trust in-guest `reboot` on this host — always cold-boot externally.**
- Post-recovery (via a fresh cold boot): hostname back to `jazz`, `git` reinstalled, canary file gone, `systemctl is-system-running` → `running`, and `findmnt /` confirmed root now resolves to the restored subvolume's new ID. Cleaned up the orphaned broken subvolume afterward (`btrfs subvolume delete`, including its two nested `var/lib/{portables,machines}` subvolumes).

**Acceptance criteria:**
- [x] A deliberately broken state (e.g. a corrupted config) is fully reverted after `snapper rollback` (or equivalent — see finding above: automatic `snapper rollback` doesn't work on this layout, `scripts/rollback-manual.sh` is the real mechanism) and a reboot

**Verification:**
- [x] System boots cleanly post-rollback; the deliberate breakage is gone

**Dependencies:** Task 7

**Files likely touched:** `scripts/rollback-manual.sh` (new — not anticipated when this task was scoped, but necessary once `snapper rollback` was confirmed broken)

**Estimated scope:** S

---

## Phase 2, Track B: Desktop

**Read `Design-Vision.md` before starting any task in this track** — it records the agreed workspace colors, the native-Hyprland-vs-Quickshell animation split, dashboard scope, and accessibility commitments, so this track builds toward what was actually agreed rather than re-deriving it from memory.

### Task 9: Hyprland reaches a working desktop
**Description:** Confirm the Hyprland desktop provisioned by archinstall's profile actually launches and is usable inside the VM.

**Done as of 5 Sept 2026 — real, working session, after one hard dead end:**
- **Plan A (documented approach) failed for a real, precise reason, not a misconfiguration.** Hyprland's own wiki documents `AQ_NO_KMS_REQUIREMENT=1` for running on a GPU with no display output — exactly the `vgem` dummy-card CI pattern. Confirmed via `strace -v` that Aquamarine 0.14.0 hard-requires `DRM_CAP_CRTC_IN_VBLANK_EVENT`, which `vgem` (a pure dumb-buffer driver, no real CRTC) can never support — `CBackend::create() failed!` every time, immediately, regardless of any documented env var.
- **Plan B: a real `virtio-gpu-pci` device**, added at QEMU launch (not hotplug — QEMU flatly refuses to hotplug display devices, confirmed directly: `Error: Device 'virtio-gpu-pci' does not support hotplugging`). Tested live whether this reintroduces the known WHPX/OVMF firmware graphics stall (`-vga none` exists specifically to avoid it) — it does not; a full cold boot with it attached reached `jazz login:` exactly as fast as without it.
- Real session achieved after fixing three further real bugs, each found live: (1) the target user needs `video` group membership (`card0` is `root:video`, Mesa's EGL/DRI2 open of it isn't seatd-mediated); (2) `seatd-launch` conflicts with the system's own already-running `seatd.service` and shouldn't be used — the system service handles DRM master correctly on its own; (3) `foot`'s shell inherits Hyprland's own cwd to `chdir()` into, and `holycowstudios` can't enter `/root` — fixed by launching Hyprland with a sane cwd.
- Confirmed live via `hyprctl monitors`: a genuine display (`Virtual-1`, `1280x800@74.99400`, `description: Red Hat Inc. QEMU Monitor`), rendered via Mesa's `kms_swrast` software path (no virgl, as expected) — not a headless dummy.
- **New finding: Hyprland 0.56.2 moved its config to Lua** (`hyprland.lua`, not `hyprland.conf`), and `hyprctl dispatch`'s syntax changed to match (`hl.dsp.<category>.<action>({...})`, not the old space-separated `dispatch exec <cmd>`) — confirmed against the real `dispatchers.md` wiki source (fetched via `gh api`), not guessed.
- `vm/boot-dev-vm.ps1` (new) is now the standard way to boot the installed system directly (previously always hand-rolled ad hoc, never committed) — includes `-device virtio-gpu-pci`. `scripts/setup-hyprland.sh` (new) adds the `video` group + seeds a deliberately minimal `hyprland.lua` scaffold (stdout logging left on for diagnosability; the real config is Tasks 10/11's job). `scripts/verify/hyprland.sh` (new) launches a real session, opens `foot`, and confirms real window management (tiled by default, then floated + moved to an exact position) via `hyprctl clients`.
- Confirmed clean end-to-end with the actual committed scripts on a fresh boot (not just the exploratory session): `install-jazz.sh holycowstudios` → `verify-hyprland.sh holycowstudios` → `3 passed, 0 failed`. Along the way this also caught and fixed a real idempotency bug in the already-committed `setup-aider.sh` (`uv venv` errors if the venv already exists, unlike `pip`'s natural idempotency) — exposed only because this was a genuine second run on the same disk.

**Acceptance criteria:**
- [x] Graphical login reaches a working Hyprland session
- [x] Basic window management (open a terminal, move/tile it) works

**Verification:**
- [x] `hyprctl version` succeeds; `scripts/verify/hyprland.sh` created and passing (3/3)

**Dependencies:** Task 5

**Files likely touched:** `scripts/verify/hyprland.sh`, `scripts/setup-hyprland.sh` (new, not anticipated when this task was scoped), `vm/boot-dev-vm.ps1` (new — the installed-system boot recipe had never been committed before this task), `scripts/install-jazz.sh` (chained in), `scripts/setup-aider.sh` (idempotency fix)

**Estimated scope:** S (revised: M — the vgem dead end and seatd/permissions debugging turned out heavier than expected)

---

### Task 10: Quickshell running with one custom widget
**Description:** Install Quickshell and build one small widget (clock or workspace indicator) from its Getting Started guide, per the research addendum's own recommended first step — not the full AI Command Centre yet.

**Done as of 5 Sept 2026 — real autostart, two real bugs found and fixed live:**
- Quickshell 0.3.1 confirmed official-repo (`extra/quickshell`) before touching the VM — no AUR needed. Its real QML API was confirmed directly from the installed `.qmltypes` files on the VM (`/usr/lib/qt6/qml/Quickshell/**/*.qmltypes`), not guessed from a blog post: `import Quickshell` gets `PanelWindow` (re-exported via `Quickshell._Window`'s `default import`) and `SystemClock` (`Quickshell/SystemClock`), with every property name (`anchors`, `implicitHeight`, `color`, `precision`, `date`, etc.) read straight from the type metadata.
- The widget: a live clock in a top `PanelWindow` bar, bound to `SystemClock.date` via `Qt.formatTime` — `configs/quickshell/shell.qml`-equivalent content lives inline in `scripts/setup-quickshell.sh` (matching the pattern already set by `setup-hyprland.sh`'s `hyprland.lua`, not a separately-tracked config file).
- **Bug 1: Qt crashed on the `xcb` platform plugin** ("could not connect to display") when Quickshell was launched via a manually-reconstructed `sudo -u` environment — `WAYLAND_DISPLAY` is not automatically inherited just by matching `XDG_RUNTIME_DIR`/the Hyprland instance signature, confirmed live via the actual crash log, not assumed.
- **Bug 2: Qt Quick's own OpenGL/EGL scenegraph renderer failed** ("MESA-EGL: failed to create dri2 screen") even once Wayland connected correctly — this VM's virtio-gpu-pci device only supports Mesa's software rasterizer (kms_swrast), the same constraint Task 9 already found for Aquamarine itself. Fixed with `QT_QUICK_BACKEND=software`, Qt's own documented pure-software scenegraph renderer — confirmed live this bypasses EGL/DRI2 entirely and Quickshell stays running with "Configuration Loaded" and no crash.
- **Real fix architecture, not a test-harness hack:** both env vars are set via `hl.env(...)` inside `hyprland.lua` (confirmed via `gh api` fetch of the real `environment-variables.md`/`autostart.md` wiki source — `hl.env()` sets vars *before the display server initializes*, so anything `hl.exec_cmd()`'d afterward inherits them correctly), and Quickshell is started the real way Hyprland is meant to autostart anything: `hl.on("hyprland.start", function() hl.exec_cmd("quickshell") end)` — not a manual `sudo -u ... env ...` wrapper. `scripts/setup-quickshell.sh` appends this block to the existing `hyprland.lua` idempotently (checks for `exec_cmd("quickshell")` before appending).
- **Verification bug also found and fixed:** `PanelWindow` uses the wlr-layer-shell protocol (bars/panels), so `hyprctl clients` (regular toplevel windows) never shows it — confirmed live, switched the verify script to `hyprctl layers`, which showed a real, visible surface: `Layer ...: xywh: 0 0 1280 32, a: 1, namespace: quickshell, pid: ...`. (`quickshell list` itself had its own separate detection quirk not chased down further, since `hyprctl layers` is stronger, more direct evidence.)
- Final end-to-end test used **zero manual Quickshell invocation** — booted the VM, ran `setup-hyprland.sh` + `setup-quickshell.sh`, launched only Hyprland, and confirmed Quickshell auto-started purely via its own `hl.on("hyprland.start", ...)` hook: `2 passed, 0 failed`.
- Chained `setup-quickshell.sh` into `install-jazz.sh` right after `setup-hyprland.sh`.

**Acceptance criteria:**
- [x] Quickshell process running under Hyprland
- [x] One custom QML widget renders and updates live

**Verification:**
- [x] `scripts/verify/quickshell.sh` confirms the process is running (via real autostart, not manual launch) and the widget is a real, visible layer-shell surface (`hyprctl layers`)

**Dependencies:** Task 9

**Files likely touched:** `scripts/setup-quickshell.sh` (installs quickshell, writes `shell.qml`, wires Hyprland autostart), `scripts/verify/quickshell.sh`, `scripts/install-jazz.sh`

**Estimated scope:** M (matched — the two real Qt/Wayland env bugs were the expected kind of risk, not a surprise dead end like Task 9's vgem gap)

---

### Task 11: `Theme.qml` singleton + one functional-animation proof
**Description:** Build the lightweight `Theme.qml` singleton (named state tokens, `Behavior`/`ColorAnimation`/`Transition` primitives) recommended by the design research, and wire one real functional-animation behavior end to end — a window-class-matched border color rule — as proof the pattern works before building the rest of the animation vision.

**Done as of 5 Sept 2026 — one real config bug caught by an actual screenshot, not just text checks:**
- `Theme.qml` (`~/.config/quickshell/Theme.qml`) is a real QML singleton (`pragma Singleton`), registered via a local `qmldir` (`singleton Theme 1.0 Theme.qml`), exposing the 6 named workspace color tokens already agreed in Design-Vision.md sec 2 and used in the approved desktop-simulation mockup — not arbitrary placeholders. `shell.qml` (Task 10's clock widget) was rewritten to bind its panel color to `Theme.forge` instead of a hardcoded hex, proving the singleton is actually consumed, not just present.
- The border-color rule lives in `hyprland.lua`, a separate system from Theme.qml (Hyprland's Lua config and Quickshell's QML runtime don't share variables — the rule's hex matches `Theme.forge` by convention, not a live binding).
- **Real bug, caught by a real screenshot:** the first `hl.window_rule({ match = {...}, effect = { border_color = ... } })` shape (following the wiki's generic syntax block too literally) made Hyprland reject the whole config and drop into emergency mode (`hl.window_rule: unknown field 'effect'`) — invisible to the text-only verify checks, which only grepped for the strings `hl.window_rule`/`border_color` being present, not that the config actually parsed. Caught only because a `grim` screenshot was pulled off the guest (via base64-over-serial, no shared filesystem) and actually looked at, showing Hyprland's own emergency-mode error overlay. Fixed by finding real `hl.window_rule` call examples elsewhere in the wiki source (`code-snippets.md`) rather than trusting the generic syntax block alone: `border_color` is a direct sibling key of `match`, not nested under an `effect` field.
- **Both halves of the acceptance criteria confirmed with real screenshots, not inferred:** one screenshot showed the clock bar in Theme.forge's slate blue and a `foot` window with a matching blue border; a second showed the *same* window (confirmed via unchanged pid) with an amber border after editing `hyprland.lua`'s `border_color` value and running `hyprctl reload` — live-reevaluating, no restart of Hyprland or the window itself.
- `grim` (also a planned Tier 2 screenshot-widget dependency from the widget backlog) installed for this — already present on this VM as an existing dependency, confirmed live.

**Acceptance criteria:**
- [x] `Theme.qml` exists with at least one named color token
- [x] A test window matching a specific class shows the rule-driven border color, confirmed live-updating via Hyprland's `windowrule` syntax

**Verification:**
- [x] Manual visual check — done via real `grim` screenshots pulled off the guest and viewed directly, not just automated text checks. `scripts/verify/theme.sh` also confirms 6/6: the config files are correct, and nothing already working (Quickshell, a real window opening) broke.

**Dependencies:** Task 10

**Files likely touched:** `scripts/setup-theme.sh` (writes `Theme.qml`/`qmldir`, rewrites `shell.qml` to use `Theme.forge`, appends the `border_color` windowrule to `hyprland.lua`), `scripts/verify/theme.sh`, `scripts/install-jazz.sh`

**Estimated scope:** M (matched)

---

### Task 11b: Tier 1 widget set (World clock, Notes, To-do, Pomodoro)
**Description:** The first batch broken out of the Design-Vision.md §6 widget backlog, now that Task 10/11 proved Quickshell+Theme.qml works end to end. Tier 1 = "pure local, no external dependency" per that doc's own tiering. Not part of the original 20-task plan; added ad hoc, tracked here after the fact, same as Task 15b/15c.

**Done as of 5 Sept 2026:**
- A second `PanelWindow` (bottom-right, floating, `exclusiveZone: -1`, persistent across every workspace per Design-Vision.md §6's own framing — not tied to any one workspace's identity color) holds all four widgets in one `Column`.
- **World clock**: computed via plain UTC-offset arithmetic on the local `SystemClock` (Asia/Kolkata, per Task 4's `base-profile.json`) rather than relying on Qt's ICU/timezone-database support (not a confirmed dependency of this install). Confirmed correct live via screenshot: Goa 18:19 → UTC 12:49 (−5:30) → SF 05:49 (−7:00 from UTC) — exact.
- **Notes / To-do**: real disk persistence via Quickshell's `Quickshell.Io` `FileView` component — its actual API (`path`, `.text()`, `.setText()`, `onLoaded`/`onLoadFailed`) was confirmed by reading the installed `.qmltypes` source directly, not guessed. To-do uses a hand-rolled `ListModel` + `Repeater` with a simple `"0|label"`/`"1|label"` line format (no JSON adapter needed). Checkboxes/buttons are hand-rolled `Rectangle`+`MouseArea` — `QtQuick.Controls` isn't a confirmed dependency of this install, so avoided rather than assumed present.
- **Pomodoro**: a plain QML `Timer`, no extra dependency.
- `Theme.qml` extended with a neutral `panel`/`panelInk` token pair (the workspace tokens don't fit a cross-workspace persistent panel) — still the same singleton, still genuinely consumed.
- **Real bug caught by a real screenshot (again):** the panel's first `implicitHeight: 260` clipped the Pomodoro row off the bottom edge — invisible to any structural/text check, only visible in the actual rendered screenshot. Fixed by bumping to `320`. This is the second task in a row where a visual check caught something a passing text-based verify would have missed entirely — worth treating "look at a real screenshot" as a standard step for any future widget work, not just theme/animation tasks.
- **Real infra bug found and fixed along the way (Claude's own tooling, not the OS):** the `grim`-screenshot-pull helper script itself had a subtle bug — its stop condition matched the *echoed* command text (the classic echoed-input-line trap this project has hit before), and separately, passing `/tmp/...` paths as Bash command-line arguments to `python.exe` got silently mangled into Windows paths by Git Bash's automatic path conversion. Both fixed (wait for a genuine quiet period + take the largest regex match; hardcode remote paths inside the script instead of passing them as args).

**Acceptance criteria:**
- [x] All four widgets render in a real Quickshell session (confirmed via `grim` screenshots, not just hyprctl text)
- [x] World clock's computed offsets are correct against real Goa/UTC/SF time
- [x] Notes/To-do use genuine `FileView`-based persistence, not in-memory-only state
- [x] Adding the widget panel doesn't break Quickshell's existing autostart/rendering (Task 10) or Theme.qml usage (Task 11)

**Verification:**
- [x] `scripts/verify/widgets-tier1.sh`: 9/9 (structural checks + both PanelWindows registering as real layer-shell surfaces)

**Dependencies:** Task 11

**Files likely touched:** `scripts/setup-widgets-tier1.sh` (extends `Theme.qml`, rewrites `shell.qml` to add the widget panel), `scripts/verify/widgets-tier1.sh`, `scripts/install-jazz.sh`

**Estimated scope:** M

---

## Phase 2, Track C: AI engineering

### Task 12: Rootless Podman working
**Description:** Set up rootless Podman on the base system.

**Done as of 4 Sept 2026 — clean pass, no bugs hit this time:**
- `scripts/setup-podman.sh <username>` installs `podman`, `slirp4netns` (rootless networking), and `fuse-overlayfs` (rootless storage), then confirms/fixes `/etc/subuid`+`/etc/subgid` delegation for the target user and enables `loginctl enable-linger` (so the user's systemd instance runs even outside an interactive login, needed for cgroups v2 delegation). Idempotent — skips the subuid/subgid step if already present.
- **Confirmed (not assumed): archinstall's own user creation does NOT auto-populate `/etc/subuid`/`/etc/subgid`** — the script's `usermod --add-subuids/--add-subgids` step actually ran and was needed; without it rootless Podman would have nothing to map container UIDs into.
- Ran against `holycowstudios` (the real sudo user from Task 4, not root — testing rootless from an actual non-root account is the meaningful test).
- `scripts/verify/podman.sh` checks two things, not just config presence (matching the lesson from Task 7's bugs — verify real behavior): `podman info` succeeding as the non-root user, and an actual container (`docker.io/library/alpine:latest echo rootless-container-ok`) running rootless and producing the expected output. Both passed on the first run.

**Acceptance criteria:**
- [x] `podman info` succeeds without root

**Verification:**
- [x] `scripts/verify/podman.sh` created and passing

**Dependencies:** Task 5

**Files likely touched:** `scripts/setup-podman.sh`, `scripts/verify/podman.sh`

**Estimated scope:** S

---

### Task 13: Reproducible PyTorch + JupyterLab container, CPU-validated
**Description:** Build one reproducible container (pinned PyTorch version, lockfile) with JupyterLab, and confirm CPU-backed PyTorch operation inside it. This exact container definition is what Task 16 later validates against a rented GPU — build it carefully.

**Done as of 4 Sept 2026:**
- Researched first (per user request): confirmed via PyPI metadata that plain `pip install torch==2.14.0` on Linux already pulls the CUDA-enabled build (depends on `cuda-toolkit==13.0.3`, `nvidia-cudnn-cu13`, etc.) — no special `--index-url` needed. This is what makes "the same container works CPU-only today and GPU later, unmodified" possible. JupyterLab pinned at 4.6.3 (current stable, checked via PyPI).
- `configs/containers/ai-core/Containerfile` + `requirements.txt` (the lockfile) and `scripts/verify/ai-core.sh` written and committed.
- **First build attempt failed on disk space, not a build bug**: `pip install` fully succeeded inside the container, but podman's layer-commit step hit `no space left on device` — the base install's ~19GiB Btrfs partition only had ~9.2GiB free, not enough for torch + the full CUDA 13 toolkit unpacked. Full diagnosis and fix in `docs/Research-Reference-List.md` section 0 (4 Sept 2026 entry) — grew the dev VM's disk live via `qemu-img resize` + `sgdisk -e` + `growpart` + `btrfs filesystem resize max` (parted got stuck on two separate interactive prompts that `-s` didn't suppress; growpart went through cleanly). Disk is now 79GB/70GB free on `arch-dev-overlay.qcow2`.
- **Second failure, a real (if minor) bug, not disk space**: with more disk, the build succeeded but the PyTorch check failed — `torch` emits a `UserWarning: Failed to initialize NumPy: No module named 'numpy'` because `numpy` was never actually pinned in `requirements.txt` (torch treats it as optional), and the verify script's `torch_out=$(... 2>&1)` folded that stderr warning into the same string it strict-compared against `"0.0"`, so a functionally-correct run showed as FAIL. Fixed two things: added `numpy` to `requirements.txt` (a real missing dependency for an AI/Jupyter container, not just to silence a warning), and changed the verify script to redirect stderr to a separate file (`/tmp/ai-core-torch-stderr.log`) so it can never corrupt the stdout comparison again.
- **Third failure, a real version-compatibility bug**: pinning `numpy==2.5.2` (latest) produced a *different* error — `ImportError: cannot load module more than once per process` when torch imports numpy internally. Researched via web search rather than guessing: numpy 2.4+ added a stricter guard against its C extension (`_multiarray_umath`) being loaded twice in the same process, and torch 2.14.0's internal numpy interop path trips that guard. Fixed by pinning `numpy==2.3.5` (the last 2.3.x release, confirmed via PyPI, predating the 2.4+ guard) instead.
- **Fourth attempt hit a transient `pip` network timeout** (`ReadTimeoutError` from `files.pythonhosted.org`) — not a bug, just flaky download; a plain retry with no file changes built cleanly.
- **Final clean run: all 3 checks pass** — container builds, `torch.zeros(3).sum() == 0.0` on CPU, JupyterLab reachable on port 8888. VM stopped after confirming.
- **Known follow-up, not yet done:** `vm/launch-dev-vm.ps1`'s base-disk size was bumped 20G→80G for future fresh disks, but `install/base-profile.json`'s own `disk_config` still hardcodes the old ~19GiB partition size — a fresh archinstall run (Task 6-style, or anyone cloning the repo) will still only get ~19GiB until that's addressed too. Worth fixing before Task 6 is ever re-run, or before a stranger tries to reproduce the build from the repo alone (SPEC.md criterion #1).

**Acceptance criteria:**
- [x] Container builds from a pinned Containerfile/lockfile
- [x] Inside the container: `import torch; torch.zeros(3).sum()` runs successfully on CPU
- [x] JupyterLab starts and is reachable

**Verification:**
- [x] `scripts/verify/ai-core.sh` created and passing

**Dependencies:** Task 12

**Files likely touched:** `configs/containers/ai-core/Containerfile`, lockfile, `scripts/verify/ai-core.sh`

**Estimated scope:** M

---

### Task 14: Ollama installed, CPU inference confirmed
**Description:** Install Ollama, pull one small model, confirm a CPU inference request returns output.

**Done as of 4 Sept 2026:** `scripts/setup-ollama.sh` installs the official `ollama` Arch package, enables its systemd service, and pulls `qwen2.5:0.5b` (small, fast to verify on CPU). Ran on the same dev VM as Tracks A/C. `scripts/verify/ollama.sh` checks structurally (a completed, non-empty response via the `/api/generate` endpoint) rather than pinning to exact wording, since a 0.5B model won't reliably follow "say exactly X" instructions and asserting content would make the check flaky for the wrong reason. Clean pass, 2/2, no bugs found — the most boring task in the project so far, as expected (this is a well-trodden, official-repo install path, unlike Task 13's pip/PyPI saga).

**Acceptance criteria:**
- [x] `ollama list` shows a pulled model
- [x] A prompt via `ollama run` (or the API) returns a real response

**Verification:**
- [x] `scripts/verify/ollama.sh` created and passing

**Dependencies:** Task 5 (does not depend on Podman track)

**Files likely touched:** `scripts/setup-ollama.sh`, `scripts/verify/ollama.sh`

**Estimated scope:** S

---

### Task 15: PyRIT probe run
**Description:** ~~Install Garak and PyRIT~~ Install PyRIT (Akash's explicit preference over Garak), run one probe against the local Ollama model, and confirm a report is produced. PyRIT installed via `scripts/setup-pyrit.sh` as a standard part of the OS build (same tier as `setup-ollama.sh`/`setup-podman.sh`), not a one-off manual step.

**Done as of 5 Sept 2026:**
- Researched PyRIT's real current API live rather than guessing (its API has changed significantly from what older blog posts/training data describe — no `PromptSendingOrchestrator` import path anymore). Downloaded the exact pinned `pyrit==1.0.1` wheel and inspected its actual source to confirm: it ships a `pyrit_scan` CLI (client/server — a local `pyrit_backend` FastAPI server), a native Ollama-compatible target (`OpenAIChatTarget` registered as `"ollama"` from `OLLAMA_CHAT_ENDPOINT`/`OLLAMA_MODEL` env vars — Ollama's OpenAI-compatible API), and a built-in `airt.jailbreak` scenario (HarmBench objectives × jailbreak templates, auto-scored for refusal) — exactly the "DAN-style jailbreak" probe the original task envisioned, no custom orchestration code needed.
- `scripts/setup-pyrit.sh` and `scripts/verify/pyrit.sh` written and committed. Setup: `python`+`python-pip` via pacman (VM had no Python before this), dedicated venv at `/opt/jazz-pyrit/venv` (PyRIT is pip-only, Arch's system Python is PEP-668 externally-managed), `pyrit==1.0.1` + pinned `numpy==2.3.5`, CLI symlinked to `/usr/local/bin`.
- **Real bug found and fixed**: a bare `pip install pyrit==1.0.1` pulls numpy 2.5.2 (latest) as a transitive dependency, which crashes on import — `NumPy was built with baseline optimizations (X86_V2) but your machine doesn't support (X86_V2)`. QEMU's default WHPX virtual CPU (no explicit `-cpu` flag passed) doesn't expose the SIMD baseline numpy 2.5.2's wheel assumes. Fixed by pinning `numpy==2.3.5` in the same install command — the same version already proven to work on this VM from Task 13 (a different numpy issue there, same fix). Confirmed via live diagnosis (crash traceback captured from `/tmp/pyrit_backend.log`), not assumed.
- **Real friction found, not a bug but had to be discovered live**: `pyrit_scan`'s backend unconditionally validates a "default objective target" (`OPENAI_CHAT_*` env vars) even when the run only asks for the differently-named `ollama` target — every command 400s with "Environment variable OPENAI_CHAT_KEY is required" otherwise. Worked around by also setting `OPENAI_CHAT_ENDPOINT`/`OPENAI_CHAT_MODEL`/`OPENAI_CHAT_KEY=not-needed` pointed at the same Ollama endpoint — both targets register, only `ollama` is actually used.
- First scenario run attempt succeeded server-side but was cut off by a too-short (300s) polling timeout on the orchestration side before the CLI could finish printing/writing its report — not a script bug, just a timeout tuned too tight for a 0.5B CPU model doing 3 scored attacks (~2-4 min each).
- **Resumed and confirmed passing 5 Sept 2026**: rebooted the VM, logged in (root/`REDACTED-ROOT-PW` — see `install/base-credentials.json`, gitignored), launched `verify-pyrit.sh` as a detached background process in the guest, and polled every 90s for up to 26 minutes without touching the process. It finished in ~5 minutes this run (backend/model already warm from the prior attempt). Final output: `PASS: pyrit importable, version 1.0.1` / `PASS: airt.jailbreak probe ran against the local Ollama model and produced a report (/root/pyrit-jailbreak-report.txt)` / `2 passed, 0 failed`. (Minor bug caught and fixed in the *orchestration* script mid-session, not in the repo: an early polling attempt matched the literal text of its own echoed shell command — which contained the substring `echo PROC_DONE` as syntax — instead of real output, falsely declaring the process done after 7 seconds; fixed by switching the check to an `RC=$?`-style marker whose value only appears in real output, never in the unexecuted echoed command line.)

**Acceptance criteria:**
- [x] `python -c "import pyrit; print(pyrit.__version__)"` succeeds (PyRIT has no `--version` CLI flag)
- [x] A probe run against the local model completes and produces a readable report file

**Verification:**
- [x] `scripts/verify/pyrit.sh` passes end-to-end: `2 passed, 0 failed`

**Dependencies:** Task 14

**Files likely touched:** `scripts/setup-pyrit.sh`, `scripts/verify/pyrit.sh`

**Estimated scope:** S (revised: M — PyRIT's real dependency weight and CPU-inference timing turned out heavier than Garak's would have been)

---

### Task 15b: Master install script + preinstalled extras
**Description:** Chain every existing `setup-*.sh` into one master `scripts/install-jazz.sh` (Tracks A+C), matching JAZZ's own "git pull + re-run the install script" update model. Also add a small preinstalled-extras layer — a terminal emulator for Hyprland, a few terminal toys, and two AI coding CLIs (OpenCode, Aider) — per Akash's explicit request. Not part of the original 20-task plan; added ad hoc, tracked here after the fact for consistency.

**Done as of 5 Sept 2026:**
- `scripts/install-jazz.sh` chains `setup-snapper.sh → setup-podman.sh → setup-ollama.sh → setup-pyrit.sh → setup-extras.sh → setup-aider.sh` in dependency order. Each sub-script was already idempotent, so the whole chain is too. Tested live end to end on the dev VM (not just written and assumed correct): every step hit its already-configured skip-path cleanly and finished in seconds.
- `scripts/setup-extras.sh`: `foot` (terminal — chosen over kitty/alacritty since it needs no GPU acceleration, the safer pick given Task 9's still-open WHPX graphics risk), `opencode`, `cmatrix`, `fastfetch`, `cava`, `sl` — verified live against Arch's package JSON API to confirm official-repo availability, not assumed. `hollywood`/`asciiquarium`/`pipes.sh` were checked too and found to be AUR-only — skipped per Akash's explicit decision to keep JAZZ pacman-only, no AUR helper.
- `scripts/setup-aider.sh`: Aider isn't in any Arch repo, and its PyPI package (`aider-chat==0.86.2`) requires Python `<3.13` while Arch's official `python` is now 3.14.7 — a plain venv off system Python (the `setup-pyrit.sh` approach) doesn't work here. Fixed by installing `uv` (also official-repo) to provision an isolated Python 3.12 build independent of pacman, then building the venv against that.
- Confirmed live via `pacman -Q` and `aider --version`: every package installed with a real version (`foot 1.28.0-1`, `opencode 1.18.25-1`, `cmatrix 2.0-4`, `fastfetch 2.68.1-1`, `cava 0.10.7-1`, `sl 5.05-6`, `aider 0.86.2`).

**Acceptance criteria:**
- [x] `install-jazz.sh <username>` runs all six setup scripts successfully in one pass
- [x] Every extras package (`foot`, `opencode`, `cmatrix`, `fastfetch`, `cava`, `sl`) installs from official repos with a real version
- [x] `aider --version` succeeds despite Arch shipping a newer Python than Aider supports

**Verification:**
- [x] Live end-to-end run on the dev VM, confirmed via `pacman -Q` and `aider --version` output — not just script logic

**Dependencies:** Task 15

**Files likely touched:** `scripts/install-jazz.sh`, `scripts/setup-extras.sh`, `scripts/setup-aider.sh`

**Estimated scope:** S

---

### Task 15c: Everyday desktop app layer
**Description:** Add a normal consumer/productivity/creator/gaming desktop layer sitting alongside JAZZ's AI-engineering tooling, per Akash's explicit request (a categorized wishlist: Consumer Core, Productivity Pack, Creator Pack, Gaming Pack, Advanced). Not part of the original 20-task plan; added ad hoc, tracked here after the fact for consistency, same as Task 15b.

**Done as of 5 Sept 2026:**
- Every candidate package checked live against Arch's official package JSON API before being added — nothing assumed from training data. Two rounds of trimming followed, each driven by a real tradeoff Akash weighed in on rather than silently decided:
  - **Cut outright:** LocalSend (AUR-only; KDE Connect already covers phone↔PC transfer), Timeshift (overlaps Snapper, which already owns JAZZ's snapshot/rollback story), Pamac/Bauh (AUR-only), Krita/Kdenlive/OBS Studio (Krita overlaps GIMP; Kdenlive drags in a large KDE Frameworks/MLT/FFmpeg tree for unlikely-to-be-used video editing; OBS went with it), Gamescope/MangoHud (Steam + GameMode stay, overlay extras don't), and the whole Virtual Machines line (virt-manager/libvirt/qemu-desktop) — Akash first asked to drop only qemu-desktop, but that would've left virt-manager/libvirt with no hypervisor backend at all, so the non-functional half was cut too rather than shipping a broken shell.
  - **Swapped for a lighter equivalent:** `file-roller` → `xarchiver` (no GNOME/Nautilus dependency chain), `qemu-full` → `qemu-desktop` (dropped entirely per above, but was the initially-planned swap), `gnome-calendar` → `gsimplecal` (gnome-calendar needs a real CalDAV backend to be more than decoration per Design-Vision.md §6; gsimplecal is a minimal GTK date-grid popup that doesn't pretend to do more than it can), `gnome-software` → **Bazaar** (added back after Akash asked "do we have an app store?" — Bazaar is a newer Flatpak-only store built without gnome-software's PackageKit/pacman-backend baggage, the app-store GUI Akash actually wanted without the GTK4/libadwaita dependency weight).
  - **Final 18-package list:** Firefox, Flatpak, Bazaar, VLC, zathura, thunar, xarchiver, Bitwarden, KDE Connect, gsimplecal, LibreOffice, Thunderbird, Obsidian, GIMP, Inkscape, Audacity, Steam, GameMode, Syncthing.
- `scripts/setup-desktop-apps.sh` also enables Arch's `[multilib]` repo (idempotent — skips if already on) since Steam needs it and it isn't on by default.
- Chained into `install-jazz.sh` after the extras/Aider step.
- **Live-tested 5 Sept 2026 (Task 11b session):** this VM's test disk had already grown to 79GiB (from Task 13's earlier resize) with 50GiB free before the install — no resize actually needed. Ran `setup-desktop-apps.sh` for real: all 18 packages installed cleanly with real versions (`firefox 155.0.1-1`, `flatpak 1:1.18.2-1`, `bazaar 0.9.4-4`, `vlc 3.0.23_2-13`, `zathura 2026.07.18-1`, `thunar 4.20.9-1`, `xarchiver 0.5.4.27-1`, `bitwarden 2026.3.1-2`, `kdeconnect 26.08.0-1`, `gsimplecal 2.5.2-1`, `libreoffice-fresh 26.8.0-2`, `thunderbird 154.0-2`, `obsidian 1.13.7-2`, `gimp 3.2.4-2`, `inkscape 1.4.4-6`, `audacity 1:3.7.8-4`, `steam 1.0.0.87-3`, `gamemode 1.8.2-3`, `syncthing 2.1.3-1`). Disk finished at 36GiB used / 42GiB free (46%) — comfortable headroom.

**Acceptance criteria:**
- [x] Every package in the final list confirmed live against Arch's official package API — no AUR
- [x] Every cut/swap has a recorded reason, not a silent removal
- [x] `install-jazz.sh` runs the full chain (including this script) successfully
- [x] `pacman -Q` confirms all 18 packages installed with real versions

**Verification:**
- [x] Live end-to-end run on the dev VM — confirmed via real `pacman -Q` output, not just script logic

**Dependencies:** Task 15b

**Files likely touched:** `scripts/install-jazz.sh`, `scripts/setup-desktop-apps.sh`

**Estimated scope:** S

---

## Checkpoint: Core tracks
- [x] Tracks A, B, C each pass all their `scripts/verify/*.sh` checks independently
- [ ] **Review with Akash before Task 16 — it's the first task that spends real money**

**Done as of 5 Sept 2026.** Full re-verify on a fresh VM boot (`vm/boot-dev-vm.ps1`), every
Track A/B/C script run back-to-back in one pass, none skipped:

| Track | Script | Result |
|---|---|---|
| A | `verify/snapper.sh` | 2 passed, 0 failed |
| B | `verify/hyprland.sh holycowstudios` | 3 passed, 0 failed |
| B | `verify/quickshell.sh holycowstudios` | 2 passed, 0 failed |
| B | `verify/theme.sh holycowstudios` | 6 passed, 0 failed |
| B | `verify/widgets-tier1.sh holycowstudios` | 9 passed, 0 failed |
| C | `verify/podman.sh holycowstudios` | 2 passed, 0 failed |
| C | `verify/ai-core.sh` (as holycowstudios) | 3 passed, 0 failed |
| C | `verify/ollama.sh` | 2 passed, 0 failed |
| C | `verify/pyrit.sh` | 2 passed, 0 failed |

**Total: 31 passed, 0 failed.** VM was cleanly powered off (`poweroff`) afterward, confirmed via
QEMU process exit. Tracks A+B+C are solid on a from-scratch boot - ready for Akash's review before
Task 16 (GPU rental, spends real money).

---

## Phase 3: GPU validation (isolated, explicit go-ahead required)

### Task 16: Rent a GPU, validate the AI-core container
**Description:** Rent a Vast.ai (or RunPod fallback) RTX 4090 spot instance, run Task 13's exact container definition unmodified, and confirm `torch.cuda.is_available()` returns `True`. Tear the instance down immediately after — never leave it running.

**In progress as of 6 Sept 2026:** `scripts/verify/gpu-cuda.sh` drafted (written, not yet run — needs a real rented instance, which Akash provisions himself since it spends money). Unlike every other `verify/*.sh`, this one runs from the local machine and SSHes out to the instance rather than running on the target; it deliberately never starts the container's default JupyterLab command (unauthenticated, binds `0.0.0.0` — fine on the local dev VM's loopback-only network, not on an internet-facing rented box), only a one-shot `python -c "torch.cuda.is_available()"` check. Prefers `docker` over `podman` for the `--gpus all` GPU-passthrough flag, since Vast.ai/RunPod GPU images are built around docker's nvidia-container-toolkit wiring. Waiting on Akash to rent the instance and hand over its SSH host/port before this can actually run.

**Acceptance criteria:**
- [ ] The same container from Task 13 runs on the rented instance without modification
- [ ] `torch.cuda.is_available()` returns `True` inside it
- [ ] Instance is terminated after validation

**Verification:**
- [ ] `scripts/verify/gpu-cuda.sh` (run manually against the remote instance) confirms the above

**Dependencies:** Task 13

**Files likely touched:** `scripts/verify/gpu-cuda.sh`

**Estimated scope:** S (small in files touched, but requires explicit ask-first per SPEC.md boundaries before spending money)

---

### Task 16b: Bare-metal install on real hardware
**Description:** Not part of the original 20-task plan; added ad hoc after Akash raised a real gap — every task so far (all 31 Core-tracks checkpoint passes) has only ever run inside a QEMU VM with software-rendered graphics, never on real silicon. Install JAZZ on Akash's own Lenovo Yoga 6 13ARE05 (Ryzen 7 4700U, Radeon Vega 7 iGPU, 16GB RAM), dual-booting alongside the existing Windows install in a 100GB partition, to prove the whole stack — base install through Tracks A/B/C — actually works on physical hardware, not just in a VM. This is the closest thing JAZZ has to an Omarchy-style "does this really work on someone's laptop" test.

**Why this hardware is a good test candidate (assessed 6 Sept 2026):** 16GB RAM and 100GB storage are both comfortably above what the full stack needs (the desktop-app layer alone used ~37GB in Task 15c). More importantly, AMD's `amdgpu` open-source driver has a stronger real-world Linux track record than the Intel Arc iGPU this project's dev laptop has — no `xe.force_probe`-style kernel workaround is expected to be needed here. The one hard gate is UEFI: confirmed fine, since any 2020 pre-installed-Windows laptop boots UEFI.

**Real differences from the VM install this task must account for — do not just reuse `install/base-profile.json` unmodified:**
1. **Disk device path will differ** — the VM's config hardcodes `/dev/vda`; the Yoga's NVMe drive will be something like `/dev/nvme0n1`. Must confirm the real device name live (`lsblt`/`fdisk -l`) once booted from USB, not guessed.
2. **Must not wipe the disk.** `base-profile.json` sets `"wipe": false` already but still defines the *entire* disk's two partitions from scratch (`config_type: manual_partitioning`, `device_modifications` covering the whole device) — that assumed a disk with nothing else on it. A new `install/bare-metal-profile.json` is needed that only touches the 100GB of unallocated space Akash frees up by shrinking the Windows partition (via Windows' own Disk Management, not a Linux tool — safer for resizing an existing NTFS volume), leaving Windows' existing partitions completely alone.
3. **Reuse Windows' existing ESP, don't create a second one.** Standard dual-boot pattern: mount the laptop's existing EFI System Partition at `/boot` (status "modify"/existing, not "create") so systemd-boot adds its own boot entry alongside Windows Boot Manager's, rather than creating a redundant second ESP. Exact partition UUID is unknown until the live USB shows the real layout.
4. **Drop the serial-console `custom_commands` hack** (`console=ttyS0,115200` baked into the kernel cmdline) — that existed purely because the dev VM has no real display and had to be watched over a serial socket. Real hardware has an actual screen; this isn't needed (harmless to leave in, but it's VM-specific cruft, not a real requirement).
5. **New verification needed that the VM could never test:** real GPU acceleration (confirm Hyprland is actually using `amdgpu`/Mesa hardware rendering, not falling back to software rendering the way the VM always did), and real wifi/bluetooth hardware working (untested on any VM so far, since QEMU's user-mode networking sidesteps real wifi drivers entirely).

**Planned flow (drafted 6 Sept 2026, not yet executed):**
1. **Akash's own prep, on the physical laptop, before anything else:** back up any data he cares about; check/record the BitLocker recovery key if Device Encryption is on; disable Windows "Fast Startup"; shrink the Windows partition via Disk Management to free ~100GB of unallocated space; disable Secure Boot in UEFI firmware settings.
2. Flash the official Arch ISO to USB (Rufus, DD mode) and boot it on the Yoga in UEFI mode.
3. In the live environment: set a root password (`passwd`) and confirm network reachability so Claude can SSH in from the Windows machine and drive the install the same rigorous way Tasks 5/6 were done (not hand-typed and unverified) — falls back to Akash typing directly at the laptop if networking in the live env doesn't cooperate.
4. Inspect the real disk layout (`lsblk`, `fdisk -l`), identify the existing ESP and the freed unallocated space, and hand-author `install/bare-metal-profile.json` from those real values (adapted from `base-profile.json` per the four differences above).
5. Run `archinstall --config install/bare-metal-profile.json --creds <credentials> --silent`, reboot, confirm both Windows and JAZZ appear as separate boot options.
6. Run `scripts/install-jazz.sh <username>` exactly as on the VM.
7. Run every Track A/B/C `scripts/verify/*.sh` again, plus new hardware-only checks: confirm `glxinfo`/`hyprctl` shows real `amdgpu` rendering (not `llvmpipe`/software), confirm wifi/bluetooth hardware is recognized and usable.

**Acceptance criteria:**
- [x] Windows install is untouched and still boots normally after JAZZ is installed alongside it — `efibootmgr` confirmed the Windows Boot Manager entry was preserved, Windows' own partitions (`nvme0n1p2/p3/p4`) were never touched at the partition-table level, and Akash confirmed live (7 Sept 2026) that Windows actually boots fine
- [x] JAZZ installs on the real Yoga 6 hardware via the same `archinstall` + `install-jazz.sh` mechanism used on the VM (adapted profile, not a different install method) — done 6 Sept 2026, using `install/bare-metal-profile.json` (new)
- [x] All Track A/B/C `verify/*.sh` scripts pass on the real hardware, same as the VM checkpoint — 42/42 passed (base-install 11, snapper 2, hyprland 3, quickshell 2, theme 6, widgets-tier1 9, podman 2, ai-core 3, ollama 2, pyrit 2)
- [x] Hyprland is confirmed using real `amdgpu`/Mesa hardware rendering, not a software fallback — `lspci -k` shows the Ryzen 4700U's Vega iGPU with `Kernel driver in use: amdgpu`, and `/sys/class/drm/card1` exposes the laptop's real `eDP-1` panel; unlike the VM there is no software/virtual DRM device on this hardware at all, so Hyprland (which worked cleanly through every verify script) has no fallback path to have used
- [x] Wifi and Bluetooth hardware both work on the installed system — `nmcli` shows `wlp2s0` connected to a real network, `bluetoothctl show` shows a powered-on real controller (`hci0`)

**Verification:**
- [x] Live, on the real laptop — not simulated, not assumed from the VM's results. Done 6 Sept 2026.

**Real bug found and fixed along the way:** `setup-theme.sh`'s idempotency check (`grep -q 'hl.window_rule'`) collided with window rules Hyprland's own stock auto-generated config already ships (`suppress-maximize-events`, `fix-xwayland-drags`, etc.) - the check always saw *some* `hl.window_rule` present and silently skipped adding the border-color rule, on every install, including the VM. The Core-tracks checkpoint's `verify/theme.sh` never caught this because todo.md's own history shows Task 11 was last hand-verified before Hyprland's package template grew those extra example rules. Fixed by matching a marker unique to this script (`Added by setup-theme.sh`) instead of the generic string. This is a real fix, not bare-metal-specific - it affects the VM install too.

**Dependencies:** Checkpoint: Core tracks (done)

**Files likely touched:** `install/bare-metal-profile.json` (new, done), `scripts/setup-theme.sh` (bug fix), `scripts/verify/*.sh` (run, not modified - real hardware surfaced a genuine bug in a *setup* script, not a verify script)

**Estimated scope:** M — mechanically similar to Tasks 4-6, but on hardware Claude has no direct tool access to, so pacing depends on Akash's own physical steps (partitioning, USB boot, BIOS settings) between each remotely-driven part

---

### Task 21: Own the base Hyprland config
**Description:** Not part of the original 20-task plan; added 6 Sept 2026 after real-hardware testing surfaced the root cause of "this feels like stock Hyprland, not JAZZ": `setup-hyprland.sh` only writes its own `hyprland.lua` scaffold if no config file exists yet. On both the VM and the Yoga 6, Hyprland's own package auto-generates a default config the first time the compositor launches (e.g. an early/curious login before `install-jazz.sh` ever runs) - so the guard silently skips, and Track B's whole chain (`setup-quickshell.sh`/`setup-theme.sh`/`setup-widgets-tier1.sh`) ends up appending onto Hyprland's stock example config instead of JAZZ's own. This is why the real install still had the stock launcher placeholder (`hyprlauncher`, a name that isn't a real package), stock keybinds, and stock window-rule examples.

Fix: `setup-hyprland.sh` force-authors JAZZ's own definitive `hyprland.lua` unconditionally (backs up any existing one first, doesn't silently defer to it), with a complete real keybind scheme - not just a minimal scaffold.

**Scope expanded live (6 Sept 2026, Akash's request) once the base fix was in place:** keyboard-first stays the design (no window title bars/buttons - `Design-Vision.md` sec 1/5 already commits to this, confirmed with Akash directly rather than assumed), but every window action must have a real, working, documented keybind. Added: file manager launch (dolphin - was in the stock config, got dropped in the first rewrite pass), maximize vs. true fullscreen as two distinct actions (`window.fullscreen` with `mode = "maximized"` vs `"fullscreen"` - confirmed as genuinely different dispatcher states, not two names for the same thing), minimize (no native concept in a tiling WM - implemented as moving the window to a `special:minimized` scratchpad workspace, which Task 22's dock will list/restore from), and directional focus/window movement (Super+arrows) - a core tiling-WM navigation gap missed in the first draft. Full reference recorded in new `docs/Keybinds.md`, which must be kept in sync with this script - not left to drift.

**Real bugs found and fixed live on the Yoga 6 during this task, not just designed on paper:**
1. Hyprland's Lua key-string parser requires the modifier written as `SHIFT` (all-caps) - `Shift` (mixed case) fails with "Unknown keysym" and breaks config load entirely, taking down every SHIFT-modified bind at once. Confirmed live (red error banner, `hyprctl reload`), not caught by any static check beforehand.
2. Workspace switching is a `hl.dsp.focus({workspace = ...})` call, not a `hl.dsp.workspace.switch(...)` (that function doesn't exist - `hl.dsp.workspace.*` only covers `change_id`/`rename`/`move`-to-monitor/`swap_monitors`/`toggle_special`). Caught before deploying, by fetching the real dispatcher list from `hyprwm/hyprland-wiki` via `gh api` rather than trusting an initial guess.

**Acceptance criteria:**
- [x] `setup-hyprland.sh` always writes JAZZ's own config, never silently skips because a file already exists
- [x] The app launcher keybind actually launches a real installed program, not a placeholder name
- [x] Existing appended content from `setup-quickshell.sh`/`setup-theme.sh`/`setup-widgets-tier1.sh` still applies cleanly on top of the new base (no regression in Tasks 9-11/widgets-tier1)
- [x] All Track A/B/C `verify/*.sh` scripts still pass after this change - re-ran hyprland/quickshell/theme/widgets-tier1 live, 20/20 passed after the full rebuild
- [x] Every window action (launch/close/float/maximize/fullscreen/minimize/restore/focus-move/window-move/workspace-switch/exit) has a real keybind, confirmed live via `hyprctl reload` producing no config errors
- [x] `docs/Keybinds.md` exists and matches the real config exactly

**Verification:** Live, on the Yoga 6 (real hardware) - re-ran `scripts/verify/hyprland.sh`, `quickshell.sh`, `theme.sh`, `widgets-tier1.sh` (20/20 passed) plus a live `hyprctl reload` config-error check after every change

**Dependencies:** Task 16b (done - this is the task that surfaced the bug)

**Files likely touched:** `scripts/setup-hyprland.sh`, `docs/Keybinds.md` (new)

**Estimated scope:** S (grew to M once live testing surfaced the full keybind gap)

---

### Task 22: Top-bar shortcuts + app dock + system menu
**Description:** Not part of the original 20-task plan; added 6 Sept 2026, Akash's request after seeing the real desktop. Went through three real iterations live on the Yoga 6, not one pass:

1. First cut: hand-rolled launcher grid + hardcoded dock app list + hand-drawn unicode-glyph icons. Akash correctly rejected this - diverged from the approved "Jazz Desktop Simulation" mockup, and a hardcoded app list would never pick up a newly-installed package.
2. A full research pass (Omarchy's real architecture - Waybar+Walker+swaybg, no dock at all; macOS Dock's pinned+running+real-icons model; Windows' shallow-flyout-vs-full-Settings-app split) - see the synthesis this produced: real `.desktop`-file scanning is the correct architecture, not a hardcoded list or a hand-rolled launcher when wofi already solves that correctly.
3. Rebuilt again once more after Akash asked for the native grid launcher back after all (his own aesthetic call - matching JAZZ's workspace-color theme, not wofi's generic system list), this time built correctly on the real app-scan data + `Quickshell.iconPath()` for real icons, not glyphs.

**What's actually built and live-verified on the Yoga 6 (6 Sept 2026):**
- `configs/quickshell/scan-apps.py` - a real XDG `.desktop` file scanner (Name/Icon/Exec/StartupWMClass, NoDisplay/Hidden respected), the single source of truth for the dock and launcher - a newly installed package's `.desktop` file is picked up on the next scan, zero code changes needed
- Native app launcher (Super+R or the 🎷 top-bar icon): real icons via `Quickshell.iconPath()`, tiles colored by the *active workspace's* accent (Forge blue by default), search-filterable
- Always-visible dock (macOS model): pinned apps (Firefox/Bazaar/LibreOffice/GIMP/Obsidian/Thunderbird/VLC/Steam/Terminal) + any other currently-running app not in that pinned set, real icons, a running-indicator dot; matched to running windows via the standard cascade (StartupWMClass -> desktop-file name -> Exec basename). Settings and the App Launcher are also permanently pinned (Akash's request) with deliberate glyphs (universal gear for Settings, a saxophone for the launcher - neither is a real installed app, so an icon-theme lookup would have been guesswork)
- Top bar retints to the active workspace's color live (`Behavior on color`) - the one thing none of Windows/macOS/Omarchy do; this is JAZZ's actual visual signature per Design-Vision.md's "color does real work" philosophy
- Top bar also shows: session username, now-playing (playerctl, only visible when something's actually playing), a notification bell with a real unread count (`dunstctl count history`), a clipboard-history icon (`cliphist` + `wl-paste --watch`, piped through wofi to pick an entry), wifi SSID, battery %
- Settings split like Windows: a shallow quick-toggles flyout (wifi/Bluetooth/volume/brightness, gear icon or Super+S) plus a separate, real multi-section Settings panel (Appearance incl. a real wallpaper picker/Network/Bluetooth/Sound/Display, Super+Comma or the dock's Settings icon)
- A real widget edit/toggle panel (✎ Edit on the Tier 1 widget stack) - per-widget enable/disable, persisted to `~/.local/share/jazz/widget-prefs.json`
- Power menu (Lock/Log out/Restart/Shut down) on its own icon/keybind (Super+Escape), separate from quick-settings

**Explicitly NOT considered finished** - Akash's own words, 6 Sept 2026: "its good for now but we need to improve design of jazz for sure. i would research more." This is a working checkpoint, not a design-complete state - expect another real design pass once that research lands.

**Acceptance criteria:**
- [x] Top bar has real, working icon shortcuts (launcher/quick-settings/power, plus username/now-playing/notifications/clipboard/wifi/battery)
- [x] A real app dock exists (pinned + running apps, click to launch/switch, always-visible per Akash's preference over the original keyboard-first-only design note)
- [x] A system settings surface exists, split shallow-flyout vs. full panel, with a working dark/light toggle and power menu
- [x] All of the above render as real layer-shell surfaces, confirmed live via `hyprctl layers` and direct screen checks, not just present in source
- [ ] Overall visual design polish - explicitly still pending Akash's further research, not yet signed off

**Verification:** Live, on the Yoga 6 (real hardware), multiple rounds

**Dependencies:** Task 21 (needs JAZZ's own config to bind the dock's keybind into, not stock Hyprland's)

**Files touched:** `scripts/setup-dock.sh` (new), `scripts/setup-wallpaper.sh` (new), `configs/quickshell/scan-apps.py` (new), `configs/quickshell/gen_wallpaper.py` (new, shared with Task 23), `scripts/install-jazz.sh` (chain updated)

**Estimated scope:** M, grew to L across the three iterations

---

### Task 23: JAZZ visual identity (wallpaper + dark/light theme)
**Description:** Not part of the original 20-task plan; added 6 Sept 2026, Akash's direct feedback after using the real desktop: "it should also have theme and wallpapers... JAZZ should have its own personality rather than Hyprland." Real gap - the installed system still showed Hyprland's own stock triangle-pattern wallpaper (Task 11's `Theme.qml` only ever themed the top bar/border colors, never the desktop background), and there was no dark/light mode at all, just the one fixed palette.

**What's actually built and live-verified (6 Sept 2026):**
- `configs/quickshell/gen_wallpaper.py` generates a real dark/light JAZZ-branded wallpaper pair (Pillow) - a calm neutral base, a subtle Forge-blue radial glow (Forge being the default/highest-traffic workspace), and a restrained waveform motif nodding to "Jazz" as music - deliberately not a loud rainbow gradient across all six workspace colors, which would read as generic/AI-templated and contradict Design-Vision.md sec 1's "calm by default"
- Wallpaper is set via `swaybg`, **not hyprpaper** - hyprpaper's own IPC (`hyprctl hyprpaper preload/wallpaper`) genuinely fails ("invalid hyprpaper request") against this Hyprland build, confirmed live, not assumed; swaybg is simpler (one CLI process, no IPC) and is what Omarchy itself actually uses for wallpaper, confirmed via its real source
- `jazz-wallpaper-set <path>` (installed to `/usr/local/bin`) kills and restarts swaybg with a new image - swaybg has no live-swap IPC, confirmed
- `Theme.qml`'s `darkMode` toggle (Task 21/22) drives both the panel/panelInk chrome tokens AND now calls `jazz-wallpaper-set` to swap the matching wallpaper - workspace identity colors (forge/lab/arena/observe/vault/range) stay constant across modes per Design-Vision.md sec 2, only chrome + wallpaper switch
- Reachable from the Settings panel's Appearance tab (toggle + a real wallpaper picker showing actual files from the wallpapers directory, not fake thumbnails)

**Acceptance criteria:**
- [x] Hyprland's stock wallpaper is fully replaced by a real JAZZ-branded one
- [x] `Theme.qml` exposes both a light and dark palette, switchable live without restarting Hyprland/Quickshell
- [x] The switch is reachable from the Settings panel
- [x] Confirmed live via screenshot on the Yoga 6, both modes
- [ ] Overall visual design polish - same explicit caveat as Task 22, Akash plans further research before this is considered done

**Verification:** Live, on the Yoga 6 (real hardware) - visual confirmation, both modes

**Dependencies:** Task 21 (own config), Task 22 (Settings panel, for the toggle UI)

**Files touched:** `scripts/setup-wallpaper.sh` (new), `configs/quickshell/gen_wallpaper.py` (new)

**Estimated scope:** M

---

### Task 24: Fix AMD ACP audio not initializing on real hardware
**Description:** Not part of the original 20-task plan; found 6 Sept 2026 while building Task 22's volume control. `wpctl status` shows zero audio devices/sinks at all on the real Yoga 6, despite the kernel correctly detecting the hardware (`/proc/asound/cards` shows a real `acp` card - AMD's Audio CoProcessor) and `alsa-card-profiles` being installed (version-matched to pipewire, 1.6.8). WirePlumber's own log shows the actual failure: `wp-device: SPA handle 'api.alsa.acp.device' could not be loaded; is it installed?` / `Failed to create 'api.alsa.acp.device' device` - the package that should provide this SPA handle is present, but the handle still won't load. Root cause not yet diagnosed - deliberately not chased down mid-Task-22 to avoid scope creep; needs its own investigation (possibly a missing SPA plugin file specifically, a version mismatch, or a genuine upstream bug with this pipewire/wireplumber version against ACP hardware).

**Acceptance criteria:**
- [ ] `wpctl status` shows at least one real audio sink on the Yoga 6
- [ ] Volume can actually be changed via `wpctl set-volume` and audibly/measurably takes effect
- [ ] Task 22's volume control in the system menu shows a real slider instead of "not available" once this is fixed

**Verification:** Live, on the Yoga 6 (real hardware)

**Dependencies:** None

**Files likely touched:** Unknown yet - investigation needed first

**Estimated scope:** M (unknown until root-caused)

---

### Task 25: JAZZ design polish - a real second pass
**Description:** Not part of the original 20-task plan; added 6 Sept 2026 per Akash's own words after Task 22/23's rebuild: "its good for now but we need to improve design of jazz for sure. i would research more." Explicitly deferred, not scoped yet - Akash is doing his own research before deciding what changes. Do not start building against this until he brings back concrete direction; this entry exists so the open item isn't lost between sessions, not to prescribe a solution.

**Known rough edges as of 6 Sept 2026 (for reference, not a locked scope):**
- Icon-based (glyph/emoji) system icons render inconsistently across contexts - real icon-theme icons (Task 22's dock/launcher work) look noticeably more polished than the remaining glyph-based tray icons
- Top bar information density/alignment could use another visual pass now that it carries much more real data (username, now-playing, notifications, clipboard, wifi, battery) than the original mockup's simpler version
- Task 24's audio gap (no sink detected) blocks the volume control from ever showing real data until fixed

**Acceptance criteria:** Not yet defined - depends on Akash's research

**Verification:** TBD

**Dependencies:** Tasks 21-23 (the working baseline this would refine)

**Files likely touched:** TBD

**Estimated scope:** Unknown until scoped

---

## Phase 4: Public-repo readiness

### Task 17: README
**Description:** Write the public-facing README — what JAZZ is, why it exists, install instructions referencing `install/` and `scripts/`, current status, a demo GIF/screenshot once the desktop from Task 10/11 is stable.

**Acceptance criteria:**
- [ ] README covers: what/why, install steps, current status, at least one visual (screenshot/GIF)

**Verification:**
- [ ] Manual read-through: could a stranger follow this?

**Dependencies:** Tasks 5, 9, 10 (needs a working, demoable system)

**Files likely touched:** `README.md`

**Estimated scope:** S

---

### Task 18: LICENSE + CHANGELOG
**Description:** Add the MIT LICENSE (copyright Akash Navet / Holy Cow Studios Pvt Ltd) and start `CHANGELOG.md`.

**Acceptance criteria:**
- [ ] `LICENSE` present with correct copyright holders
- [ ] `CHANGELOG.md` exists with at least one entry

**Verification:**
- [ ] Manual check

**Dependencies:** None (can happen any time, listed here for phase grouping)

**Files likely touched:** `LICENSE`, `CHANGELOG.md`

**Estimated scope:** XS

---

### Task 19: Hygiene gate
**Description:** Full-history Gitleaks scan (not just staged-diff) and a manual pass confirming every tracked config references `$HOME`/XDG variables natively rather than hardcoded personal paths.

**Acceptance criteria:**
- [ ] `gitleaks detect` (full history, not `--staged`) returns clean
- [ ] No hardcoded personal paths/usernames found in `configs/`

**Verification:**
- [ ] Command output reviewed directly

**Dependencies:** All prior tasks

**Files likely touched:** none (audit only, fixes applied wherever found)

**Estimated scope:** S

---

### Task 20: Clean-clone rebuild test
**Description:** The spec's own definition-of-done for reproducibility: boot a genuinely fresh vanilla Arch ISO in a disposable VM, clone the repo, run only what's in `install/` and `scripts/`, and confirm it reproduces a working system using nothing but the repo and its README.

**Acceptance criteria:**
- [ ] A fresh VM, following only the README, reaches the same working state as the development VM

**Verification:**
- [ ] Full walkthrough performed and documented; any gap between "what I did from memory" and "what's actually in the repo" gets fixed before this passes

**Dependencies:** Task 19

**Files likely touched:** whatever gaps are found during the walkthrough

**Estimated scope:** M

---

## Checkpoint: Public-repo ready
- [ ] All 12 of SPEC.md's success criteria met
- [ ] **Explicit go-ahead from Akash obtained before the first public push** — this checklist does not authorize that step on its own, per SPEC.md's boundaries
