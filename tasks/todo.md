# Task List: JAZZ Phase 1

Companion to `tasks/plan.md`. Each task is sized S or M (per the planning skill's guidance, nothing here should run L+ — if a task turns out larger once started, split it rather than push through).

---

## Recommended build sequence for remaining tasks (assessed 7 Sept 2026, locked in)

Reasoned out with Akash 7 Sept 2026, covering everything open after Task 30 was scoped. Grouped by dependency, not strictly linear — several tiers can run in parallel. All four live-verification flags below were checked the same day once Akash reconnected to the Yoga 6 — sequence is now final, not provisional.

1. **Task 18** (LICENSE/CHANGELOG) — trivial, no dependencies either direction, do anytime.
2. ~~**Task 24** (AMD ACP audio)~~ — **DONE 7 Sept 2026**, turned out to already be working (see Task 24's entry) — no longer gates anything below it.
3. **Task 30** (permission tiers + Checkpoint→Act→Undo) — backend can be built standalone now; its UI slots into Task 28's Agents tab whenever that lands. Do before any AI-action feature (Jazz Files' AI follow-on, future NL control).
4. **Task 28** (Jazz Settings) → **Task 29** (Jazz Files v1) — Settings first since it grows an existing surface and Task 30's UI needs its Agents tab; Files is the bigger, more novel build. Task 29's Dolphin retirement confirmed trivial (one-line keybind change).
5. **Task 26** (AI Command Centre — GPU panel confirmed shippable with real data via `radeontop`) and **Task 27** (theme-as-bundle, now split into subtasks 27a-27f) — can interleave with tier 4, no strict order between them.
6. **Task 25** (design polish) — before tier 4/5 if Akash's own research lands soon (avoids re-skinning brand-new apps right after building them); otherwise as one unifying pass after tiers 4/5.
7. **Task 16** (GPU rental) — fully independent, gated only on Akash's own money/timing decision.
8. **Task 17 → Task 19 → Task 20** (Phase 4) — must be last; Task 19 explicitly depends on all prior tasks, Task 20 on Task 19.

**All four "confirm live" flags checked 7 Sept 2026, once Akash reconnected to the Yoga 6:**
- Task 26: `radeontop` confirmed working, returns real live data (VRAM/clocks/per-block utilization) on the Vega iGPU — GPU panel ships real, not "pending."
- Task 27: kitty config empty (defaults), `hyprlock.conf` doesn't exist, dunst has no config dir — all three genuinely need Task 27's work from scratch, folded into the new subtask breakdown.
- Task 24: turned out to already work via the plain HDA audio path — **DONE**, downgraded from open investigation to resolved.
- Task 29: Dolphin/`Super+E` wiring confirmed trivial to retire (single variable, one bind).

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

**Real bug found and fixed 8 Sept 2026 (Akash's feedback, live use after Task 27a/27g), in two rounds:**

**Round 1:** the workspace-retint philosophy above was only ever fully wired into the top bar and the native app launcher (both correctly used `workspaces.activeColor()`) - the quick-settings flyout (Bluetooth toggle, volume/brightness slider fill, "More settings..." button), the dock (hover highlight, running-window dot), and the widget edit panel's per-widget toggle were all still hardcoded to `Theme.forge`. Found via `grep -n 'Theme\.forge' scripts/setup-dock.sh` (7 hits) and fixed all 7 to `workspaces.activeColor()`.

**Round 2, same day, after Akash flagged it was still incomplete** ("setting tabs all have forge colour fixed and gidget colour is fixed to green of lab" - i.e. Settings' buttons never followed workspace at all, and the To-do widget's checked-item color was hardcoded to `Theme.lab` specifically, not workspace-reactive). Root cause: `workspaces` was a file-local `id` inside `shell.qml`, invisible to `Settings.qml` (a separate loaded component) - there was no way for Settings' buttons/toggles to know the active workspace's color at all. **Real architecture fix:** extracted a new `WorkspaceState` singleton (`configs/quickshell/WorkspaceState.qml`, registered in `configs/quickshell/qmldir` alongside `Theme` - same mechanism) owning the active-workspace name, the live `hyprctl activeworkspace` poll, and `workspace-overrides.json` - the one source both `shell.qml` and `Settings.qml` (via `ui/Button.qml`'s `primary` variant, `ui/Toggle.qml`'s "on" state, and `ui/ListRow.qml`'s selected-state) now read. Also fixed the To-do widget's `Theme.lab` and 9 more passive accent spots in `Settings.qml` found via a full sweep (Displays/Accessibility rollback-banner borders, Sound's volume fill, Network's signal bars and "Connected" text, Bluetooth's "Connected" text, Developer's "(live)" indicator and D-Bus selected-row highlight) - plus one real gap from the original Task 27g migration itself: Network's Wi-Fi radio toggle had been missed entirely and was still raw inline QML, never migrated to the `Toggle` component. Confirmed live: switched to the real Lab workspace, Settings' sidebar-selected-item highlight, Wi-Fi toggle, and Connect buttons all correctly turned Lab's green (screenshot-verified), then switched back to Forge and confirmed clean.

(The Tier 1 widget panel's Pomodoro Start/Reset buttons use fixed `Theme.arena`/`Theme.vault` colors and the Desktop tab's default-color reference swatches use each workspace's own base `Theme.xxx` token - both intentional, unrelated to this bug.)

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

**Re-checked live 7 Sept 2026 - functionally resolved, root cause still open but no longer blocking.** `/proc/asound/cards` actually shows three cards, not one: two generic `HDA-Intel` cards plus `acp`. `wpctl status` now shows a real sink (`Ryzen HD Audio Controller Speaker`) and real sources (mic array), both live and controllable - confirmed by actually setting volume (`wpctl set-volume 52 0.7`) and playing `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga` via `paplay`, which Akash physically heard through the laptop speakers. This sink comes from the plain HDA path (card 1, `Generic_1`), not the `acp` card - the two are independent audio paths on this hardware. The original ACP SPA-handle error still fires every boot (confirmed in this session's journal too), but it no longer blocks real audio output since the HDA path works on its own. Root cause of the ACP-specific failure remains undiagnosed (likely governs a secondary DSP/smart-amp path, not core playback) - worth revisiting later for completeness, but not a blocker for Task 22/28's volume control or Task 26's audio panel.

**Acceptance criteria:**
- [x] `wpctl status` shows at least one real audio sink on the Yoga 6
- [x] Volume can actually be changed via `wpctl set-volume` and audibly/measurably takes effect - confirmed, Akash heard the test sound
- [x] Task 22's volume control in the system menu shows a real slider instead of "not available" - confirmed via live screenshot of the Quick Settings panel: Volume renders as a real filled slider, matching Brightness's styling, not placeholder text

**Status: DONE as of 7 Sept 2026.** All three acceptance criteria met live on real hardware. The underlying ACP SPA-handle bug (separate `acp` card, distinct from the working HDA path) remains undiagnosed but is no longer tracked as blocking - split off as a possible future investigation if a real need for it surfaces (e.g. a smart-amp/DSP feature that specifically needs the ACP path), not carried forward as open work here.

**Verification:** Live, on the Yoga 6 (real hardware) - confirmed 7 Sept 2026

**Dependencies:** None

**Files likely touched:** None needed for the core fix (already working) - `configs/quickshell/shell.qml`'s volume control may need re-verification only

**Estimated scope:** Downgraded from M to XS (just a UI re-check) - the audio-not-working assumption behind the original M estimate no longer holds

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

### Task 26: AI Command Centre (Observe workspace dashboard) — **DONE, 8 Sept 2026**
**Description:** Not part of the original 20-task plan; scoped 7 Sept 2026 from `docs/JAZZ-v2.md` sec 4a (Claude's proposal, promoted to a real task on Akash's request). The content and scope are already fully designed - `Design-Vision.md` sec 4, written 31 Aug 2026, never actually built. A Quickshell panel scoped to the **Observe workspace** (Design-Vision.md sec 2: "Logs, metrics, the AI Command Centre" - this is workspace-specific, not a global always-visible panel like the dock/widget-stack), showing real system + AI-stack telemetry.

**What it shows (per Design-Vision.md sec 4, unchanged from the original spec):**
- **Real now:** CPU / memory / temperature / power (`/proc`/`/sys` reads), Ollama's loaded model + VRAM-equivalent size + context length + quantization (`GET /api/ps` against the local Ollama endpoint), Podman per-container CPU/memory/network (`podman stats --format json`)
- **Deliberately shown as pending, not faked, unless verification below says otherwise:** GPU utilization/VRAM graph - the original spec assumed the dev laptop's Intel Xe iGPU (no working `intel_gpu_top` support). Task 16b moved the real target hardware to an AMD Ryzen 4700U (Vega iGPU) - AMD's GPU monitoring tooling (`radeontop`, `amdgpu_top`) has historically been more reliable than Intel Xe's. **Check live, on the Yoga 6, whether one of these actually works before deciding this panel is real vs. honestly-pending** - do not assume either way, the hardware changed since this was originally speced.
- Token throughput - explicitly not free per the original spec (would need client-side timing of Ollama's streaming response, not a pulled metric) - still fine to leave as a later refinement, not required for this task's first pass

**Technical mechanism (reuse what's already proven, don't reinvent):** Tonight's Task 22 build already proved the exact pattern this needs live on real hardware - `Process` + `SplitParser` (line-streamed) or `StdioCollector` (whole-output, `this.text` in `onStreamFinished`) polling on a `Timer`, exactly as used for network SSID/Bluetooth status/volume/brightness. No new Quickshell technique to learn here, just new data sources. Visibility gated on `workspaces.active === "Observe"` (the active-workspace state already tracked and polled every second since Task 22's top-bar retinting).

**Acceptance criteria:**
- [x] Panel appears when on the Observe workspace, not visible on others - confirmed both ways via `hyprctl layers` (the compositor's own authoritative state) and screenshots
- [x] CPU/memory/temperature/power show real, live-updating values
- [x] Ollama's loaded model info (name/size/context/quantization) shown live, real data from `GET /api/ps`
- [x] Podman per-container stats shown live, real data from `podman stats`
- [x] GPU utilization: **real data, not pending** - see finding below, this hardware turned out better-supported than the original spec assumed
- [x] Confirmed live on the Yoga 6, screenshot showing the Observe workspace with real data

**Real finding, better than expected:** the original spec (written when the dev laptop's Intel Xe iGPU was the target) assumed GPU monitoring would need `radeontop`/`amdgpu_top` and might not work at all. Checked live on the real Yoga 6 hardware (AMD Ryzen 4700U / Vega iGPU) before writing any QML: `/sys/class/drm/card1/device/{gpu_busy_percent,mem_info_vram_used,mem_info_vram_total}` and `/sys/class/hwmon/hwmon4/power1_input` (the `amdgpu` hwmon) all exist and return real live values directly from the kernel driver - **no external tool needed at all**, not even `radeontop`. GPU utilization/VRAM/power are all real, not honestly-pending as originally anticipated.

**Also confirmed live before building:** the real AMD CPU temperature sensor is `k10temp`'s `Tctl` (hwmon), not `acpitz` (a different, less specific zone that also exists); CPU % needs a genuine two-sample `/proc/stat` delta (a single read can't give a percentage) - implemented as a small embedded Python script (`time.sleep(0.4)` between samples) rather than fighting bash/awk quoting; `podman stats --no-stream --format json` was verified against a real temporary test container (`alpine sleep 60`, removed after) to get the real field names (`cpu_percent`, `mem_usage`, `net_io`, etc., all pre-formatted strings) rather than guessed.

**Architecture:** the panel sits at the wlr-layer-shell **Background** layer (`WlrLayershell.layer: WlrLayer.Background`, below normal windows, above the wallpaper) rather than an overlay popup, so it reads as "this workspace's own content" - matching how a real workspace-scoped dashboard should feel, not a popup you'd summon. Visibility is bound directly to `WorkspaceState.active === "Observe"` (the same singleton built for the workspace-color fix earlier the same day) - zero new state-tracking needed, confirming that refactor already pays for itself.

**Verification:** Live, on the Yoga 6 (real hardware) - screenshots confirm real live values (CPU/temp/power fluctuating between polls, matching expected real system behavior) and confirmed the panel is genuinely absent (not just hidden) on other workspaces via `hyprctl layers`.

**Real Ollama chat added same day, Akash's request right after seeing the dashboard** ("can we also chat with it" -> "can we have our ollama GUI for chat... within command center"): a genuine streaming chat interface. `curl -s -N -X POST http://localhost:11434/api/chat -d '{...,"stream":true}'` confirmed live to emit one real JSON chunk per line (`{"message":{"content":"..."},"done":false}` ... final line `"done":true`), read via `SplitParser` exactly like every other real-time source in this codebase. The request body is built with `JSON.stringify()` and written to a temp file via `FileView.setText()` (`onSaved:` triggers the curl `Process`) rather than interpolated into a shell command string, avoiding any quoting/injection risk with arbitrary user text. Each streamed chunk is appended to the in-progress assistant message via a full array reassignment (`chatMessages = chatMessages.slice()`), which is what actually makes QML's reactivity fire per chunk. Verified end-to-end using a temporary `IpcHandler` (`qs ipc call cctest send "<msg>"`) added only to the deployed test build (never committed, removed before every clean deploy) - since there's no way to simulate real keyboard/mouse input remotely, this let the whole file-write -> curl-stream -> UI-update path be proven live without needing Akash at the physical keyboard for every iteration.

**Real layout iteration, same session, driven by several rounds of Akash's own live feedback** (a good example of iterating fast against real screenshots + a real user rather than guessing at a design in one pass):
1. Compact telemetry sidebar (was 4 large cards, now a single narrow 240px column) + chat given the majority of the width, per Akash's explicit "chat space must be most space."
2. Translucent panel background (`Qt.rgba(Theme.panel.r/g/b, 0.7)`) so the Observe wallpaper shows through, rather than a fully opaque block.
3. **Real bug found via live click-testing:** the Send button was rendering completely hidden - first a `bottomMargin` too small to clear the dock, then discovered the **Tier 1 widget panel** (Notes/To-do/clock, permanently visible on every workspace since Task 11b) was overlapping the chat column's right edge at a higher z-layer, hiding Send underneath it entirely.
4. **That overlap became its own real fix, per Akash's follow-up** ("widget fixed there is annoying, it blocks many things"): the Tier 1 widget panel is no longer permanently visible - it's a real toggleable popup now (`visible: false` by default, new `IpcHandler target: "widgets"`), summoned via a new ▦ icon in the top bar, with a fade-in (`Behavior on opacity`, reduced-motion-gated like the top bar's own retint) on open.
5. **Model picker became a real dropdown** (hand-rolled `Item` + conditional popup `Rectangle`, no `QtQuick.Controls` dependency - matches this project's existing pattern of hand-building `Toggle`/`Button`/`ListRow`) instead of a `Repeater` of pill buttons, which doesn't scale past 2-3 installed models. Its popup initially rendered **behind** the chat message box - a real QML stacking-order gotcha (a child's high `z` only wins against siblings *within its own parent's paint order*; the dropdown's parent `Row` still painted before its own later sibling, the message `Rectangle`, regardless of the dropdown's own internal `z: 200`) - fixed by giving the `Row` itself `z: 10` so the whole thing (dropdown included) paints above what comes after it.
6. **Real symmetry bug, worth remembering for any future Row-based layout with a hardcoded sibling-width formula:** an attempt to add breathing room by bumping the outer `Row`'s `spacing` silently broke the chat column's width, because that width was a separate hardcoded formula (`parent.width - 240 - 20 - 1`) that didn't reference the `Row`'s actual `spacing` value - the two drifted out of sync the moment one changed without the other. **Fixed properly, not by re-guessing more magic numbers:** replaced the whole three-column layout with a plain `Item` + real anchors (sidebar anchored left; divider anchored `24px` right of the sidebar; chat anchored `24px` right of the divider AND to the `Item`'s own right edge) - both the "chat to divider" gap and the "chat to panel edge" gap are driven by the identical literal margin now, symmetric by construction, and immune to this whole class of bug since nothing is computed by subtraction anymore.

**Files touched:** `scripts/setup-dock.sh` (new `commandCentre` `PanelWindow` section in the `shell.qml` heredoc: telemetry + chat + widget-panel toggle + top-bar icon)

**Dependencies:** Task 21 (own config), Task 22 (the polling/`Process` patterns this reuses)

**Files likely touched:** `configs/quickshell/shell.qml` (new PanelWindow, workspace-gated), possibly a new `scripts/setup-` script if this needs its own package installs (e.g. `radeontop`)

**Estimated scope:** M

---

### Task 27: Theme-as-bundle system + design foundation
**Description:** Not part of the original 20-task plan; scoped 7 Sept 2026 from `docs/JAZZ-v2.md` sec 3 point 2 (Omarchy research finding, promoted to a real task on Akash's request). Real gap identified: JAZZ's current dark/light toggle (Task 21/23) only ever switches `Theme.qml`'s chrome tokens (`panel`/`panelInk`) + the wallpaper (via `jazz-wallpaper-set`) - two things, switched together but not as part of a real bundling system. Omarchy's actual execution (confirmed via research) is that a "theme" is a **complete bundle** - wallpaper, terminal colors, shell chrome, and lock-screen appearance all restyle together as one atomic switch, with a picker.

**Broadened 7 Sept 2026** after Akash shared `Operating_Icons_Themes_Wallpapers_Design_Guide.md` and asked for it to inform this task. That doc is a full OS design-system spec (icon pipeline, cursor theme, GTK/Qt compatibility layers, Matugen dynamic wallpaper theming, Theme CI, a "Design Lab" preview tool, licensed wallpaper collections) - real reference material, but far larger than Task 27's original bundling scope. Broken into subtasks below: the genuinely applicable parts became 27a-27f; everything disproportionate to JAZZ's current single-maintainer scale is listed under "Deliberately not adopted" instead of silently dropped.

**Tool availability confirmed live on the Yoga 6 before scoping subtasks (JAZZ is pacman-only, no AUR helper - same constraint that shaped Task 15c):**
- Official repo (`extra`), usable: `papirus-icon-theme`, `kvantum`, `kvantum-qt5`, `matugen`, `ttf-jetbrains-mono`, `inter-font`
- **AUR-only, NOT usable as packages:** `bibata-cursor-theme`, `adw-gtk3` - the guide's own recommended cursor theme and GTK3 compat layer. Either vendor manually from upstream source (no AUR/pacman involved) or skip - decide per-subtask below, don't block the rest of Task 27 on this.

**What JAZZ's current dark/light switch does NOT yet touch, that a real bundle would:**
- **kitty** (the terminal) - confirmed live 7 Sept 2026: config dir exists but is completely empty, using kitty's stock defaults, never themed.
- **hyprlock** (the lock screen, installed Task 22 for the power menu's Lock button) - confirmed live: `~/.config/hypr/hyprlock.conf` does not exist at all, package installed but never configured.
- **dunst** (notifications, installed Task 22) - confirmed live: no config dir exists either; dunst is running, on stock defaults.

**Scope for this task (the bundling architecture, not necessarily many themes):** JAZZ currently has exactly two built-in palettes (dark/light) vs. Omarchy's 22 - the valuable v2 work is the **mechanism**, built so more themes can be added later as pure data (a bundle definition) without new engineering, not authoring a large theme library right now.

---

#### Task 27a: Brand tokens (single source of truth) — **DONE, 7 Sept 2026**
**Description:** Formalize `Theme.qml`'s current hardcoded values (`panel`/`panelInk`, the 6 workspace colors) plus the missing semantic tokens (surface/surfaceRaised/textPrimary/textSecondary/positive/warning/critical) into real token files, per the guide's §4 schema - stop scattering raw hex values across QML and config files.

**Acceptance criteria:**
- [x] `design/tokens/colors.json` exists with semantic names (not "blue1/blue2"), covering both dark and light palettes plus the 6 existing workspace colors
- [x] `Theme.qml` reads from this file (or a generated QML companion) instead of hardcoding hex values inline — used the generated-companion option: `scripts/generate-theme-qml.py` reads `colors.json` and writes `configs/quickshell/Theme.qml`, which is committed and deployed via a plain `cp` (like Settings.qml), not read live at runtime — avoids a startup flash of default colors while an async file load completes, since every panel needs Theme's values synchronously at launch
- [x] `design/tokens/typography.json` records the two fonts chosen (Inter for UI, JetBrains Mono for terminal-style text — both confirmed official-repo, neither installed/wired yet, that's later work) as data

**Also added:** `positive`/`warning`/`critical` status tokens, deliberately reusing the existing `lab`/`arena`/`range` workspace hex values rather than inventing new ones — `critical` formalizes what Settings.qml's destructive actions (Disconnect/Forget/Remove/Clear) have already been using via `Theme.range` since Task 28. `panel`/`panelInk` kept as live-bound aliases to the new `surface`/`textPrimary` names so every existing reference across `shell.qml`/`Settings.qml` (dozens of usages) keeps working unchanged — no risky wholesale rename.

**Verification:** Live, on the Yoga 6 — generated `Theme.qml` deployed, Quickshell relaunched, zero QML errors, screenshot confirmed pixel-identical to before (all values are unchanged, purely additive).

**Dependencies:** Task 11 (`Theme.qml` exists)
**Estimated scope:** S

**Task 27a-followup: real font picker — DONE, 8 Sept 2026.** Akash asked for a Settings dropdown to actually pick fonts (following the same "curated options" pattern as the theme picker), which meant finally installing/wiring the fonts recorded above but never applied. Curated 4 real options per role (checked live via `pacman -Si`/`fc-match` on the Yoga 6, not assumed - Geist and Manrope turned out to not exist in Arch's official repos at all, swapped for confirmed-available alternatives):
- UI: Inter (default), IBM Plex Sans, Mona Sans, Fira Sans
- Monospace: JetBrains Mono (default), IBM Plex Mono, Iosevka, Cascadia Code

`Theme.qml` gained `uiFont`/`monoFont` properties, same live-FileView pattern as `activeTheme` (Task 27b) - a new `jazz-font-set "<ui>" "<mono>"` writes `~/.config/fontconfig/fonts.conf` (the real ArchWiki-documented `sans-serif`/`monospace` alias mechanism, so GTK/Qt apps pick it up too, not just JAZZ's own shell) plus `font-state.json`, confirmed live with zero relaunch.

**Real architecture snag, found and fixed:** first attempt set `font.family: Theme.uiFont` directly on each top-level `PanelWindow` intending QML's font-inheritance to cascade to every descendant `Text` - crashed instantly (`Cannot assign to non-existent property "font"` - `PanelWindow` is a Window type, not an Item, and only Items have the grouped `font` property Quickshell/Qt Quick inherits through). Real fix: wired `font.family: Theme.uiFont` into the 3 shared `ui/` components (`Button`/`ListRow`/`SectionHeader`, covering most of Settings' text through reuse) plus a scoped regex pass adding it to every single-line `Text`/`TextInput` element in `shell.qml`/`Settings.qml` that didn't already set one (skipping the font-dropdown's own preview rows, which intentionally render each option in its own typeface) - 74 elements, reviewed via diff before deploying, zero corruption.

Deliberately NOT theme-dependent - fonts stay constant across all 4 themes, same principle as the workspace colors (a font is a personal preference, not part of a theme's visual identity).

**Verification:** Live, on the Yoga 6 - switched UI/mono fonts via `jazz-font-set` directly, screenshot confirmed visibly different letterforms (Mona Sans vs Inter) applying with no relaunch; Settings' own dropdown UI (2 pickers, each option previewed in its own font) confirmed rendering correctly via screenshot.
**Files touched:** `design/tokens/typography.json`, `scripts/generate-theme-qml.py`, `scripts/jazz-font-set` (new), `scripts/setup-dock.sh` (font packages + shell.qml heredoc), `scripts/setup-theme-bundle.sh` (jazz-font-set deployment + default apply), `configs/quickshell/Theme.qml`, `configs/quickshell/Settings.qml`, `configs/quickshell/ui/{Button,ListRow,SectionHeader}.qml`

#### Task 27b: Theme compiler + bundle format (the original Task 27 core) — real multi-theme system, mechanism BUILT and live-verified 8 Sept 2026 (commit `82206e1`); wallpaper completeness still open
**Description:** The bundling mechanism itself - unchanged from the original scope above. A theme bundle (directory/manifest) specifies `Theme.qml` token values + wallpaper path + kitty config + hyprlock config + dunst config; one function applies all of them atomically and reloads whichever of kitty/hyprlock/dunst need it.

**Scope locked in 8 Sept 2026** after Akash asked Claude to research why Omarchy's themes/wallpapers look visually appealing (real findings: borrowed proven community palettes rather than invented ones; one `colors.toml` generates config for every app - genuine cohesion because it's architecturally one object; each theme ships a small curated wallpaper set matched to its palette, not a generic pool; a real accessibility floor - Mocha's contrast is 11.3:1, checked not assumed; `matugen`-based Material-You extraction for dynamic wallpaper-derived theming; "omakase" - curated good defaults, not endless raw toggles). Akash then chose (via AskUserQuestion) to build a **real multi-theme system** for JAZZ, not stay single-identity.

**Real architecture decision, not to be silently revisited:** JAZZ's 6 workspace colors (Forge/Lab/Arena/Observe/Vault/Range) stay **constant across every theme** - already documented (`Theme.qml`'s own header comment, `Design-Vision.md` sec 2) as JAZZ's actual signature ("the one thing none of Windows/macOS/Omarchy do"); reshuffling them per-theme like a generic reskin would dilute the one real differentiator JAZZ has over Omarchy. Themes instead control: chrome tokens (surface/textPrimary/textSecondary/surfaceRaised), accent, kitty terminal palette, hyprlock, dunst, and a matched wallpaper - the same `colors.toml`-generates-everything architecture Omarchy uses, applied on top of JAZZ's own fixed-identity system.

**Planned theme set (4, not 22 - quality over quantity, every theme has a real reason to exist, not decoration):**
1. **Forge** (existing dark, refined) - the current cool-blue dark default.
2. **Daylight** (existing light, refined) - the current light counterpart.
3. **Midnight** (new) - near-black, higher-contrast, real OLED/battery/eye-strain rationale.
4. **Warm** (new) - warm-neutral non-blue dark variant, real rationale (blue light late at night).

**Architecture sketch (not yet built):**
- New `design/tokens/themes.json`, separate from `colors.json` (which stays workspace + status colors only, unaffected by theme choice). Each entry: `label`, `mode` (dark/light), `chrome` (4 tokens), `accent`, `terminal` (16-color kitty palette + bg/fg/cursor), `wallpapers` (a list, **minimum 2 per theme, Akash's explicit requirement** - matches Omarchy's own per-theme wallpaper-set precedent from the research, not a single fixed background per theme).
- `scripts/generate-theme-qml.py` extended to be theme-id-driven (bakes ONE chosen theme's literal values into `Theme.qml`, same as it already does for dark/light today) rather than a runtime ternary - switching themes means regenerating + redeploying, not a live in-QML toggle (acceptable - even Omarchy's own switch isn't fully hot-reloaded either).
- New orchestrator script (working name `jazz-theme-set <id>`) - the actual bundle compiler: regenerates `Theme.qml`, writes real `kitty.conf`/`hyprlock.conf`/`dunstrc` from the theme's tokens (**all three currently have NO real config at all** - `kitty`'s config dir is empty, `hyprlock.conf` doesn't exist, `dunst` has no config dir either, all confirmed from earlier project memory, needs re-confirming live before building), applies the wallpaper via the existing `jazz-wallpaper-set` helper, persists the choice, and relaunches Quickshell via `hyprctl dispatch exec_cmd` (never a bare kill, per the established safe-relaunch rule).
- `configs/quickshell/gen_wallpaper.py` (Task 23's existing Pillow generator) extended to take theme parameters (base/accent/mode) instead of being dark/light-hardcoded, and to produce **at least 2 real variants per theme** (not just re-running the same composition once - e.g. varying the waveform-motif placement/density or a second genuinely different composition within the same palette), so the existing Appearance-tab wallpaper picker (Task 22, already supports picking among multiple images) has real choices within every theme, not just one fixed background.
- Settings' Appearance tab: replace the binary Dark/Light toggle with a real theme picker (dropdown, reusing the AI Command Centre's model-picker pattern from Task 26); the existing per-wallpaper picker grid stays underneath it, now populated per-theme.

**Wallpaper sourcing model - changed 8 Sept 2026** after Akash flagged the current Pillow output looks "not so good visual looking" and asked Claude to research how Omarchy actually produces its wallpapers. Findings, from directly inspecting the live repo (`gh api repos/omacom/omarchy` - the maintainer moved it off `basecamp/omarchy`, `themes/tokyo-night/backgrounds/` listed directly): **Omarchy does not procedurally generate wallpapers at all.** Each theme ships 6-8 static `.webp`/`.jpg` files with names like `winding-road`, `sunset-lake`, `swirl-buck`, `oma-cityscape` - finished curated art/photography hand-picked to fit that theme's palette, committed as binary assets. The palette (`colors.toml`) and the wallpaper are chosen together by a human; neither is derived from the other by an algorithm.
This matters because JAZZ's `gen_wallpaper.py` is pure procedural Pillow (radial glow + waveform bars + noise, toggled only by `dark: bool`) - structurally the hardest wallpaper genre to make look premium (competing with real lighting/depth/composition using primitive shapes), and Omarchy sidesteps that difficulty entirely by not generating anything at runtime. **Revised approach:** the ≥2-per-theme requirement should be met primarily with curated/sourced images, not procedural output -
1. AI-generated art (any image model), human-curated, then color-graded in a script to lock exactly to that theme's palette (design guide's own §33 AI-Generated Wallpaper Workflow pipeline: AI concept → human curation → refinement → color grading → crop testing → provenance record) - most realistic path for a solo maintainer with no art budget, and almost certainly how pieces like Omarchy's own "swirl-buck" were produced.
2. Or clearly-licensed real imagery (Wikimedia Commons / NASA / CC0), picked to match the palette, per the guide's §50-52 licensing rules - feeds straight into Task 27f's asset-licensing record.
3. `gen_wallpaper.py`'s procedural generator is kept as one lightweight bonus/"dynamic" option per theme, not the mechanism for the full set - it no longer needs to single-handedly carry the ≥2-per-theme quality bar.

**Acceptance criteria:**
- [x] A defined theme bundle format exists and is documented (`design/tokens/themes.json`)
- [x] Switching a theme atomically updates: `Theme.qml` tokens, wallpaper, kitty colors, hyprlock appearance, dunst appearance - confirmed live (dock pixel-sampled exact-match across all 4 themes; kitty/hyprlock/dunst config files inspected and correct; dunst reload confirmed no error; hyprlock's actual lock screen triggered live 12 Sept 2026 with Akash's explicit go-ahead - see the dedicated write-up below)
- [x] All 4 planned themes (Forge/Daylight/Midnight/Warm) exist as real bundles under this system - Midnight/Warm designed this session (chrome/accent real, terminal palettes hue-derived from each theme's own accent, method documented in `jazz-theme-set`'s docstring)
- [ ] **Every theme ships at least 2 real, genuinely different wallpaper variants** (Akash's explicit requirement) - NOT yet met. Currently each theme has exactly 1: Forge/Daylight still have Task 23's originals (Akash generating real replacements via Recraft, in progress), Midnight/Warm have one `gen_wallpaper.py`-generated placeholder each. Blocked on Akash's curated art per the wallpaper-sourcing model decided earlier this session, not a mechanism gap - `gen_wallpaper.py --variant 2` and the wallpapers list already support more than one, just need the actual images.
- [x] Switch is reachable from the Settings panel's existing Appearance tab (Task 22) - real theme picker (4 pills) replacing the old binary dark/light toggle, confirmed live via screenshot (Forge correctly highlighted as active)
- [x] Confirmed live on the Yoga 6 - kitty.conf/hyprlock.conf/dunstrc content inspected after a switch and matches the theme's tokens exactly

**Two real bugs found and fixed during live verification, 8 Sept 2026:**
1. `hyprctl dispatch exec_cmd("quickshell")` does NOT kill an already-running instance first - relaunching without an explicit `pkill` first left two Quickshell processes competing for the same layer-shell surfaces (visibly: two top bars, two docks, caught live by Akash). Fixed by always killing first, then dispatching - now the documented safe-relaunch procedure (was previously just "dispatch exec_cmd", missing the kill step because earlier relaunches happened to follow an already-crashed instance).
2. `swaybg`'s autostart was completely missing from this specific machine's `hyprland.lua` (confirmed via grep - not a bug in `setup-wallpaper.sh`'s guard logic, which is correct for fresh installs; this live machine just never got it applied) - Akash was seeing Hyprland's stock wallpaper this whole time, not JAZZ's own. Fixed live, now wired through `jazz-theme-set --restore` instead of a hardcoded dark-path line, which also fixes a related persistence gap: without `--restore`, a reboot would have restored Theme.qml's correct last-picked chrome (it reads theme-state.json at startup) while silently reverting the wallpaper to Forge's.

**One false alarm, corrected:** a live check initially seemed to show the FileView-watch live-switch NOT working (top bar stayed Forge blue across every theme switch) - was about to add a Quickshell-relaunch step to "fix" it. Turned out to be a misread: the top bar is workspace-tinted (`WorkspaceState.activeColor()`), correctly constant across themes by design - only chrome (dock/surface) is theme-controlled. Caught before shipping the wrong fix by pixel-sampling the dock instead of eyeballing the top bar; the live watch genuinely works, no relaunch needed.

**Chat text-color bug fixed same session (Akash's report, not part of the original 27b scope but same area):** AI Command Centre's chat message text and input text were hardcoded `#ffffff` regardless of theme - would have been unreadable on Daylight (light theme). Now `Theme.textPrimary`. Akash explicitly confirmed the Send button and model-picker highlight should stay workspace-tinted (`WorkspaceState.activeColor()`, same as the top bar) rather than theme-tinted - verified live by recoloring Observe via the Desktop tab and watching the top bar, Observe's pill, and the Send button all shift together.

**hyprlock live test, 12 Sept 2026 (Akash's explicit go-ahead obtained first):**
Triggered the real lock screen (`hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")'`) rather than continuing to defer it. First attempt produced a real scare, worth recording in full: the screenshot taken immediately after showed no visible password box at all, which read as a rendering failure - killed the process via SSH as a safety precaution (`pkill -x hyprlock`) before asking Akash to touch anything. That triggered Hyprland's own built-in "lockscreen app died" recovery screen - a real, deliberate Hyprland safety feature (a crashed lock client does NOT auto-unlock the session, to prevent exactly this kind of accident from becoming a security hole) - fully recovered via `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'` over the same SSH session, no physical intervention needed, confirmed via screenshot. Akash then clarified: the password box was never broken - `fade_on_empty = true` (already present in the config) intentionally hides the empty input field until a key is pressed, and he'd seen it appear correctly when he tried it physically. **The only real "bug" here was mine: killing a perfectly working process because a static screenshot of its correct idle state looked wrong.**

Retriggered for real after that, this time leaving it running: Akash unlocked it himself with his real password, `hyprlock` exited cleanly (confirmed via `pgrep`, no crash-recovery screen this time), desktop fully restored. Repeated a second full cycle under Daylight (light mode, never tested before) + Observe workspace - correctly renders dark text on the dimmed light wallpaper, real accent-colored input outline, clean unlock, confirmed via screenshot both mid-lock (password dots visible, accent-correct) and post-unlock.

**Real UX gap found by Akash, fixed same session:** the lock screen had no username shown at all, and no JAZZ branding - just clock/date/password box. Added two new labels to `write_hyprlock()`: "Welcome to **JAZZ**" (JAZZ bolded via Pango markup, matching the project's own "the word JAZZ is the logo" branding decision) above the clock, and the real logged-in username (`cmd[update:3600000] echo "$(whoami)"`, same `cmd[]` mechanism already proven working for the clock/date, not a guessed hyprlock-native `$USER` syntax) just above the password field. Verified live via screenshot under Forge - both render correctly, theme-colored.

**Status: hyprlock's live lock screen is now genuinely tested end-to-end (2 full lock/unlock cycles, Forge/dark and Daylight/light, different workspaces each time) and includes a real username + JAZZ branding.** This closes the last open item blocking Task 27b.

**Verification:** Live, on the Yoga 6 - dock pixel-sampled exact-match per theme; kitty/hyprlock/dunst config content inspected; workspace-vs-theme accent split verified via a live recolor test; hyprlock's real lock/unlock cycle completed twice with Akash physically at the keyboard
**Dependencies:** Task 21, Task 22, Task 23, Task 27a (tokens to bundle) - all satisfied
**Remaining before this task can close:** real curated wallpapers (≥2 per theme, Akash producing via Recraft) - Forge/Warm now have 2 each (Task 27b's own follow-up work), Daylight/Midnight still need a 2nd
**Files likely touched:** `design/tokens/themes.json` (new), `scripts/generate-theme-qml.py` (extended), new `scripts/jazz-theme-set` orchestrator, `configs/quickshell/gen_wallpaper.py` (extended), `configs/quickshell/Settings.qml` (Appearance tab theme picker)
**Estimated scope:** L (grew from the original single-mechanism scope to include designing 2 new real palettes + a wallpaper generator extension + kitty/hyprlock/dunst configs built from scratch)

#### Task 27c: JAZZ shell icon system (scoped down from the guide's 60-symbol + full freedesktop tree) — **DONE, 8 Sept 2026**
**Description:** The guide recommends ~60 symbols across a full freedesktop icon-theme directory structure (16/22/24/32/48/scalable/symbolic × apps/actions/devices/places/status/categories). JAZZ doesn't need to theme every possible Linux app icon - Task 22 already solved third-party app icons via `Quickshell.iconPath()` reading real installed icon themes. Scope this to just what JAZZ's own shell chrome actually renders: the icons Quickshell draws itself (wifi/bluetooth/volume tiers/battery/brightness/notifications/power/lock/search + the saxophone launcher glyph and gear Settings glyph already hand-picked in Task 22).
**Source:** Lucide (ISC license) as primary geometry per the guide's own recommendation - vendor the specific SVGs needed, not the whole library. `papirus-icon-theme` (confirmed official repo) stays the fallback for third-party apps, already effectively in place via Task 22's icon-theme lookup.

**Real inventory found (8 Sept 2026), smaller than the wishlist:** grepped every non-ASCII glyph actually rendered in `shell.qml`/`Settings.qml` rather than assuming the guide's full list applied - several categories (Bluetooth, volume, brightness, search) turned out to have no dedicated glyph at all (plain text labels or progress bars), so they were never "cheap-looking" to begin with and needed no replacement. Real inventory: now-playing note, notifications bell, clipboard history, wifi, battery, widgets grid, power (7, top-bar, always white - top bar is always the active workspace's saturated color regardless of theme), Settings gear + Ollama/AI diamond (2, dock, theme-reactive), and the Wi-Fi-secured lock indicator (1, Settings, theme-reactive) = 10 real icons, 13 SVG files (the 3 theme-reactive ones need `-ondark`/`-onlight` baked-color pairs).

**Real constraint found, not guessed:** Quickshell runs Qt's software rendering backend on this hardware (`QT_QUICK_BACKEND=software`, `setup-hyprland.sh`), which doesn't support shader-based SVG recoloring (`ColorOverlay`/`MultiEffect`) - ruled out `currentColor` + runtime tinting as the mechanism. Instead: colors are baked directly into each SVG, and the 3 theme-reactive ones ship as `-ondark`/`-onlight` pairs with QML picking the right file via `Theme.darkMode` at render time (still fully live/reactive across a theme switch, just file-swap based instead of shader-based).

**Deliberate exception:** the saxophone launcher glyph (🎷) stays as the emoji - it's JAZZ's actual brand mark (referenced in the wallpaper logotype concept too), not a generic system icon, and Lucide has no music-instrument icons to substitute. Confirmed live it reads well as a deliberate accent against the new clean line icons, not as leftover inconsistency.

**Acceptance criteria:**
- [x] SVGs (13, not 60 - the real inventory was smaller than the guide's wishlist) covering exactly the symbols JAZZ's shell/dock/settings currently render, normalized to one spec (24x24 canvas, 1.8px stroke, round linecap/linejoin - the guide's §17 spec)
- [x] Stored under `design/icons/symbols/`, referenced by Quickshell instead of any remaining unicode/emoji glyphs (except the deliberate saxophone exception above)
- [x] `papirus-icon-theme` installed live (confirmed via `pacman -Q`, went through a real Snapper pre/post checkpoint) and added to `setup-dock.sh`'s pacman line for fresh installs

**Verification:** Live, on the Yoga 6 - screenshots of the top bar and dock at both close-up and cropped/zoomed resolution confirmed clean rendering; theme-reactivity confirmed by switching Forge→Daylight and back, watching the dock's gear/AI icons flip from light-on-dark to dark-on-light correctly
**Dependencies:** Task 22 (existing icon-lookup mechanism, left untouched - extended alongside it, not replacing it)
**Files touched:** `design/icons/symbols/*.svg` (new, 13 files) + `SOURCE.md`, `scripts/setup-dock.sh` (shell.qml heredoc + icon/papirus deployment), `configs/quickshell/Settings.qml` (Wi-Fi lock indicator)
**Estimated scope:** M

**Confirmed 8 Sept 2026** via the same live-repo research above: Omarchy does zero custom icon design either - each theme's `icons.theme` file is a single line (e.g. `Yaru-magenta`) just naming an existing GTK icon-pack variant; no vendored/drawn icon assets anywhere in the repo. That validates this subtask's plan (Akash's "icons look cheap" complaint traced to raw unicode/emoji glyphs in `shell.qml` - inconsistent stroke weight/style since every emoji comes from a different foundry, doesn't respect `currentColor`/theme accent) - swapping to normalized Lucide SVGs is the right fix, just adapted to QML/SVG since JAZZ is its own shell rather than a GTK app that can reference a system icon-theme name.

#### Task 27d: Dynamic wallpaper theming (Matugen) — **DONE, 12 Sept 2026**
**Description:** Confirmed live that `matugen` is an official-repo package - genuinely buildable, not just aspirational. Derive accent-color candidates from the existing Task 23 wallpaper pair (or any future wallpaper) via Matugen, then run them through a JAZZ-specific validation layer (contrast check, reject near-black/near-white/muddy/oversaturated candidates - guide §38-39) before feeding into 27b's compiler. Raw wallpaper colors must never directly override text/background contrast - only accent/tint.

**Real architecture researched 8 Sept 2026** (Akash asked to check the itsfoss Hyprland-dotfiles roundup for how ML4W actually does this) - the article itself had no technical detail, so went straight to ML4W's real source (`gh api repos/mylinuxforwork/dotfiles`, not guessed):
- `~/.config/matugen/config.toml` is the real template-mapping file: one `[templates.X]` block per target app, each with `input_path` (a template file), `output_path` (where the generated config lands), and an optional `post_hook` (`pkill -SIGUSR1 kitty`, `hyprctl reload`, a GTK-theme-reload script, etc.) so the app picks up the new colors live, not just on next launch. ML4W has a dedicated `[templates.quickshell_overview]` entry targeting `Appearance.colors.qml` - direct precedent for a Quickshell-based shell like JAZZ's.
- Templates use matugen's own Jinja-like syntax against a real Material-You role set (`colors.surface.default.rgba`, `colors.primary`, `colors.on_primary`, etc., plus a raw `for name, value in colors` iterator) - not a handful of ad hoc named colors.
- The actual trigger, from ML4W's `ml4w-wallpaper` script: `matugen image "$IMAGE_PATH" --source-color-index 0 -m <dark|light>`, with the dark/light mode read from GTK's current `gtk-application-prefer-dark-theme` setting (stays in sync with the user's real current preference, not a separate toggle) - then a sequence of per-app reload calls (`reload_waybar`, `reload_quickshell`, `reload_pywalfox`, `reload_swaync`, etc.).

**How this maps onto JAZZ, once real wallpapers exist:** extend `jazz-theme-set` (Task 27b, already built) with a `--from-wallpaper <path>` mode - shell out to `matugen image <path> --source-color-index 0 -m <mode>` (matugen supports JSON output for programmatic consumption), run the derived candidate through the JAZZ-specific contrast/saturation validation layer described above, then feed the validated accent into the SAME kitty/hyprlock/dunst pipeline `jazz-theme-set` already writes - reusing the Task 27b infrastructure rather than building a parallel one.

**DONE, 12 Sept 2026 - unblocked once Forge/Warm got real curated wallpapers (12 Sept 2026, same day).**

**Real findings:**
- `matugen` 4.2.0-1 confirmed official `extra` repo. Its real CLI (`matugen image <path> --source-color-index 0 -m <dark|light> -j hex --dry-run`) was checked live via `--help`, not assumed from the ML4W research above - flags matched, `--dry-run` confirmed it never touches config/wallpaper/apps on its own, just prints JSON.
- **Real decision, confirmed against actual output:** matugen's Material-You `primary` role is tone-shifted for on-dark/on-light FOREGROUND TEXT contrast (Google's own design system), not for use as a flat fill color the way JAZZ's `accent` token is used (Button.qml puts white text ON TOP of a solid accent fill). Ran matugen against Forge's own wallpaper and compared roles directly: `primary` came back `#a7c8ff` (a light pastel, wrong register for a fill), `source_color` came back `#435c83` (the actual extracted dominant swatch, same hue family as Forge's own `#4c6fa0`) - used `source_color` instead of `primary`, falling back to `primary` only if `source_color` is ever missing (version-robustness, not the real path).
- **Real validation layer** (`validate_accent_candidate()` in `jazz-theme-set`): rejects a candidate if lightness is out of a 0.15-0.92 range, if HSV saturation is below 0.22 (muddy/gray), or if its contrast ratio against white is below 2.0:1 (JAZZ's buttons put white text on the accent fill, so this is a real constraint the UI itself already depends on, not an invented threshold). Rejected candidates fall back to the theme's own configured accent, printed to stderr, never silently substituted.
- `--from-wallpaper PATH` only affects the current `jazz-theme-set` invocation in memory - `themes.json` on disk (the theme's canonical accent) is never overwritten. Confirmed live: after testing a derived accent, a plain `jazz-theme-set forge` (no flag) genuinely restores `#4c6fa0`.
- **Scope boundary, honestly not covered:** Quickshell's own chrome (top bar/dock/Settings via `Theme.qml`) does NOT pick up a `--from-wallpaper` override - `Theme.qml`'s per-theme accent table is baked in at build time from `themes.json` (Task 27b), and `theme-state.json` only carries `activeTheme`, not a per-run accent override. The derived accent DOES flow into kitty, hyprlock, dunst, Kvantum, and GTK3 - real, screenshot/pixel-verified live theme surfaces - just not Quickshell's own QML chrome in this pass. Extending `Theme.qml` with an accent-override `FileView` (same live-reload pattern already used for `activeTheme`/fonts) would close this gap if ever wanted; not built now since 27d is explicitly optional scope.
- **Real bug found and fixed, caught only by pixel-sampling a live screenshot, not by reading code:** the first pass assumed (from Task 27e, incorrectly) that Kvantum recolors its bundled SVG shapes entirely from `.kvconfig`'s `[GeneralColors]` values. A rendered VLC checkbox still showed KvArcDark's original `#5294e2` after applying a derived accent - pixel-sampled it (`#5294E2` exactly, not close-but-off) rather than assuming the screenshot "looked dark enough to be fine." Root cause: `KvArcDark.svg` itself bakes its accent-blue family directly into ~65 shape fills (checkbox ticks, focus rings, slider handles) - only background/text-role fills are actually `[GeneralColors]`-driven, contrary to the Task 27e claim. Fixed by having `write_kvantum()` also substitute the same accent-family literals (`#5294e2`, `#4693e6` -> accent; `#58acff` -> a lightened accent tint) directly in the generated per-theme `.svg`, not just the `.kvconfig` - left one confirmed-unrelated purple literal (`#b74aff`, only 4 occurrences, a distinct hue with no evidence it tracks accent) untouched rather than guess. Re-sampled the exact same checkbox pixel afterward: a full grid read back `#435C83` (the derived accent) as the fill, confirming the fix - the earlier single-pixel read that still showed a dark tone had just landed on the checkmark's own dark stroke, not the fill, a real lesson in sampling more than one point before concluding a fix didn't work.
- **Real bug found and fixed (repeat of Task 27e's process note, hit again writing the verify script):** `verify/matugen.sh`'s own `jazz-theme-set` calls crashed the wallpaper daemon the same way, since the script didn't export `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` either. Fixed by having the verify script export both itself unconditionally, rather than relying on every future caller to remember.
- New `scripts/verify/matugen.sh`: tests BOTH real outcomes, not just the happy path - Forge's own curated wallpaper (saturated, mid-tone) is expected to be ACCEPTED, Daylight's flat procedural placeholder (near-white, low-saturation) is expected to be REJECTED, both read from each theme's own first `wallpapers` entry rather than hardcoded filenames. 6/6 passed live on the Yoga 6, including a check that a plain `jazz-theme-set forge` afterward genuinely restores the canonical accent.
- **Follow-up spot-check, same day (Akash's request):** the automated tests above only proved an ACCEPT case under dark mode (Forge) and a REJECT case under light mode (Daylight's own placeholder) - never an ACCEPT case under light mode. Ran `jazz-theme-set daylight --from-wallpaper <Forge's real wallpaper>` (deriving from a different theme's art than the one being applied to, which the flag always allowed) while the Lab workspace was focused, to check the workspace/theme/accent combination together. Accepted the same `#435c83` candidate (matugen's `source_color` role is mode-invariant - it's the extracted seed color before any light/dark tonal mapping, confirmed by observing the same value returned regardless of `-m light`/`-m dark`). Pixel-sampled a live VLC checkbox again: fill was exactly `#435C83` against Daylight's real light surface `#E9EAEC`, and the Lab workspace's top-bar color stayed correctly independent of theme throughout (workspace color and theme accent are separate concerns by design, Design-Vision.md sec 2). This was the one real combination the automated suite didn't cover - now spot-checked live, not just inferred from the code being symmetric.

**Acceptance criteria:**
- [x] `matugen` installed and produces a palette from JAZZ's existing wallpaper
- [x] A validation step rejects unsuitable candidate colors before they reach the live theme (contrast-tested, not raw Matugen output) - proven with a real rejected case (Daylight's placeholder), not just a hypothetical
- [x] At least one real accent color flows from a wallpaper through Matugen into the live theme, confirmed via screenshot - pixel-sampled a real VLC checkbox rendering the exact derived accent (`#435C83`), not eyeballed

**Dependencies:** Task 27a (token schema), Task 27b (compiler to feed into), Task 23 (wallpaper mechanism)
**Estimated scope:** M
**Note:** genuinely optional relative to 27a/27b/27c - JAZZ's two-palette (dark/light) approach works without this; treat as an enhancement, not a blocker for the rest of Task 27.

#### Task 27e: Qt/GTK compatibility layer — **DONE, 12 Sept 2026**
**Description:** For the third-party Qt/GTK apps in Task 15c's list (not JAZZ's own Quickshell/QML surfaces, which need no compatibility layer). Kvantum (confirmed official repo) for Qt widget apps. GTK3 compat was previously assumed blocked on `adw-gtk3` being AUR-only - re-checked live and that's now outdated.

**Real findings, 12 Sept 2026:**
- `kvantum` (1.1.8-1), `kvantum-qt5` (1.1.8-1), and `adw-gtk-theme` (6.5-1, a differently-named successor to the old AUR-only `adw-gtk3`) all confirmed official `extra` repo via live `pacman -Si`/`pacman -Ss` - no AUR needed for either half of this task.
- Kvantum recolors much of its bundled SVG shapes from a `.kvconfig`'s `[GeneralColors]` hex values at render time (confirmed by inspecting the installed `KvArcDark` theme) - but **correction, found while building Task 27d:** this is NOT universal. `KvArcDark.svg` bakes its accent-blue family directly into ~65 shape fills (checkbox ticks, focus rings, slider handles) that `[GeneralColors]` substitution alone never touches - only background/text-role fills are actually kvconfig-driven. A real per-JAZZ-theme Kvantum theme needs the SVG's own accent-family literals substituted too, not just the `.kvconfig` - see Task 27d's write-up for the fix. This was missed here because Task 27e's own acceptance criteria (VLC's overall look) happened to pass without it - only Task 27d's pixel-level checkbox check caught it.
- Vendored KvArcDark's `.kvconfig`/`.svg` unmodified into `configs/kvantum/JazzBase.{kvconfig,svg}` (author Tsu Jan, GPL-3.0-or-later, confirmed via `pacman -Qi kvantum` - full record in `configs/kvantum/SOURCE.md`, feeds Task 27f).
- Extended `jazz-theme-set` (Task 27b's orchestrator) with `write_kvantum()`/`write_gtk3()`: generates `~/.config/Kvantum/Jazz-<theme-id>/` per theme (mode-aware substitution of `surface`/`surfaceRaised`/`accent`/`textPrimary` into the template), selects it via `~/.config/Kvantum/kvantum.kvconfig`, and writes `~/.config/gtk-3.0/settings.ini` picking `adw-gtk3` vs `adw-gtk3-dark` by theme mode. Every JAZZ theme switch now reskins Qt AND GTK3 apps alongside kitty/hyprlock/dunst/Quickshell.
- New `scripts/setup-kvantum.sh` installs the three packages, deploys the base template to `$JAZZ_DATA_DIR/kvantum-base/`, and adds `hl.env("QT_STYLE_OVERRIDE", "kvantum")` to `hyprland.lua` - chained into `install-jazz.sh` right before `setup-theme-bundle.sh`.
- **Real bug found and fixed live, caught specifically by testing Daylight (JAZZ's one light-mode theme) rather than stopping at Forge:** the generic `#ffffffXX -> textPrimary` text-color substitution ran *after* the key-based substitutions, so it incorrectly re-matched and overwrote `base.color`'s own freshly-written `#ffffff` (light mode's base field color) with Daylight's dark text color - `base.color` came out as `#23262b` instead of white. Fixed by reordering: blanket substitutions now run first against the untouched template, key-based substitutions run last so they always win. Re-verified across all 4 themes after the fix (`highlight.color` correctly distinct per theme: forge `#4c6fa0`, daylight `#3d5c8a`, midnight `#5c86ad`, warm `#b8783f`).
- **Live-verified on the Yoga 6, both modes:** `scripts/verify/kvantum.sh` (new) passed 6/6 on Forge. Launched a real VLC instance with `QT_STYLE_OVERRIDE=kvantum` set directly (no Hyprland restart needed/risked) under both Forge (dark) and Daylight (light) and confirmed via screenshot each time: VLC renders genuinely themed - dark/Forge-toned in one case, light/readable-dark-text in the other - not the default Breeze look either time. **Note:** `hl.env()` only takes effect for windows Hyprland spawns after its own next start - the live session's already-running Hyprland won't pick up the new env var until a natural reboot/restart; verified the mechanism directly via explicit env vars instead of forcing a compositor restart mid-session.
- **Process note:** a direct `jazz-theme-set` invocation over SSH without `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` set silently crashes its `jazz-wallpaper-set` call (swaybg can't connect to the compositor) and leaves zero wallpaper daemon running, reverting the desktop to Hyprland's own default fallback pattern - hit this once mid-session (caught by Akash, not self-caught), fixed by always exporting both vars before calling `jazz-theme-set`/`jazz-wallpaper-set` over SSH.

**Acceptance criteria:**
- [x] `kvantum`/`kvantum-qt5` installed, JAZZ's palette applied to at least one real Qt app from Task 15c's list - VLC, confirmed live via screenshot under both a dark and a light JAZZ theme
- [x] Explicit decision recorded on GTK3 - not vendored manually, not skipped: `adw-gtk-theme` is genuinely official-repo now, installed and wired per-theme

**Dependencies:** Task 27a (tokens), Task 15c (app list to test against)
**Estimated scope:** S

#### Task 27f: Asset licensing record — **DONE, 12 Sept 2026**
**Description:** Lightweight but non-optional given JAZZ's existing public-repo-readiness requirement (project memory: clean history, no unlicensed assets). Every vendored asset from 27c (Lucide SVGs) and 27e (Papirus, Kvantum, any vendored adw-gtk3) needs a source/license/modification record, per the guide's §48 schema.

**Real findings, 12 Sept 2026:** `licenses/ASSETS.md` written with 6 entries: Lucide (ISC, 27c's 10 icons/13 files), Papirus (GPL-3.0, confirmed live via `pacman -Qi papirus-icon-theme` - the URL/license weren't just assumed), KvArcDark (GPL-3.0-or-later, author Tsu Jan, confirmed via `pacman -Qi kvantum`, 27e), adw-gtk3 (LGPL-2.1-only, confirmed live via `pacman -Qi adw-gtk-theme` - a real license check, not guessed from the project name), plus Forge/Warm's curated wallpapers (Akash's own Recraft generations, not third-party-licensed stock) and an explicit "not yet covered" note for Daylight/Midnight's still-placeholder wallpapers. Task 27d has no assets yet (not built) so nothing to record there currently - the dependency is satisfied vacuously, not skipped. `design/icons/symbols/SOURCE.md`'s interim "see Task 27f, not yet written" note updated to point at the real file.

**Acceptance criteria:**
- [x] `licenses/ASSETS.md` exists, one entry per vendored asset (source, author, license, URL, modifications)
- [x] Covers everything pulled in by 27c/27e (27d has no assets yet, nothing to cover)

**Dependencies:** 27c, 27d, 27e (needs their assets to exist first)
**Estimated scope:** XS

#### Task 27g: Shared QML component library — **DONE, 8 Sept 2026**
**Description:** Added 7 Sept 2026 from `Operating_UX_UI_Blueprint.md` §61 (Akash's request, analyzed same session). Real, already-visible pain, not speculative: Task 28's Settings.qml alone hand-repeats the same "forge-colored rounded rectangle + white centered text + MouseArea" button markup, the same toggle-switch markup, and the same list-row markup a dozen-plus times across its sections. Every new tab copies the last one's inline styling instead of reusing a component.

**Scope:** Extract the handful of patterns actually repeated today into real reusable QML components - not the blueprint's full 16-component wishlist, just what JAZZ's own code already duplicates:
- `Button.qml` (the forge-colored action button pattern - text + click handler)
- `Toggle.qml` (the on/off switch pattern used in Appearance's dark-mode toggle and Agents' policy buttons)
- `ListRow.qml` (the sidebar-item / policy-row / app-row pattern - label + optional trailing content + selected state)
- `SectionHeader.qml` (the small-caps `Theme.textSecondary` bold label used at the top of every tab)

**Acceptance criteria:**
- [x] All 4 components exist under a shared location (`configs/quickshell/ui/`) and are importable from both `shell.qml` and `Settings.qml` — both files gained `import "ui"`; each component itself does `import "../"` to reach the `Theme` singleton, following the exact same qmldir-registration mechanism already proven for `Theme` (`configs/quickshell/qmldir`'s `singleton Theme 1.0 Theme.qml`) — a bare `import "ui"` alone was NOT enough (`SectionHeader is not a type` at runtime until `ui/qmldir` explicitly registered each type; confirmed live before doing the full migration)
- [x] Settings.qml's existing sections (Agents' policy buttons, Appearance's dark-mode toggle, every sidebar/section header) are migrated to use them, confirmed still rendering correctly live — migrated far beyond just those three named examples: all 31 remaining section headers (mechanical regex), the 18-row sidebar (`ListRow`), all 4 real Toggle instances (Appearance/Accessibility/Network/Bluetooth), and ~23 distinct `Button` call sites covering Desktop/Displays/Sound/Network/Bluetooth/Privacy/Agents/Storage/Updates/Accessibility/System/Developer - essentially the entire button surface of the file. Confirmed via screenshots on 4 different tabs (Network, Agents, Accessibility, Developer) after migration - pixel-identical to before
- [x] Any NEW section written after this lands uses the shared components, not fresh inline markup

**Real finding, worth remembering for any future Quickshell QML subdirectory:** a plain relative directory import (`import "ui"`) is NOT enough for Quickshell to resolve types in a subfolder, unlike stock Qt Quick's usual implicit-directory-import behavior - Quickshell's own `qs:` virtual-URL loader needs an explicit `qmldir` in that subdirectory listing each type (`Button 1.0 Button.qml`, etc.), the same registration style already used for the `Theme` singleton. Caught immediately via a deliberate one-component test (`SectionHeader` wired into one tab, deployed, screenshot) before committing to the full migration - exactly the kind of QML error that's loud and immediate (whole panel fails `qs ipc call settings toggle` with "Target not found") rather than a silent bug, so this class of risk was cheap to catch early.

**Migration method:** built a Python script with ~28 exact-match `(old, new)` string-replacement pairs (one per real duplicated block, enumerated by reading the full ~1840-line file) plus one regex pass for the 31 mechanical `SectionHeader` cases, run on the Yoga 6 (no local Python on the Windows host) against the placeholder-intact source, then pulled the transformed file back into the repo. All 28 pairs + the regex matched exactly once each on the first attempt (0 problems) - brace-balance sanity-checked before deploying, then confirmed live via screenshots across 4 tabs.

**`Button.qml` variants, all directly reflecting real pre-existing visual styles found in the codebase (not invented):** `primary` (forge bg, white text - the default), `danger` (critical bg, white text - Disconnect), `outlineDanger` (panel bg, critical border+text - Forget/Remove), `neutral` (panel bg, panelInk border+text - Cancel/Reset/Revert), `subtle` (surfaceRaised, no border - Refresh/Clear/Scan), `flat` (panel bg, no border - the unselected state of Agents' tri-state policy pills). A `fontSize` override (default 10) was added for the handful of buttons that were already using 11px (Displays/Accessibility's Keep/Revert, Storage/Updates' CTAs) to stay pixel-faithful.

**Status: Task 27 now has 27a and 27g done; 27b (theme bundle compiler) is next, planned to pair with Task 25 (design polish) once Akash's own research lands - not started.**

---

**Deliberately not adopted from the design guide (disproportionate to JAZZ's current single-maintainer scale - matches the "stay lightweight, earn complexity through real pain" architecture decision already made 7 Sept 2026):**
- Full freedesktop icon-theme tree with hundreds of app/folder/category icons across 6 pixel sizes - Papirus fallback + 27c's ~25 shell symbols covers real usage; JAZZ isn't shipping a competing general-purpose icon theme.
- Custom cursor theme (Bibata is AUR-only anyway) - use the GTK/Adwaita default cursor, revisit only if it's a real visible problem.
- `operating-themed` as a dedicated D-Bus service - exactly the kind of standalone daemon JAZZ already decided against; 27b's bundle-switch logic lives as a script/Settings-panel action.
- Design Lab, Theme CI, visual regression screenshot testing - real engineering overhead for a team of one; revisit if JAZZ gets outside contributors.
- Full curated wallpaper collection (space/nature/playful families, per-space wallpapers, Blender-authored art), Plymouth boot art, custom greeter - Task 23 already shipped one dark/light pair and `ly` is explicitly called "fine during development" by the guide itself; captured as open backlog ideas in `docs/JAZZ-v2.md`, not this task.
- Icon/Theme CI pipeline (SVGO/scour validation, contact sheets, automated license-metadata checks) - manual review is enough at this scale.

**Verification:** Live, on the Yoga 6 (real hardware) - visual confirmation for each subtask as scoped above
**Estimated scope (whole Task 27):** XL, broken into 7 subtasks (27a-27g) so it can land incrementally rather than as one giant PR

---

### Task 28: Jazz Settings — full expansion — **DONE, 7 Sept 2026**

**Description:** Not part of the original 20-task plan; scoped 7 Sept 2026 from `docs/JAZZ-v2.md` sec 5b, after Akash's explicit direction that JAZZ must have a real GUI-based settings control, going further than Omarchy in this specific area (confirmed via live research, `omarchy.org/manual`/GitHub, 7 Sept 2026: Omarchy's "Settings" is a `Super+Space` menu + `omarchy` CLI wrapping existing tools, not a panel GUI at all). Task 22 already built a real native Quickshell settings surface (5 tabs: Appearance/Network/Bluetooth/Sound/Display) — this task grows that panel into the full structured surface, not a rebuild.

**Scope:** Add sections: Desktop, Keyboard & Mouse, Applications, AI, Privacy, Agents (ties into Task 30's permission ledger/policy once that exists), Storage, Battery & Power, Security, Updates, Accessibility, System, Developer (hidden by default). Add real settings search, driven by a schema (setting id/title/keywords/page), not hardcoded per-page strings — the same schema can later back the Universal Command idea's settings results (`docs/JAZZ-v2.md` sec 5d) without rework. Displays gets a rollback timer on any change ("Keep these display settings? Reverting in 12s") so a bad monitor config can never permanently blank the screen. Storage gives a friendlier view of Track A's existing Snapper/Btrfs data (used/available by category, snapshot storage, cleanup actions).

**Also informed 7 Sept 2026 by two more sources at Akash's request:** the Agentic AI Linux Desktop Blueprint's §26-58 (concrete per-section control lists) and its Implementation Guide's §15/18/19 - the guide's own "do not implement every page at once" advice plus its recommended v0.1/v0.2/v0.3 sequencing directly validated building this task in slices rather than all 17 sections at once.

**Slice 1 DONE, live-verified on the Yoga 6, 7 Sept 2026 (this is a partial pass on an L task, not the full task):**
- Architecture: the Settings panel outgrew shell.qml's single heredoc (was 1071 lines) - extracted to its own `configs/quickshell/Settings.qml`, loaded via `Loader { source: "Settings.qml" }`, written by a new `scripts/setup-settings.sh` chained after `setup-dock.sh` in `install-jazz.sh`. `Theme.qml` gained two more semantic tokens (`surfaceRaised`, `textSecondary`, pulling forward a slice of Task 27a) so every new section styles through tokens, not hardcoded hex - insurance against Task 25 causing a rebuild later.
- Full 18-section navigation shell built (all sections from the Settings Home spec Task 28 already scoped), with an honest "•" marker on sections with no backend yet (not fake controls - matches the project's existing "real data or honest pending, never fake" rule).
- Real schema-driven search implemented (id/title/keywords/page), same shape Universal Command can reuse later per the original scope note.
- **Real sections shipped this slice:** Appearance/Network/Bluetooth/Sound (carried over unchanged from Task 22) + Display (carried over, rollback timer still pending) + three genuinely new ones: **Agents** (reads `jazz-agent-action ledger`/`policy list` live, policy allow/ask/deny buttons write via a new `jazz-agent-action policy set` subcommand added this session), **Storage** (real `df` data + a "Manage snapshots" button reusing the established Network/Bluetooth pattern of launching a terminal for privileged/complex flows, avoiding any new sudo-in-QML risk), **Battery & Power** (real sysfs capacity/status/power draw), **System/About** (real hostname/kernel/CPU/GPU/memory + a working Developer Mode toggle backed by a real marker file).
- Developer Mode toggle verified live both directions: marker file present → "Developer" appears in sidebar with real content; marker absent → correctly hidden, confirmed via screenshot both ways.
- One real bug caught and fixed before deploy: the Agents tab's policy buttons had a broken/duplicate `color:` binding and no click handler at all (would have been decorative, not functional) - fixed to properly track per-row policy state and call `jazz-agent-action policy set` on click, confirmed working live.

**Slice 2 DONE, live-verified on the Yoga 6, 7 Sept 2026:**
- **Applications**: real 43-app catalog (same `scan-apps.py` source the dock/launcher already use), click-to-launch, confirmed live with a real screenshot.
- **AI**: real Ollama status via `/api/tags` (installed models, real param count/quantization/context) and `/api/ps` (currently-loaded model). Both states tested live: idle ("No model currently loaded") and actually running (triggered a real `qwen2.5:0.5b` load via `/api/generate`, confirmed "Running: qwen2.5:0.5b (0 bytes VRAM)" - correctly honest that it's CPU, not GPU, inference).
- One real bug caught and fixed before commit: forgot to flip the `sections` array's `real: false → true` flag for these two, so the sidebar still showed the "pending" dot next to fully-working sections - caught via screenshot, fixed.

**Slice 3 DONE, live-verified on the Yoga 6, 7 Sept 2026:**
- **Security**: real firewall status (`ufw status`, rule count), SSH status, Secure Boot status (`bootctl status`), disk encryption status (`lsblk` LUKS check - confirmed off, plain Btrfs). Needed one new permanent, narrowly-scoped sudoers rule (`/etc/sudoers.d/jazz-settings-firewall`, exactly `ufw status verbose`, nothing broader) since `ufw status` genuinely requires root and there's no non-root path around that - Akash approved this explicitly via AskUserQuestion before it was added, framed correctly as a permanent feature requirement (the real desktop user needs this too), not a debugging shortcut.
- **Updates**: real `checkupdates` (from `pacman-contrib`, newly installed - official repo, designed specifically to check without needing root or touching the live pacman db/lock) - showed "9 updates available" with the real package list, "Check Now" re-check button.

**Slice 4 DONE, live-verified on the Yoga 6, 7 Sept 2026:**
- **Desktop**: real workspace identity list (name/description/color, sourced from `Theme.qml`'s actual tokens - matches the top bar exactly), plus an honest note that dock/hot-corner/icon behavior is fixed by design for v1, not faked as toggles.
- **Keyboard & Mouse**: real Hyprland input option reads (`hyprctl getoption` - natural scroll, tap-to-click, pointer sensitivity, marked read-only for now) + JAZZ's real `docs/Keybinds.md` displayed directly (now deployed to the data dir by `setup-settings.sh` too, so a fresh real install has it, not just this dev checkout) - single source of truth, zero drift risk versus hand-copying the keybind list into QML.
- **Real testing-methodology bug caught and fixed (not a code bug):** the input reads initially showed "not" for every value - traced to my own manual Quickshell restarts this session never setting `HYPRLAND_INSTANCE_SIGNATURE`, which `hyprctl` needs (I'd only ever passed `XDG_RUNTIME_DIR`/`WAYLAND_DISPLAY`). Confirmed by restarting with the full three-variable environment - real values appeared correctly. The actual shipped feature is unaffected since Hyprland's own autostart hook sets this correctly for the real launch; this only affected my own manual test-restart commands. **Remember for any future hyprctl-dependent testing: always export `HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr/)` alongside the other two vars when manually restarting Quickshell.**

**Slice 5 DONE, live-verified on the Yoga 6, 7 Sept 2026 - Display's rollback timer, the last required acceptance criterion besides Accessibility:**
- Real monitor data via `hyprctl monitors -j` (name/resolution/refresh/scale/available modes), a real clickable mode picker, and a genuine 12-second "Keep these display settings? Reverting in Ns [Keep] [Revert]" banner - the exact safety mechanism the task's own spec calls for ("never make a bad monitor change permanently blank the display").
- **Real architecture finding mid-build:** `hyprctl keyword monitor ...` (the classic syntax) fails outright on this Hyprland build - `"keyword can't work with non-legacy parsers. Use eval."` - same Lua-config migration this project already hit for `hyprctl dispatch` (Task 9's finding). Researched the real replacement via the actual wiki source (`hyprwm/hyprland-wiki` on GitHub, not guessed): `hyprctl eval 'hl.monitor({ output = "...", mode = "...", position = "...", scale = ... })'`. Verified apply-then-revert manually over SSH, with zero QML involved, before writing a single line of the timer UI around it - given the explicit "never blank the display" stakes, proving the underlying mechanism first was worth the extra step.
- **Real bug found and fixed via live testing (not assumed away):** `Quickshell.execDetached()` is fire-and-forget - calling a monitor-state refresh immediately after issuing the revert command race ahead of the compositor actually applying it, so the panel's own displayed resolution text could go stale right after a real, successful revert (confirmed independently via `hyprctl monitors -j` that the revert itself always worked correctly - only the UI's redisplay of current state could lag). Fixed with a short (500ms) one-shot delay Timer before re-querying after any revert. **General pattern worth remembering for any future feature pairing `execDetached` with an immediate state re-query: don't trust the ordering, add a short buffer or move to a non-detached `Process` with a completion signal.**
- End-to-end flow (apply -> live countdown banner with real ticking seconds -> auto-revert) confirmed via a shortened test cycle (1s trigger, 3s countdown) with per-tick debug logging and strict single-process verification, plus the full-length real-timing (12s) cycle screenshotted mid-countdown showing the banner, countdown, and dimmed/disabled mode buttons correctly.

**Slice 6 DONE, live-verified on the Yoga 6, 7 Sept 2026 - search spot-check, one real bug found and fixed:**
- Traced the search logic by hand against the acceptance criteria's own 5 example queries before testing, and caught a real gap up front: the original single-contiguous-substring match would fail on "dark mode" (title is "Dark / Light mode" - "dark" and "mode" aren't adjacent). Fixed by splitting the query into words and requiring each word to appear somewhere across title+keywords combined, in any order - the standard, more forgiving fuzzy-search behavior a real user expects.
- All 5 example queries confirmed live via screenshot after the fix: "touchpad" → Keyboard & Mouse, "wifi" → Wi-Fi status, "dark mode" → Dark / Light mode, "snapshot" → Disk usage, "battery" → Battery status - each returning exactly the right result.

**Cross-cutting bug found and fixed 7 Sept 2026, while Akash tested search live on the Yoga 6 (not something either of us could have caught remotely - genuinely needed a real keyboard):** the Settings search box didn't accept typed input at all. Root cause turned out to be system-wide, not Settings-specific - **no custom QML text input anywhere in JAZZ has ever accepted real keyboard input**, confirmed by Akash testing the app launcher (Super+R) and the Notes widget too - neither worked either. Real cause: Quickshell `PanelWindow`s use wlr-layer-shell surfaces, which default to `WlrKeyboardFocus.None` (refuse all keyboard input at the Wayland protocol level) unless a panel explicitly opts in - confirmed against the real `quickshell-examples` GitHub source (`WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand`), not guessed. This is a bug in Task 22 (launcher) and Task 11b (Notes/To-do widgets) as much as Task 28 - fixed all three in the same pass: added `import Quickshell.Wayland` + `WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand` to the launcher and widget panels in `setup-dock.sh`'s `shell.qml` heredoc, and to `Settings.qml`. Confirmed working live by Akash after redeploy - typing now works in all three.

**Network + Bluetooth in-panel UI DONE, 7 Sept 2026 (Akash's request from the prior session end, built this session).** Replaced the old "open nmtui/bluetoothctl in a terminal" launchers with real native controls in `Settings.qml`, confirmed live on the Yoga 6 via screenshot (real Wi-Fi networks and real Bluetooth power state, not mock data):
- **Network**: live Wi-Fi radio on/off toggle (`nmcli radio wifi` — Akash asked for this explicitly, added to match Bluetooth's own toggle), real scanned network list (`nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list`) with a 4-bar signal indicator and a lock glyph on secured networks, connected network shown first with Disconnect/Forget, click-to-connect with an inline password field for secured networks (works thanks to the prior session's keyboard-focus fix), open networks connect directly.
- **Bluetooth**: live power on/off toggle, real paired-device list with Connect/Disconnect/Remove, a 6-second scripted scan (`bluetoothctl --timeout 6 scan on`) populating a Nearby list (paired devices excluded) with Pair, honest note that some devices need a physical confirmation to finish pairing.
- Both scripted via `bluetoothctl`/`nmcli` non-interactively (confirmed their exact CLI shapes live against this box's real `nmcli 1.58.1`/`bluetoothctl 5.87` before writing any QML — `bluetoothctl`'s modern non-interactive commands and its `--timeout` flag were confirmed via `--help`, not guessed).
- **Wi-Fi toggle click-tested live by Akash, initially failed, root cause found and fixed same session (not a code bug):** `nmcli device wifi connect`/`nmcli radio wifi` both failed with "Insufficient privileges"/"Not authorized" for Akash's real clicks too, confirmed via `journalctl` audit lines showing the real uid=1000 attempts being denied. Actual cause: the live Quickshell process at the time had been manually restarted over SSH (`nohup quickshell &`) during this session's own testing, which scoped it under the SSH login's logind session rather than the real seat0/Hyprland session (`session-c1.scope`) — NetworkManager's `network-control`/`enable-disable-wifi` polkit actions are `allow_active: yes` (no password) but only for the seat's genuinely active session, and the SSH-launched process didn't qualify. **Fix: relaunch Quickshell via `hyprctl dispatch 'hl.dsp.exec_cmd("quickshell")'` instead of a bare SSH `nohup`, so Hyprland itself spawns it inside its own session-c1.scope** — confirmed via `loginctl session-status c1` showing quickshell listed under the session's cgroup afterward, and a safe permission re-test (reconnecting to the already-active network) succeeding cleanly with no privilege error. Akash confirmed both the Wi-Fi toggle and Connect work live after this fix. **New standing rule for all future live-testing sessions: never leave a manually SSH-launched Quickshell process as the one Akash actually interacts with — always relaunch via `hyprctl dispatch exec` (or have Akash do a real Hyprland reload) before handing back control, or any active-session-gated action (NetworkManager, likely others) will silently fail.** Bluetooth never needed this — its control path (`bluetoothctl`/BlueZ D-Bus) has no polkit active-session gating at all.
- Pairing a real Bluetooth device end-to-end still hasn't been tested (no BT peripheral was on hand this session) — the Pair button chains `pair`/`trust`/`connect`, structurally consistent with the proven-working scan/list commands, but wants a real device nearby to confirm once.

**Privacy + Accessibility DONE, 7 Sept 2026 (Akash's request, built and confirmed live on the Yoga 6 via screenshot same session as the Network/Bluetooth fix above):**
- **Privacy**: real activity-trace counts and clear actions - clipboard history (`cliphist list`/`cliphist wipe`), recent-files list (`~/.local/share/recently-used.xbel`, count + delete), terminal command history (`~/.bash_history`, line count + truncate) - plus an honest static note ("JAZZ sends no telemetry... nothing leaves this machine unless you explicitly configure a cloud service") and a cross-reference to Agents (AI action history) and Security (firewall/SSH/encryption), rather than duplicating those.
- **Accessibility**: real reduce-motion toggle - added `Theme.qml`'s `reducedMotion` property and wired the top bar's `Behavior on color { enabled: !Theme.reducedMotion; ... }` (the one confirmed real animation, per the checklist below) - and, for UI scaling, **a real architecture win found live before writing any code**: rather than the previously-assumed "thread a scale token through every hardcoded pixel size" refactor, Hyprland's own per-monitor `scale` (already read, not yet exposed as a control, by the Displays tab) rescales the ENTIRE desktop including every Quickshell panel automatically, confirmed by testing `hyprctl eval 'hl.monitor({... scale = 1.2 })'` live and screenshotting the whole UI (top bar/dock/widgets) visibly larger. Accessibility's Text & UI Size control is just five preset buttons (100/115/125/150/175%) reusing that exact mechanism plus the same 12-second Keep/Revert safety timer already proven in Displays (a bad scale is the same "never permanently break the display" risk class as a bad resolution) - no big refactor needed after all.
- Both sections' `real` flag flipped true, confirmed via screenshot (no more "•" pending marker in the sidebar for either).
- Scale-button clicking and the reduce-motion toggle weren't click-tested live this session (only screenshotted in their default state) - same category as the Network/Bluetooth gap two sections up; low risk since both reuse already-proven mechanisms (Displays' scale/timer pattern, the darkMode/Bluetooth toggle pattern), but worth a quick real click if Akash wants full confidence.

**Developer's deeper tools DONE, 7 Sept 2026 (Akash's request, built and confirmed live on the Yoga 6 via screenshot same session):**
- **Hyprland Event Log**: a real live feed of Hyprland's own IPC event stream (`.socket2.sock` - the same socket every status bar/widget ecosystem reads from), captured via a new tiny stdlib-only script (`configs/quickshell/jazz-hypr-events.py`, deployed by `setup-settings.sh` alongside Keybinds.md) rather than installing `socat`/`nc` (neither was on the box) - Python's own `socket` module connects to the AF_UNIX socket directly, same "no new dependency" precedent as `scan-apps.py`/`jazz-agent-action`. Runs only while the Developer tab is open (`running: developerTab.visible`), rolling 40-line buffer, auto-scrolls, Clear button. Confirmed live: triggered two real `hyprctl dispatch` workspace switches and watched the exact real events (`createworkspace>>Lab`, `workspace>>Lab`, `destroyworkspace>>Forge`, ...) appear.
- **D-Bus Inspector**: real session-bus service list (`busctl --user list`, confirmed 59 real services live - Hyprland, Quickshell, dunst, wireplumber, xdg-desktop-portal, etc.), click a row to inspect its object tree (`busctl --user tree <name>`, confirmed fast/safe with a `timeout 3` guard).
- Developer Mode toggle re-tested both directions again after adding this (enabled to test, disabled again before handing back) - unaffected, still works correctly both ways.
- Developer section's `real` flag flipped true. **All 18 of 18 Task 28 Settings sections are now real - the task's full section-coverage acceptance criterion is met.**

**Reduced-motion checklist added 7 Sept 2026 (`Operating_UX_UI_Blueprint.md` §54, Akash's request, analyzed same session)** - concrete things for the eventual reduced-motion toggle to actually gate, once built: the top bar's workspace-color `ColorAnimation` (confirmed real, already exists in `shell.qml`'s `topBar`), dock hover/magnification effects (if added later per the same doc's dock spec, not yet built), any future wallpaper-transition/AI-pulsing effects. Recorded so the toggle has real, known targets instead of being scoped blind.

**Acceptance criteria (full task - all met):**
- [x] Every listed section exists as a real tab/page in the settings app, backed by real live data wherever a Track A/B/C script already exposes that data — **18 of 18 sections real, confirmed 7 Sept 2026**
- [x] Settings search returns correct results for at least 5 real spot-check queries — all 5 confirmed live 7 Sept 2026, one real word-matching bug found and fixed along the way
- [x] Displays changes have a working rollback timer, confirmed live — apply/countdown/auto-revert and explicit Keep/Revert all confirmed live on real hardware, 7 Sept 2026
- [x] Accessibility section has real, working controls (not stubs) for at least reduced motion and UI scaling — DONE, confirmed live via screenshot; reduced motion gates the top bar's `ColorAnimation`, UI scaling reuses Displays' real `hl.monitor` scale mechanism + rollback timer (no big refactor needed - see slice note above)
- [x] Developer section is hidden by default, toggleable, and never shown to a fresh install without explicit enablement — confirmed live both directions
- [x] Terminal remains fully functional for every setting this app exposes — this app is additive, not a terminal replacement — unchanged, still true

**Verification:** Live, on the Yoga 6 (real hardware) - slice 1 confirmed 7 Sept 2026 via direct screenshots of every new/changed section

**Dependencies:** Task 22 (existing settings panel, extended not replaced)

**Files likely touched:** `configs/quickshell/Settings.qml` (new, was going to be shell.qml growth), `scripts/setup-settings.sh` (new), `scripts/setup-dock.sh` (Settings block replaced with a Loader), `scripts/install-jazz.sh` (chained), `scripts/jazz-agent-action` (new `policy` subcommand)

**Estimated scope:** L — real architecture growth of an already-large surface, likely the biggest single JAZZ task yet. First slice done; remaining slices are each roughly S-M.

---

### Task 29: Jazz Files — real GUI file manager (v1, no AI)

**Description:** Not part of the original 20-task plan; scoped 7 Sept 2026 from `docs/JAZZ-v2.md` sec 5a, after Akash's explicit direction that JAZZ must have a real GUI-based file system, going further than Omarchy in this specific area (confirmed live 7 Sept 2026: Omarchy's file manager is plain themed/keybound Nautilus). JAZZ currently has no file-manager story of its own at all (Dolphin, launched via Task 21's `Super+E` keybind, completely stock, zero integration) — actually a step behind Omarchy's current state. This task is v1: real file management only, no AI features (those are a deliberate separate follow-on — see `docs/JAZZ-v2.md` sec 5a — matching the source blueprint's own advice not to build semantic AI until basic file management is reliable).

**Dolphin/`Super+E` wiring confirmed live 7 Sept 2026 (`~/.config/hypr/hyprland.lua`):** trivial to retire — a single `local fileManager = "dolphin"` variable feeding one bind, `hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))`. No other config, desktop-file association, or wiring depends on Dolphin specifically. Retiring it later is a one-line change (point `fileManager` at Jazz Files' launch command instead) - no cleanup risk.

**Scope (v1):** browse, Grid/List view modes, Recent, Home/Documents/Downloads/Pictures/Videos/Music/Projects sidebar, copy/move/rename/create-folder/open/open-with/properties, delete-to-trash + restore, a real preview pane (image/text/Markdown/PDF at minimum — audio/video/archive preview can slip to a follow-on if genuinely harder), a device sidebar aware of Btrfs (used/available/filesystem/health, mount/unmount/eject), GUI-translated Linux permissions ("You: Read and Write" instead of raw mode bits, with an advanced view for real uid/gid/mode), and a real file-operation transaction log powering Undo for move/rename/batch-organize/delete-to-trash — explicitly **not** the same mechanism as Snapper's system snapshots (user-file undo and OS-snapshot undo are different and shouldn't be conflated).

**Quick Look interaction spec added 7 Sept 2026 (`Operating_UX_UI_Blueprint.md` §23, Akash's request, analyzed same session):** the preview pane's real trigger should be pressing `Space` on a selected file for an instant full preview overlay, `Escape` to close - sharpens the existing preview-pane requirement below rather than adding new scope.

**Acceptance criteria:**
- [ ] All v1 operations (browse/copy/move/rename/trash/restore/create-folder/properties) work correctly on real files, confirmed live
- [ ] Grid and List views both render correctly with real files (images in Grid, source/documents in List with name/type/size/modified/owner columns)
- [ ] Preview pane works for at least image/text/Markdown/PDF, reachable via `Space` on a selected file (Quick Look), `Escape` to close
- [ ] Device sidebar shows real Btrfs volume info and mount/unmount/eject work live
- [ ] Permissions are shown in translated form by default, with a working advanced/raw view
- [ ] Undo works for at least move/rename/delete-to-trash, via a real transaction log (not Snapper)
- [ ] Dolphin's existing `Super+E` keybind is retired in favor of Jazz Files, or clearly repurposed — no dangling reference to the old placeholder

**Verification:** Live, on the Yoga 6 (real hardware)

**Dependencies:** Task 21 (own config, to rebind the keybind), Task 22 (existing `.desktop`-scan/icon-resolution infra this can reuse for "Open With")

**Files likely touched:** new `configs/quickshell/Files/*.qml`, `scripts/setup-files.sh` (new), `scripts/install-jazz.sh` (chain updated), `scripts/setup-hyprland.sh` (keybind change)

**Estimated scope:** L — genuinely large, comparable to or bigger than Task 22's dock/launcher/settings build

---

### Task 30: Agent permission tiers + Checkpoint → Act → Undo

**Description:** Not part of the original 20-task plan; scoped 7 Sept 2026 from `docs/JAZZ-v2.md` sec 5c, promoted early (ahead of any specific AI-action feature) because it's the safety foundation every AI-driven idea in the v2 backlog depends on — the fully-local NL OS control idea (`docs/JAZZ-v2.md` sec 4b) was explicitly missing this piece when first written, and Jazz Files' eventual AI actions (organize/rename/summarize, sec 5a follow-on) will need it too. Deliberately built as a plain script wrapper around Track A's already-working Snapper infrastructure — no Rust service, no new daemon (per the confirmed architecture decision, 7 Sept 2026: stay lightweight, promote to a real service only if it earns it).

**Scope:** A `jazz-agent-action` wrapper (or equivalent) that any future AI-driven script/feature calls instead of acting directly: classify the requested action into a tier (**Green** = auto-execute — launch app, change volume, read status, search approved folders; **Yellow** = confirm — move many files, install a package, close an app, change a setting; **Red** = strong explicit authorization — sudo, disk format, security-policy change, delete system files), create a Snapper checkpoint before anything Yellow/Red, perform the action, verify it took effect, log to a simple activity ledger (what/why/files touched/commands run/snapshot ID/timestamp), and expose Undo. A minimal Quickshell surface (the Agents tab in Task 28's Jazz Settings) shows the ledger and lets a user set default policy (allow/ask/deny) per action type.

**Status: DONE as of 7 Sept 2026.** Built as `scripts/jazz-agent-action` (Python 3, stdlib only - no new dependency), installed via `scripts/setup-agent-safety.sh`, chained into `install-jazz.sh` right after Track A's Snapper setup. `scripts/verify/agent-safety.sh`: **6/6 passed live on the Yoga 6.**

**Real design decision made during implementation, worth remembering:** Undo uses `snapper undochange <pre>..<post>` (a live diff-reverse between two bracketing snapshots), NOT `snapper rollback` - rollback needs a full subvolume swap + reboot and is already confirmed broken on JAZZ's fstab layout (Task 8's finding, see `rollback-manual.sh`). `undochange` has no such dependency - live-tested directly before writing any wrapper code (created a real file, two snapshots, ran `undochange`, confirmed the file reverted) to make sure the mechanism was sound before building on it.

**Acceptance criteria:**
- [x] Tier classification exists for at least the action types listed above, documented
- [x] A Yellow/Red-tier test action creates a real Snapper checkpoint before running, confirmed via `snapper list`
- [x] The activity ledger records real entries (what/why/files/commands/snapshot ID/timestamp) for a real test action, readable by the user
- [x] Undo works end-to-end for at least one real logged action
- [x] A Green-tier action runs with zero prompts; a Yellow-tier action is blocked until confirmed; a Red-tier action requires explicit strong confirmation — all three confirmed live, not just described

**One real bug caught during live verification (test bug, not tool bug):** the verify script's red-tier block check grepped output for the blocked command's text, which false-failed because the tool legitimately echoes back the command it refused to run (for transparency) - fixed by checking the documented exit code (3) instead of grepping content.

**Verification:** Live, on the Yoga 6 (real hardware) - confirmed 7 Sept 2026

**Dependencies:** Track A (Snapper, already working), Task 28 (Agents tab to surface the ledger/policy UI — backend can be built first, UI wired in once Task 28 lands, in either order)

**Files likely touched:** `scripts/setup-agent-safety.sh` (new) or similar, `scripts/install-jazz.sh` (chain updated), `configs/quickshell/shell.qml` (Agents tab ledger UI, once Task 28 exists)

**Estimated scope:** M — conceptually simple, but real correctness matters here more than almost anywhere else in the project (this is a safety mechanism, not a feature)

---

### Task 31: Decouple JAZZ's own chrome size from monitor scale — **DONE, 8 Sept 2026**

**Description:** Not part of the original plan; found live 8 Sept 2026 while investigating Akash's report that Firefox/apps "look too enlarged." Root cause: `hyprland.lua`'s monitor config used `scale = "auto"`, and Hyprland's auto-detection picked 1.5x for this 1920x1080 13.3" panel (~166 PPI - not really high-DPI, doesn't need scaling). Fixed the monitor scale to 1.0 (correct for this panel - GTK/Qt apps now render at proper density, confirmed live). But JAZZ's own Quickshell panels (top bar/dock/Settings/Command Centre) are Wayland surfaces too, so they scale with the compositor the same way - dropping to 1.0x shrank them to ~67% of their previous on-screen size, since every dimension in `shell.qml`/`Settings.qml` was implicitly tuned assuming a 1.5x compositor scale.

**Real architecture problem, not just a number to tweak:** a single monitor-scale value can't simultaneously give apps correct density AND keep JAZZ's own chrome at a deliberately-chosen size - those need to be decoupled. Monitor scale should stay correct (1.0x here) for every third-party app; JAZZ's own UI dimensions need to be real, deliberately-chosen pixel values that don't depend on whatever the monitor's auto-detected scale happens to be.

**Mechanism:** wrote `scripts/../rescale_qml.py`-style regex transform (scratch, not committed - one-off) that scales bare-integer literals on a curated property list (`implicitHeight`/`implicitWidth`/`width`/`height`/`radius`/`spacing`/`font.pixelSize`/`anchors.*Margin*`) by ×1.5, explicitly excluding `border.width` (hairline borders shouldn't scale) and skipping anything that's part of a larger expression (e.g. `parent.width - 240`) rather than a bare literal - those need separate manual review since scaling them naively could corrupt the arithmetic. Applied to `shell.qml` (218 replacements), `Settings.qml` (305), then the 4 shared `ui/` components (16 more) after Akash caught the sidebar looking undersized - `ui/ListRow.qml`/`Button.qml`/`Toggle.qml`/`SectionHeader.qml` were missed in the first pass since they're separate files the regex script wasn't pointed at.

**Two real follow-up fixes needed after the bulk regex pass, both found via live visual inspection, not assumed correct:**
1. Two hardcoded arithmetic expressions (`parent.height - 90` reserving space below the chat message list, `parent.width - 90` reserving space for the Send button) were correctly skipped by the regex but were now wrong given everything around them grew - manually updated to `- 135` (90×1.5) each. Caught because the Send button was visibly clipped by the now-taller dock.
2. `Settings.qml`'s sidebar `height: parent.height - 44` had the same issue, fixed to `- 66`.
3. The 4 shared `ui/*.qml` components (`ListRow`, `Button`, `Toggle`, `SectionHeader`) were missed in the first pass entirely (regex was only pointed at `shell.qml`/`Settings.qml`) - caught live by Akash ("the settings tab sidebar is smaller, other side is fine"), since `ListRow` backs every sidebar tab. Fixed the same way; `Button.qml`'s `property int fontSize: 10` default also needed a manual bump to 15 since it's a property declaration, not a `font.pixelSize:` binding the regex targets.

**Acceptance criteria:**
- [x] Monitor scale confirmed at 1.0x, apps render at proper density - confirmed live
- [x] Top bar, dock, Settings panel, and Command Centre all resized back to a comparable on-screen size to before, independent of monitor scale
- [x] No broken/overlapping layouts introduced by the resize - live visual check across Settings' tabs, Command Centre, and the shared `ui/` components; two real clipping bugs and one undersized-sidebar bug found and fixed
- [x] Persisted `hyprland.lua`'s `scale = "auto"` replaced with an explicit `scale = 1.0`, both live and in the repo's `setup-hyprland.sh` source

**Verification:** Live, on the Yoga 6 - visual confirmation via screenshot across top bar/dock/Settings/Command Centre, Akash's own live feedback caught two real bugs (chat clipping, sidebar undersized) that a screenshot-only pass would have missed
**Dependencies:** none (found and worked live, current session)
**Files touched:** `scripts/setup-dock.sh` (shell.qml heredoc), `configs/quickshell/Settings.qml`, `configs/quickshell/ui/{Button,Toggle,ListRow,SectionHeader}.qml`, `scripts/setup-hyprland.sh` (persisted monitor scale)
**Estimated scope:** M-L - touched most of shell.qml/Settings.qml's dimension literals plus all 4 shared components

---

### Task 32: User management (Settings' new Users tab)
**Description:** Not part of the original plan; raised by Akash 12 Sept 2026 alongside the hyprlock username-label fix - the lock screen should show whose account it is, and Settings should let a user change their own password and add additional system users, rather than only ever having the one account `archinstall` created.

**Real findings, checked live before writing this spec (12 Sept 2026):**
- `passwd`, `chpasswd`, `useradd`, `userdel` are all standard `shadow`-package binaries, already present (core system tooling, not something to install).
- **pkexec/polkit tried live and abandoned - real compatibility gap, not a config mistake.** Installed and autostarted `polkit-kde-agent`, confirmed it registers with `polkitd` and `pkexec` genuinely reaches it (spawns a real `polkit-agent-helper-1` process) - but no graphical dialog ever renders under plain Hyprland, leaving `pkexec` hanging indefinitely. Tried a second, lighter agent (`lxqt-policykit-agent`, official repo, far fewer Plasma dependencies) - same result, still no visible dialog. Both are almost certainly built assuming a full desktop environment (Plasma/LXQt) provides some window-management piece Hyprland alone doesn't. **Real incident from this:** each hung `pkexec` attempt registered as a PAM auth failure via `pam_faillock` (source `polkit-1` in `faillock --user holycowstudios`), and with this install's `deny=3` policy, three hung attempts locked the account out of SSH **and sudo** for about 10 minutes - a real, if temporary, lockout caused directly by this experimentation, not by a wrong password. Confirmed via `faillock`'s own log timestamps.
- **Adopted instead: the same terminal+sudo pattern Task 16b/30 already use in this project.** Privileged actions (add/remove user, admin toggle) open a real `kitty --hold -e sudo <script> ...` window - a genuine, visible `[sudo] password for holycowstudios:` prompt the user types into directly, no polkit/pkexec/GUI-agent dependency at all. Tested live end-to-end (a disposable `jazztest5` account created successfully this way) - confirmed working on the first real try, unlike either polkit agent. This is arguably a *stronger* safeguard than a polkit dialog anyway: it's the exact same mechanism every Linux user already trusts, with zero new attack surface.
- Self-service password change (a user changing their OWN password) needs no root/sudo/pkexec at all - `passwd` is setuid and already permits this. **Confirmed live** against disposable test accounts (never the real `holycowstudios` login): `passwd` genuinely accepts its three interactive prompts (current/new/confirm) via piped stdin, no real TTY needed - a wrong current password is correctly rejected with real PAM error text surfaced back to the caller.
- Adding/removing a system user is unambiguously a **Red tier** action per Task 30's own permission model (creates real accounts, home directories, touches `/etc/passwd`/`/etc/shadow`) - goes through the terminal+sudo prompt above for a real, strong authentication moment, not a hardcoded `NOPASSWD` sudoers entry.
- **Follow-up research, same day, for additional features Akash asked about:**
  - `accountsservice` (26.27.3-1) is confirmed official `extra` repo - and **already installed** on this machine (a pre-existing dependency, not something new to add). Its daemon (`accounts-daemon.service`) is loaded but currently disabled/inactive - would need enabling. This is the standard mechanism (`org.freedesktop.Accounts` D-Bus API, what GNOME/KDE both use) for a real display name (GECOS full name) and a per-user avatar image, stored at `/var/lib/AccountsService/icons/<username>`.
  - `hypridle` (0.1.8-2) is confirmed official `extra` repo - NOT currently installed, but a clean add (Hyprland's own idle-daemon, official upstream project, same family as hyprlock) for an idle auto-lock timeout feature.
  - `ly` (the greeter, 1.4.1-1, already installed) genuinely supports auto-login via `/etc/ly/config.ini`'s `auto_login_user`/`auto_login_session` keys (confirmed by reading `config.ini.example`'s real documented options, not guessed) - a real, low-risk feature for a single-user machine.
  - **Real finding: self-service `chfn` is blocked on this install** by `login.defs`' `CHFN_RESTRICT` setting, even for a user changing their OWN display name (`chfn: login.defs forbids setting Name`, confirmed live) - `usermod -c` works with root, so display-name changes go through the same terminal+sudo path even when a user is setting their own name.

**Real backend scripts already built and tested live (12 Sept 2026), against disposable test accounts only:**
- `scripts/jazz-user-add <username> <full-name> <initial-password> <admin: yes|no>` - `useradd -m -c`, `chpasswd`, optional `usermod -aG wheel`. Runs as root (invoked via the terminal+sudo pattern).
- `scripts/jazz-user-remove <username> <keep-home: yes|no>` - `userdel` or `userdel -r`. Runs as root.
- `scripts/jazz-user-set <username> --displayname NAME | --admin yes|no` - `usermod -c` / `usermod -aG wheel` / `gpasswd -d wheel`. Runs as root.
- `scripts/jazz-user-passwd <current-password> <new-password>` - self-service, no root needed, surfaces `passwd`'s real PAM error text on failure.
- All four confirmed live: user creation, admin grant/revoke (`groups` before/after), display-name change, self-service password change (success AND correct-rejection-of-wrong-password cases), and removal with `keep-home=no` genuinely deleting the home directory (`keep-home=yes` path also confirmed separately, home directory correctly survives `userdel` without `-r`).

**Scope:**
1. ~~Autostart a polkit authentication agent~~ - abandoned, see findings above. No polkit agent is autostarted; the `hyprland.lua` block that briefly did this was removed.
2. New "Users" tab in Jazz Settings: lists real system users (via `getent passwd` filtered to real login-shell accounts, not system/service accounts), a "Change my password" form (current/new/confirm, calls `jazz-user-passwd` directly - no elevation), an "Add user" form (username, full name, initial password, admin-or-not) that opens a `kitty --hold -e sudo jazz-user-add ...` terminal, and a remove-user action (same terminal+sudo pattern, with a strong explicit confirmation dialog first - this deletes a real home directory) that explicitly asks whether to keep or delete the home directory (`userdel` vs `userdel -r`) rather than silently picking one.
3. **Display name (GECOS full name)** - editable per-user, shown instead of the raw Linux username on the lock screen greeting ("Welcome, Akash" instead of "Welcome, holycowstudios") and in Settings/top bar where the username currently shows. Backed by `chfn`/`usermod -c` or directly via `accounts-daemon`'s D-Bus API once enabled.
4. **Avatar** - a per-user profile picture, set via `accountsservice` (enable `accounts-daemon.service` first), shown on the lock screen and in Settings' Users tab. Needs a real image-picker flow (file browser or Jazz Files once Task 29 exists) and a sane fallback (initials or a generic icon) for users with none set.
5. **Idle auto-lock** - install `hypridle`, configure a real idle timeout that calls `hyprlock` automatically (and optionally dims/locks the screen off entirely after a longer second timeout), with the timeout itself configurable from the Users tab (or a Security/Privacy section, TBD during implementation).
6. **Auto-login toggle** - a per-user switch writing `ly`'s `auto_login_user`/`auto_login_session` config keys, with a clear warning in the UI that this skips the login password prompt entirely (real security tradeoff, not hidden from the user).
7. **Toggle admin (sudo/`wheel` group) access** for an *existing* user, not just at creation time - `usermod -aG wheel <user>` / removal from the group, via the same terminal+sudo pattern as add/remove.
8. New backend scripts - `jazz-user-add`/`jazz-user-remove`/`jazz-user-set`/`jazz-user-passwd` - **built and live-tested already** (see above), called via `Quickshell.execDetached(["kitty", "--hold", "-e", "sudo", ...])` for the three that need root, and directly (no elevation) for `jazz-user-passwd`.
9. Update hyprlock's username label (already shipped, Task 27b) to read the real display name once set (falling back to the raw username if none), and to read the *actual currently-locked* user if JAZZ ever supports fast user switching - not required for v1 (single real desktop user is the common case), noted so it isn't forgotten if multi-user switching is ever built.
10. **Fixed 12 Sept 2026, found during a live audit of a second real non-admin account (`anve`):** "Revoke admin"/"Remove" were visually enabled for a non-admin viewer, even though the backend already refused them (`sudo` rejects anyone not in `wheel`, correct password or not - confirmed live testing as `anve`, no actual security gap). Still real UX debt - a non-admin saw buttons that would always fail. Added a `usersTab.viewerIsAdmin` check (derived from the same `userList` the tab already fetches) and gated both buttons behind it, replacing them with "Only admins can manage users" for a non-admin viewer. Confirmed live via screenshot as `anve` post-fix.
11. **Real multi-user bug found and fixed 12 Sept 2026: `jazz-wallpaper-set` used a single shared `/tmp/jazz-swaybg.log` for every user's swaybg stdout/stderr redirect.** Whichever user's swaybg ran first "owned" that file (default mode 644, not group-writable); every other user's `>` redirect then failed with `Permission denied` before swaybg could even launch - no crash, no visible error, the screen just kept showing whatever was already composited. Found live: after switching from `anve` back to `holycowstudios` at the console and checking Settings, the theme picker correctly showed "Forge" selected but the actual desktop was still showing `anve`'s last-rendered Midnight wallpaper - `anve` had created `/tmp/jazz-swaybg.log` first, blocking `holycowstudios`'s own swaybg from starting at all. Fixed by using `${XDG_RUNTIME_DIR}/jazz-swaybg.log` instead (per-user, mode 700, already exported by Hyprland - can't collide). Confirmed live: `holycowstudios`'s Forge wallpaper now renders correctly, and Akash confirmed the Settings wallpaper picker works again after the fix.
    - **Real incident during this fix, worth recording as a standing lesson:** redeploying the fixed script via `echo "$PASSWORD" | sudo -S tee /path <<'EOF' ... EOF` hijacked `sudo -S`'s stdin with the heredoc instead of the piped password - `sudo` fell back to an interactive prompt, got fed the heredoc's own script body as failed password attempts, and `pam_faillock` locked `holycowstudios` out of **both sudo and SSH** for several minutes (same mechanism as Task 32's earlier pkexec-driven lockout, different trigger). No password was changed or at risk - purely an auth-attempt-count lockout. Akash cleared it himself at the console (`faillock --user holycowstudios --reset`) rather than waiting it out. **Lesson: never combine a piped `sudo -S` password with a heredoc body in the same command** - write the file locally and `pscp`/`install` it instead, exactly like the fix that actually worked afterward.

**Session of 14 Sept 2026 - idle auto-lock, auto-login toggle, display name UI, and a real reproducibility gap fixed:**
- **Real audit finding, checked before doing any new work: the Users tab UI (password change, add user, remove user, admin toggle) was already fully built and wired** - not a stub, a real in-app sudo popup (`sudoActionProc`, `requestSudo()`/`runPendingCommand()`) replaced the earlier kitty-terminal approach after Akash's feedback that a terminal opening behind Settings was confusing. The acceptance-criteria checkboxes below were simply stale relative to the actual code - corrected here after reading the real `Settings.qml`, not assumed from the checklist.
- **Real reproducibility gap found and fixed: `jazz-theme-set`, `jazz-font-set`, and all four `jazz-user-*` scripts existed on the live Yoga 6's `/usr/local/bin` but were never actually installed there by any committed setup script** - confirmed via `grep -r "install -Dm755" scripts/` finding only `jazz-agent-action`'s own line. They'd only ever reached the guest by hand during interactive sessions. A clean clone (Task 20's own bar) would have silently shipped a system where none of these were callable. Fixed with a new `scripts/setup-jazz-bin.sh` (installs all six to `/usr/local/bin`), chained into `install-jazz.sh` right after `setup-jazz-repo.sh`.
- **Idle auto-lock (hypridle) - built, deployed, confirmed live.** `hypridle` confirmed official `extra` repo. Real syntax taken from its own bundled `/usr/share/hypr/hypridle.conf` sample on this install (already adapted to this fork's `hl.dsp.dpms({action=...})` dispatch syntax), not guessed. **Mechanism verified live before writing any script**: a real 12-second test listener genuinely triggered `hyprlock` and locked a real Wayland session (hypridle's own log: "Wayland session got locked"). New `scripts/jazz-idle-set` (self-service, no root - mirrors `jazz-theme-set`'s `$JAZZ_DATA_DIR`/regenerate-and-restart pattern) writes `idle-settings.json` + regenerates `hypridle.conf`, defaulting to 10 minutes, enabled. New `scripts/setup-hypridle.sh` installs the package, seeds the default (only if no settings file exists yet - won't clobber a user's own choice on re-run), and wires `hl.on("hyprland.start", ...)` autostart into `hyprland.lua`. Chained into both `install-jazz.sh` and `jazz-user-add`'s per-user loop. Settings UI (Users tab, "IDLE LOCK" section) confirmed live via screenshot showing real loaded state ("Locks after 10 minutes of inactivity.").
- **Real incident during this work, cleanly resolved: killing a test `hyprlock` via `pkill` (instead of letting it exit through Hyprland's own session-lock protocol) left the compositor stuck on its "lockscreen app died" crash-fallback screen** - Akash caught this live ("yoga 6 screen is locked?"). Fixed immediately with Hyprland's own documented recovery call, `hyprctl eval 'hl.clear_crashed_lockscreen()'`, confirmed via a follow-up screenshot showing the real desktop restored. **Lesson applied to `jazz-idle-set` itself: its restart logic only ever `pkill`s `hypridle`, never `hyprlock`** - hyprlock's own lifecycle must always go through its real client protocol, not be killed out from under Hyprland.
- **Auto-login toggle - built, deployed, confirmed live.** Real config keys confirmed by reading `/etc/ly/config.ini`'s own bundled comments: `auto_login_user` + `auto_login_session` (the latter must be a `.desktop` filename from `/usr/share/wayland-sessions/` minus extension - `hyprland`, this system's only session) must both be set; ly's own doc note ("Autologin only happens once at startup - it won't re-trigger after logout") is surfaced verbatim in the UI's confirmation warning, not hidden. `jazz-user-set` extended with a `--autologin yes|no` action (root-gated, Red-tier, via the existing sudo-popup mechanism - no new authorization path). Since ly supports exactly one auto-login user, setting it for one account naturally supersedes any other - no extra cleanup logic needed. Settings UI adds a per-user-row "Auto-login: on/off" indicator + toggle button, admin-only, with the full tradeoff warning in the confirmation text. **Confirmed live end-to-end** (bypassing the UI's own click, since no click-simulator exists over SSH): ran `jazz-user-set anve --autologin yes`, confirmed `/etc/ly/config.ini` updated correctly, then reverted to `no` and confirmed it cleared - left the system in its original off state.
- **Display name self-service UI - built, deployed, confirmed live via screenshot.** Backend (`jazz-user-set --displayname`) already existed from the 12 Sept session; only the Settings UI form was missing. New "MY DISPLAY NAME" section, pre-fills the field from the real GECOS name already being fetched for the Users list (confirmed live: showed "Akash N..." for holycowstudios), Save routes through the same sudo popup (needed even for your own name - `chfn` self-service is blocked by this system's `login.defs`, confirmed 12 Sept).
- Avatar (accountsservice-based profile picture) is the one remaining item from this task's original scope, not started - needs either enabling `accounts-daemon.service` + its D-Bus API, or a simpler JAZZ-owned scheme storing the image under `$JAZZ_DATA_DIR` directly (leaning toward the latter to avoid a new daemon dependency and because there's no file-picker UI to select an image from until Task 29/Jazz Files exists - a plain text path field is the only realistic v1 short of that).

**Acceptance criteria:**
- [x] Privileged actions (add/remove/admin-toggle) use a real, working authorization mechanism - terminal+sudo, confirmed live end-to-end (polkit/pkexec tried and abandoned, see findings above)
- [x] A user can change their own password via Settings UI, wired to the already-tested `jazz-user-passwd` script - confirmed built and live via screenshot, 14 Sept 2026 (todo.md checkbox was stale, code was already done)
- [x] An admin can add a new real system user via the Settings UI - confirmed built and live via screenshot, 14 Sept 2026 (todo.md checkbox was stale, code was already done)
- [x] Removing a user requires strong explicit confirmation, explicitly asks about keeping vs deleting the home directory - confirmed built and live via screenshot, 14 Sept 2026 (todo.md checkbox was stale, code was already done)
- [x] Users tab lists real accounts, not a hardcoded/fake list - confirmed live via screenshot (holycowstudios + anve, real GECOS names, real admin status)
- [x] A user can set a display name and it shows on the lock screen - `jazz-theme-set`'s hyprlock label extended 14 Sept 2026 to prefer GECOS display name over raw username (falls back to username when unset, `sed "s/^$/$(whoami)/"`), verified correct for both cases (`Akash Navet` for holycowstudios, `anve` for the no-display-name account) by running the exact pipeline directly over SSH and confirmed written into the real deployed `hyprlock.conf`. Not confirmed via an actual lock-screen screenshot - deliberately avoided re-triggering a real `hyprlock` this session after the crash-recovery incident above, to not risk locking the physical machine again; worth a quick visual confirmation next time Akash is at the console.
- [ ] A user can set an avatar and it shows on the lock screen and in Settings, with a sane fallback when unset
- [x] Idle auto-lock genuinely triggers `hyprlock` after the configured timeout, confirmed live 14 Sept 2026 (real 12s test listener, watched `hyprlock` actually lock the session)
- [x] Auto-login toggle genuinely skips `ly`'s password prompt on next boot when enabled, confirmed live 14 Sept 2026 (config file verified before/after, with a clear on-screen tradeoff warning) - a real physical reboot to confirm the login-prompt skip itself wasn't done (left off afterward, by design, to avoid leaving the machine passwordless)
- [x] Admin (wheel group) access can be toggled for an existing user via the Settings UI - confirmed built and live via screenshot, 14 Sept 2026 (todo.md checkbox was stale, code was already done)

**Dependencies:** Task 28 (Jazz Settings, to add the tab to), Task 30 (permission-tier precedent for the Red-tier add/remove/admin-toggle actions)
**Files likely touched:** `configs/quickshell/Settings.qml` (Users tab - display name, idle lock, auto-login sections added 14 Sept), `scripts/jazz-user-add`/`scripts/jazz-user-remove`/`scripts/jazz-user-set`(`--autologin` added)/`scripts/jazz-user-passwd`, `scripts/jazz-idle-set` (new), `scripts/setup-hypridle.sh` (new), `scripts/setup-jazz-bin.sh` (new - closes the `/usr/local/bin` reproducibility gap), `scripts/install-jazz.sh`/`scripts/jazz-user-add` (both updated to chain the above), `scripts/jazz-theme-set` (hyprlock username label extended to prefer display name, 14 Sept)
**Estimated scope:** L - backend scripts done and live-tested; UI fully wired; only avatar (accountsservice or JAZZ-owned image path + a way to pick a file before Jazz Files exists) remains

---

### Task 33: Boot-to-desktop branding chain + first-boot Welcome app

**Description:** Not part of the original plan; scoped 12 Sept 2026 after researching how comparable Arch-based distros (Omarchy, EndeavourOS, Garuda, Manjaro, CachyOS) brand the stretch from power-on to a usable desktop, and confirming live that JAZZ currently has none of it. JAZZ's own theme system (`jazz-theme-set`) already threads one accent/palette through kitty/hyprlock/dunst/Kvantum/GTK3 in one shot (Task 27b/27e) - this task extends that same "set once, propagates everywhere" property to the two pieces still outside it (boot splash, login greeter), and adds the first-boot welcome experience every comparable distro has that JAZZ currently lacks entirely.

**Real findings, confirmed live on the Yoga 6 before writing this spec (not assumed):**
- `plymouth` is **not installed** (`pacman -Qi plymouth` fails) - JAZZ boots with plain kernel text output, no splash screen at all, right up until Hyprland/Quickshell appears.
- No `splash`/`quiet` kernel params are set, and `mkinitcpio.conf` has no `plymouth` hook.
- `ly` (the TUI login greeter, already installed since Task 4) has real built-in animation modes (`animation = matrix|colormix|doom|game_of_life|none` in `/etc/ly/config.ini`) but is currently set to `none` - completely unthemed, never touched by any JAZZ script.
- There is no first-boot welcome app or equivalent of any kind - a brand-new JAZZ user's first real interaction with the desktop is just the empty Forge workspace, no onboarding at all.
- **Omarchy's real mechanism, confirmed via its own manual:** `omarchy plymouth set` applies one logo + one color palette to Plymouth's boot splash AND SDDM's login screen together (`omarchy plymouth preview` to try first, `omarchy plymouth reset` to revert); a companion `omarchy transcode ascii` command converts a logo into ASCII/braille/block art for terminal-side branding (used for a themed `fastfetch` banner - CachyOS does the same with a custom `fastfetch` logo + `os-release`). This single-command "propagate everywhere" pattern is exactly what `jazz-theme-set` already does for JAZZ's desktop-side configs - Plymouth/`ly` are the two real gaps in that same pipeline, not a new mechanism to invent.
- **First-boot welcome apps are near-universal** across comparable distros, each a small standalone app: EndeavourOS's "Welcome" (setup tips/driver tools/doc links, shown in both the live installer and first real boot, toggled via `Hidden=true/false` in its autostart `.desktop`), Garuda's "Setup Assistant" (prompts to open on first boot, walks through system update + curated optional-software picks with real descriptions), Manjaro Hello (Python/GTK3, same autostart-toggle convention), CachyOS's "cachyos-hello"/newer "nabu-welcome" (GTK4, also launchable anytime from the app grid, not just first boot).

**Scope:**
1. **Plymouth boot splash**: install `plymouth` (confirmed official repo - standard package, not AUR), author a real JAZZ-branded theme (the JAZZ wordmark, matching the project's own "the word JAZZ is the logo" branding decision - Task 27's hyprlock "Welcome to **JAZZ**" label is the closest existing precedent for tone/style), wire the `plymouth` hook into `mkinitcpio.conf` + `splash quiet` kernel params, rebuild the initramfs (`mkinitcpio -P`, real risk - test on a snapshot-protected system, Snapper's already in place from Track A).
2. **`ly` greeter theming**: extend `jazz-theme-set` (or a new small helper) to write `ly`'s `config.ini` with JAZZ's active theme's real colors, so the login screen matches whichever theme was last active - reusing `design/tokens/themes.json` as the single source, same as every other theme-consuming script.
3. **First-boot Welcome app**: a small new Quickshell/QML surface (or a lightweight standalone app if that proves simpler) shown once on first real login - real content only (no fake filler): a short JAZZ intro, a link to `docs/Keybinds.md` (already exists), a prompt to pick a theme (reuses Settings' existing Appearance tab picker), and - once Task 32 ships - a nudge toward the Users tab if only the archinstall-created account exists. Autostart-toggle via a marker file in `$JAZZ_DATA_DIR` (e.g. `welcome-shown`), matching the "Hidden=true/false" convention every comparable distro already uses, adapted to JAZZ's own FileView-based state pattern.
4. **Optional, lower priority**: a themed `fastfetch` config (logo + JAZZ's real palette) as a terminal-side branding touch, matching the CachyOS/Omarchy convention - genuinely optional, not blocking the rest of this task.
5. **`ly` doesn't recognize newly-created users until restarted - confirmed real, and confirmed fixed by a reboot.** Found live 12 Sept 2026 via Akash's own click-test of Task 32's new "Switch to this user" button: after creating a user via Settings and logging out, `ly`'s login screen would not accept the new username - it kept authenticating back into the previously-logged-in account. Root cause confirmed directly from `ly`'s own README (`gh api repos/fairyglade/ly/contents/readme.md`, not guessed): **"Ly doesn't automatically refresh itself. To fix this you should restart Ly service... or reboot your system."** Corroborated live: `ly@tty1.service`'s `MainPID` had been running continuously for 5+ hours (`ActiveEnterTimestamp` from this morning's boot) - well before any test user existed this session. **Confirmed fixed by a real reboot** (Akash's explicit request, 12 Sept 2026): rebooted the machine, reconnected via SSH, `who` showed `jazzy` genuinely logged in on tty1 - the new user's login worked. Whether a live, non-reboot `systemctl restart ly@tty1.service` is also safe (vs. a full reboot) is still untested - not required now that the safe fallback (reboot) is confirmed to work and is already the documented recommendation from `ly` itself.
6. **New users got bare stock Hyprland, not the real JAZZ desktop - FIXED, 12 Sept 2026 (commit follows).** Found live: logged in as the newly-created `jazzy` and screenshotted their session - it showed Hyprland's own generic auto-generated "Welcome to Hyprland!" tutorial popup, no JAZZ top bar/dock/Quickshell/theme at all (`jazz-user-add` only ran a bare `useradd` - none of JAZZ's own per-user provisioning). **Went with Option A** (re-run the real setup scripts per new user), not `/etc/skel` - confirmed live that every JAZZ config bakes in absolute paths at deploy time (`@@JAZZ_DATA_DIR@@` → `/home/holycowstudios/...`), which `/etc/skel` would copy verbatim and wrong for any other user; Option A reuses the same per-user path construction the scripts already do correctly.
   - New `scripts/setup-jazz-repo.sh` persists `scripts/configs/design/docs` at `/opt/jazz` (matching the existing `/opt/jazz-aider`/`/opt/jazz-pyrit` convention from Task 15/15b) - chained as the very first step of `install-jazz.sh`. **Real blocker found and fixed first:** confirmed live that JAZZ's `scripts/` never persisted anywhere on the guest before this - only pushed transiently to `/tmp` per SSH session from the dev machine's own checkout (`find / -iname 'setup-hyprland.sh'` returned nothing beforehand).
   - `jazz-user-add` now runs the real Track B chain (`setup-hyprland.sh`, `setup-quickshell.sh`, `setup-theme.sh`, `setup-dock.sh`, `setup-settings.sh`, `setup-wallpaper.sh`, `setup-kvantum.sh`, `setup-theme-bundle.sh`) from `/opt/jazz/scripts` for the new username, exactly as `install-jazz.sh` already does for the first user. Track A (Snapper) and Track C (Podman/Ollama/PyRIT) deliberately NOT re-run - already-done system-wide setup, not per-user config. (`setup-widgets-tier1.sh` originally listed here too - removed 12 Sept 2026, see item 7 below.)
   - **Two more real bugs found and fixed live while testing this end-to-end:**
     1. Every script pushed via `pscp` from the Windows dev machine carried CRLF line endings, crashing bash (`$'\r': command not found`, `set: -: invalid option`) the moment they ran on the guest - same class of bug as Task 16b's `core.autocrlf` gotcha. Fixed by stripping `\r` from every script on the guest (`sed -i 's/\r$//'`) - a real reminder that any script pushed from Windows needs this before running, not just assumed clean.
     2. `setup-wallpaper.sh` called `gen_wallpaper.py` with no arguments at all - a real regression since Task 27b required a `theme` argument or `--all`, never caught because the existing dev machine already had wallpapers so this code path never actually ran there. Fixed to pass `--all`, matching `setup-theme-bundle.sh`'s own already-correct bootstrap call.
   - **Verified live:** created a fresh `jazzdesktoptest` account end-to-end - real, correctly-populated `hyprland.lua`/`shell.qml`/`Theme.qml`/`Settings.qml`/`themes.json`/Kvantum configs confirmed via file listing after each step, not assumed. Actually *seeing* it rendered still needs one more reboot (same `ly` cache limitation as item 5 above) - not forced without Akash's own choice to do it.
   - Curated wallpapers (Forge/Warm's real art) still only exist in `holycowstudios`'s own folder, not a shared location - copied manually into `jazzdesktoptest`'s folder as a one-off for this test; a real fix (e.g. storing curated wallpapers in `/opt/jazz/design/wallpapers` and having `setup-wallpaper.sh` copy them in) is a smaller separate follow-up, not blocking.
7. **Follow-up, same day (12 Sept 2026): the "smaller follow-up" above was itself a real, live bug - FIXED.** Created a second fresh account (`anve`) and found its desktop showing Hyprland's own stock bundled wallpaper, not JAZZ's - `swaybg` wasn't even running. Root-caused to `gen_wallpaper.py --all`'s bootstrap logic: it decided "does this theme need a placeholder?" by checking substrings in the filename (`"warm" in path`), which also matched `jazz-wallpaper-warm-canyon.png` (the real curated file, not a placeholder) and never matched Forge at all - so new users got a procedurally-mangled file under the "canyon" name for Warm, and literally zero wallpaper file for Forge (confirmed via `md5sum`: `anve`'s "warm-canyon.png" was byte-identical to `warm-01.png`'s placeholder). Also confirmed live: the curated art (`forge-canyon.png`/`warm-canyon.png`) had never actually been persisted in this repo at all - only ever lived in `holycowstudios`'s home directory.
   - **Fixed properly, not patched around:** added an explicit `"curated": true/false` flag to each wallpaper entry in `design/tokens/themes.json`, replacing the substring guess. `gen_wallpaper.py --all` now copies curated entries from a real persisted asset store at `design/wallpapers/` (synced to `/opt/jazz/design/wallpapers` by the existing `setup-jazz-repo.sh` - no new plumbing needed), falling back to the procedural generator only for genuinely non-curated entries. `forge-canyon.png`/`warm-canyon.png` committed into `design/wallpapers/` for the first time.
   - **Akash's separate request, same session:** identified the wallpaper `anve` was actually seeing as Hyprland's own bundled default (`/usr/share/hypr/wall2.png`, confirmed via `pacman -Ql hyprland` + visual match) and adopted it as Midnight's real curated wallpaper (cropped 7680x4191 -> 1920x1080, `jazz-wallpaper-midnight-hyprland.png`, added to `themes.json` as `curated: true`). Licensing caveat recorded in new `design/wallpapers/SOURCE.md`: this art isn't in Hyprland's own GitHub repo and its original artist is undocumented - fine for internal dev use, flag before shipping beyond this machine (same open class as Task 27f).
   - Live-fixed `anve`'s already-created account directly (re-ran the corrected `gen_wallpaper.py --all` against its wallpaper dir, `jazz-theme-set --restore` to actually start `swaybg`) - confirmed via screenshot, real Forge canyon wallpaper now rendering. Backfilled `holycowstudios` with the new Midnight file too for consistency.
   - **Full audit of `anve` vs `holycowstudios`, requested by Akash, everything else checked out as expected (not bugs):** Kvantum only has `Jazz-forge` for `anve` (by design - `jazz-theme-set` generates a theme's Kvantum config lazily on first real selection, not upfront); `chat-request.json`/`notes.txt`/`workspace-overrides.json` correctly absent (all three are user-generated-content files, created on first use); `hyprland.lua` functionally identical (only a stale comment differs); `anve` correctly lacks the `wheel` group (non-admin) and `seat` (confirmed no udev rule on this system references it - harmless leftover on `holycowstudios`); `~/.config/jazz/agent-policy.json` correctly absent (Track C tooling, deliberately not provisioned for new users).
   - **Real (harmless) finding from that audit:** `setup-widgets-tier1.sh` was fully superseded by `setup-dock.sh` - both write the same `shell.qml`, "latest writer wins" by the script's own header comment, and `setup-widgets-tier1.sh`'s version had a genuine bug (Notes/To-do widgets hardcoded to `/home/holycowstudios/...` instead of `@@JAZZ_DATA_DIR@@`). Since it ran before `setup-dock.sh` in both `install-jazz.sh` and `jazz-user-add`, its output was always immediately clobbered - dead code in practice (confirmed live: `anve`'s real deployed `shell.qml` has no hardcoded path), but pure wasted work on every provision and a landmine if the run order ever changed. **Removed** from both chains and deleted the file entirely.

**Session of 14 Sept 2026 - ly login-screen theming and the first-boot Welcome app, both built and confirmed live:**
- **`ly` theming - real mechanism chosen after checking permissions live, not guessed.** `ly`'s `config.ini` lives in `/etc` (root-only), but `jazz-theme-set` runs as a plain desktop user on every single Appearance-tab click (self-service, no sudo) - it can't write there directly, and adding a sudo prompt to every theme switch would be a real UX regression. Instead: `jazz-theme-set` now also writes theme colors (`bg`=chrome.surface, `fg`=chrome.textPrimary, `border`=accent, `error`=terminal.red) to `/var/lib/jazz/ly-theme.json`, a small state file seeded at mode 0666 by new `scripts/setup-ly-theme.sh` (confirmed a plain truncate-write to an existing 0666 file works for any user, no sticky-bit tricks needed). New `scripts/jazz-ly-theme-sync` (root) reads that file and rewrites `config.ini`'s real `bg`/`fg`/`border_fg`/`error_fg` keys (format `0xSSRRGGBB`, confirmed from the file's own header comment) - wired to run via a systemd drop-in (`/etc/systemd/system/ly@.service.d/jazz-theme.conf`, `ExecStartPre`) right before the greeter starts, so `ly` always reflects whichever theme was most recently applied by any user. **Confirmed live end-to-end**, twice, with two different themes: applied Forge, ran the sync, confirmed `config.ini`'s real hex values matched Forge's palette exactly; switched to Daylight, re-ran, confirmed the values changed to Daylight's palette; reverted back to Forge afterward to leave the system as found. Not confirmed via an actual `ly` screenshot (would have required stopping/restarting the live `ly@tty1.service` mid-session, avoided as unnecessary risk to the active desktop) - the config file itself is proven correct, which is what the systemd hook applies verbatim.
- **First-boot Welcome app - built, wired, and confirmed live via screenshot showing/hiding correctly.** New `configs/quickshell/Welcome.qml`, same `Loader { source: "..." }` pattern as Settings.qml (Task 28), added to `setup-dock.sh`'s `shell.qml` heredoc right after the Settings Loader line. Shows once via the same `FileView` `onLoaded`/`onLoadFailed` marker convention already used for Notes/To-do (`$JAZZ_DATA_DIR/welcome-shown`) - deliberately no click-outside-to-dismiss (unlike Settings), only the explicit "Let's go" button writes the marker, so an accidental click can't burn the one-time showing. Content: a short real intro, a "pick a theme" button (reuses the existing Settings IPC toggle - `Quickshell.execDetached(["qs", "ipc", "call", "settings", "toggle"])`, the exact same call already used elsewhere in `shell.qml`, confirmed no `-c` flag needed), a "view keybinds" button (opens the already-deployed `Keybinds.md` in `less`/kitty), and a real user-count check (`getent passwd` filtered the same way Settings' own Users tab does) that only shows the "add more users" nudge when there's genuinely just one real account. New `scripts/setup-welcome.sh` deploys the file with `@@JAZZ_DATA_DIR@@` substitution, chained into `install-jazz.sh` and `jazz-user-add`. **Real bug caught before deploying, not after**: the card's first draft used a fixed height (560px) that a rough content-size estimate suggested could clip the bottom button - the exact bug class Task 31 already hit once. Fixed by sizing the card to `content.implicitHeight` instead of a guessed constant, before ever testing live. **Confirmed live end-to-end via two screenshots**: first with no marker file present, showing the full card correctly (no clipping, and the "only one account" nudge correctly absent since this machine has 2 real users - proving the count check itself works, not just its visibility binding); then with the marker written (simulating the dismiss button, since no click-simulator exists over SSH), confirming it correctly stays hidden and the normal desktop renders.
- **Plymouth boot splash - attempted 15 Sept 2026 with Akash's explicit go-ahead, ultimately REVERTED after real live feedback.** Full attempt, in order: (1) adapted Plymouth's own bundled `spinner` theme (proven `two-step` module, not a hand-written script) with a JAZZ watermark + Forge's palette, confirmed via a real reboot watched live by Akash ("Black screen was there and then jazz load up. now i am on login screen") - genuinely worked on the first full attempt. (2) Akash's photographed feedback on that same boot then surfaced two more real, separate things, investigated and partly fixed the same session - see the "boot branding fixes" entry below for the systemd-boot menu title/splash-BMP/NVRAM-label work, all of which stayed and shipped. (3) The Plymouth splash itself got two follow-up passes (a bigger/recentered logo; reordering `HOOKS` so `plymouth` runs after `kms`, on the theory that the GPU driver wasn't ready when Plymouth first tried to paint) - **neither fixed the actual problem**, because the real cause turned out to be unrelated to Plymouth entirely (see the `docs/Research-Reference-List.md` entry dated 15 Sept 2026): a ~85 second USB enumeration stall on every single boot, root-caused to a known AMD Renoir/Cezanne chipset-class issue (almost certainly the integrated webcam failing to respond), confirmed present in boot logs from *before* Plymouth was ever installed on this machine. Before this was diagnosed, `quiet` had turned that pre-existing stall from "scrolling kernel text, looks busy" into "blank black screen, looks hung" - Akash's own words after the third attempt: *"black screen is too long again. not a word of jazz loading... that window showed scrolling kernel boot text is much better than this."*
- **Final decision: fully reverted, not shipped half-working.** `plymouth` was removed from `mkinitcpio.conf`'s `HOOKS`, and `splash`/`quiet` were removed from `/etc/kernel/cmdline`, restoring the exact original plain-text boot - confirmed via a real reboot afterward (`/proc/cmdline` matches the pre-Plymouth state exactly, system healthy). The `plymouth` package, the `jazz` theme files (`/usr/share/plymouth/themes/jazz/`), and all the `ly`/Settings theme-sync work built alongside it (see below) all stay installed and available - only the active boot-time wiring was reverted. **This is the right call, not a failure to just push through**: the underlying USB stall is a real hardware/kernel timing issue with no fast, certain software fix available in-session (see Research-Reference-List.md for the real fix options - BIOS-disable the camera, or further kernel-quirk research - both deliberately left for a dedicated follow-up, not rushed).
- **Boot branding fixes - all three shipped and confirmed live, independent of the Plymouth revert above:** (1) the plain UEFI NVRAM boot entry (labeled "Linux Boot Manager" by `bootctl install`'s own default, shown in the firmware's own F12-style boot menu) renamed to "JAZZ" via `efibootmgr` (delete + recreate, `BootOrder` restored to its original Windows-first position afterward) - confirmed live via `efibootmgr` after a real reboot (`BootCurrent: 0000`, the new JAZZ-labeled entry, actually used to boot). (2) `/etc/os-release`'s `NAME`/`PRETTY_NAME` changed from "Arch Linux" to "JAZZ" (kept `ID=arch` untouched for pacman/AUR-helper compatibility - confirmed it's a real file, not a symlink to a package-owned path, so this survives package updates) - this is what systemd-boot's own UKI-derived menu title reads from, confirmed live (the boot menu itself now says "JAZZ"). (3) the *separate* systemd-boot stub splash BMP (shown before Plymouth even starts, discovered only from Akash's own photo feedback - `/etc/mkinitcpio.d/linux-lts.preset`'s `default_options="--splash ..."` was pointing at the stock Arch logo the whole time, a layer Task 33's original scope never anticipated) replaced with a JAZZ wordmark BMP at a JAZZ-owned path (`/usr/local/share/jazz/splash.bmp`, not overwriting the systemd-package-owned original, so a future package update can't silently revert it). **The plain systemd-boot OS-selection menu itself (Arch vs. Windows, ~3 second timeout) stays unstyled by explicit choice** - confirmed via research (Omarchy doesn't touch it either) that this is a hard technical limitation of `systemd-boot`'s menu renderer (text-only, no image/font support by design), not something fixable short of a full bootloader swap (rEFInd/GRUB/Limine) - Akash explicitly chose to leave the 3-second timeout as-is rather than pursue that bigger change.
- **Real finding recorded publicly, not just internally**: the USB/boot-stall root cause is written up in full in `docs/Research-Reference-List.md` (dated 15 Sept 2026), plus a public-facing "Known Issues" section drafted directly into Task 17's own entry below, ready to drop into the real README when that task starts - Akash's explicit request, so future users hitting the same symptom on similar AMD hardware have somewhere to look.

**Acceptance criteria:**
- [ ] `plymouth` installed and shows a real JAZZ-branded boot splash (not the Arch/OEM default `bgrt`) - **attempted and reverted 15 Sept 2026**, not shipped: the splash itself worked, but a real, separate ~85s USB-enumeration hardware stall (see Research-Reference-List.md) made the overall boot experience worse than plain text, per Akash's own live feedback across three attempts. Re-open once either the USB stall has a real fix or Akash decides a black screen during that stall is acceptable anyway.
- [x] `ly`'s login screen reflects the currently-active JAZZ theme's real colors - confirmed live 14 Sept 2026 via the deployed `config.ini` itself (two themes tested, values matched exactly both times); an actual greeter-screenshot confirmation is still open, deliberately deferred to avoid restarting the live `ly@tty1.service` mid-session
- [x] A first-boot Welcome app appears exactly once on a fresh install, never again after being dismissed, confirmed via the marker-file mechanism - confirmed live 14 Sept 2026, both the "shows" and "stays hidden after dismiss" cases
- [x] Welcome app's content is real (working theme picker, real doc links) - no placeholder/fake content, matching the project's own "functional honesty" precedent (Design-Vision.md, the GPU-panel/audio-panel honesty pattern from Tasks 24/26) - confirmed live via screenshot
- [x] A user created via Task 32's Settings UI can actually log in as themselves at `ly` after a reboot - confirmed live 12 Sept 2026 (`who` showed the new user logged in on tty1 post-reboot); a non-reboot live refresh path remains untested/optional
- [x] A newly-created user's first login shows the real JAZZ desktop (top bar, dock, active theme), not Hyprland's own generic stock config - confirmed live end-to-end on a second real account (`anve`, no reboot needed this time since `ly` had already been restarted by the earlier reboot): correct wallpaper rendering confirmed via screenshot after fixing the `gen_wallpaper.py --all` bug (item 7)

**Dependencies:** Task 27b (theme tokens to source colors from), Track A/Snapper (safety net before any `mkinitcpio -P` rebuild), Task 32 (Welcome app's "add more users" nudge, once that tab exists - now genuinely useful since new users get a real desktop)
**Files likely touched:** `scripts/jazz-theme-set` (extended 14 Sept to also write `/var/lib/jazz/ly-theme.json`), new `scripts/jazz-ly-theme-sync` + `scripts/setup-ly-theme.sh` (14 Sept), new `configs/quickshell/Welcome.qml` + `scripts/setup-welcome.sh` (14 Sept), `scripts/setup-dock.sh` (Welcome Loader line added to its `shell.qml` heredoc), `scripts/install-jazz.sh`/`scripts/jazz-user-add` (both updated to chain `setup-ly-theme.sh`/`setup-welcome.sh`), `docs/Research-Reference-List.md` (15 Sept, USB boot-stall finding), `tasks/todo.md` Task 17 (15 Sept, draft README "Known Issues" section), new `scripts/setup-boot-branding.sh` + `design/boot-branding/jazz-splash.bmp` (15 Sept - the three surviving branding fixes, now a reproducible/idempotent script instead of live-only guest state, confirmed live: a second run against already-applied state cleanly no-ops). **No committed setup script for Plymouth itself** - the splash/HOOKS portion was reverted (see above), and its theme files (`/usr/share/plymouth/themes/jazz/`) still only exist as live guest state; deliberately not scripted since the splash isn't active and isn't worth capturing until the USB-stall blocker has a real fix.
**Estimated scope:** M - new-user-desktop-provisioning (item 6), its wallpaper-bootstrap follow-up (item 7), `ly` theming, the Welcome app, and all three boot-branding fixes (NVRAM label/menu title/stub splash) are done, shipped, AND now reproducible via `setup-boot-branding.sh`; only Plymouth's own splash remains attempted-and-reverted, pending a real fix for the unrelated USB boot-stall

---

## Phase 4: Public-repo readiness

### Task 17: README
**Description:** Write the public-facing README — what JAZZ is, why it exists, install instructions referencing `install/` and `scripts/`, current status, a demo GIF/screenshot once the desktop from Task 10/11 is stable.

**Draft "Known Issues" section ready, added 15 Sept 2026 (Akash's request, during Task 33's Plymouth work) — drop this into the real README.md when this task starts, don't recreate it from scratch. Full technical detail (root-cause trail, sources) lives in `docs/Research-Reference-List.md` section 0, dated 15 Sept 2026 - this is the public-facing summary of that entry:**

> ## Known Issues
>
> **Boot takes longer than expected on AMD Renoir/Cezanne laptops (e.g. Lenovo Yoga 6 82FN) - it will still boot, just not quickly.** On some AMD Ryzen 4000/5000-mobile ("Renoir"/"Cezanne") laptops, an integrated USB peripheral (commonly the webcam) fails to respond during early boot, and the kernel's USB stack retries repeatedly before giving up - adding well over a minute before the desktop appears. This is a known chipset/peripheral timing issue (see `docs/Research-Reference-List.md` for the full trail and sources), not something JAZZ's own scripts cause, and it isn't specific to any one physical unit - any Linux distro on the same chipset family will show the same symptom (`dmesg`/`journalctl -b` will show repeated `usb N-M: device descriptor read/64, error -110` lines from the same port).
>
> JAZZ does **not** currently hide this delay behind a boot splash - Plymouth was tried and then deliberately reverted back to plain scrolling boot text, specifically so this delay stays visible as real progress (it's still moving, just slow) rather than reading as a silent hang.
>
> **A universal fix (bounding how long boot waits on any slow/misbehaving USB device, not specific to any one machine's exact hardware) is planned for v2, not v1** - deliberately not rushed. If you don't need the affected device (usually the integrated camera) and want to remove the delay now, disabling it in your BIOS/UEFI setup is a workaround, not something JAZZ does for you.

**Acceptance criteria:**
- [ ] README covers: what/why, install steps, current status, at least one visual (screenshot/GIF), and the Known Issues section drafted above

**Verification:**
- [ ] Manual read-through: could a stranger follow this?

**Dependencies:** Tasks 5, 9, 10 (needs a working, demoable system)

**Files likely touched:** `README.md`

**Estimated scope:** S

---

### Task 18: LICENSE + CHANGELOG
**Description:** Add the MIT LICENSE (copyright Akash Navet / Holy Cow Studios Pvt Ltd) and start `CHANGELOG.md`.

**Status: DONE as of 7 Sept 2026.**

**Acceptance criteria:**
- [x] `LICENSE` present with correct copyright holders
- [x] `CHANGELOG.md` exists with at least one entry (seeded with real milestones from git history, not a placeholder)

**Verification:**
- [x] Manual check

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
