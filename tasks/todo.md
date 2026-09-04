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

**Acceptance criteria:**
- [ ] A deliberately broken state (e.g. a corrupted config) is fully reverted after `snapper rollback` (or equivalent) and a reboot

**Verification:**
- [ ] System boots cleanly post-rollback; the deliberate breakage is gone

**Dependencies:** Task 7

**Files likely touched:** none new

**Estimated scope:** S

---

## Phase 2, Track B: Desktop

**Read `Design-Vision.md` before starting any task in this track** — it records the agreed workspace colors, the native-Hyprland-vs-Quickshell animation split, dashboard scope, and accessibility commitments, so this track builds toward what was actually agreed rather than re-deriving it from memory.

### Task 9: Hyprland reaches a working desktop
**Description:** Confirm the Hyprland desktop provisioned by archinstall's profile actually launches and is usable inside the VM.

**Acceptance criteria:**
- [ ] Graphical login reaches a working Hyprland session
- [ ] Basic window management (open a terminal, move/tile it) works

**Verification:**
- [ ] `hyprctl version` succeeds; `scripts/verify/hyprland.sh` created and passing

**Dependencies:** Task 5

**Files likely touched:** `scripts/verify/hyprland.sh`

**Estimated scope:** S

---

### Task 10: Quickshell running with one custom widget
**Description:** Install Quickshell and build one small widget (clock or workspace indicator) from its Getting Started guide, per the research addendum's own recommended first step — not the full AI Command Centre yet.

**Acceptance criteria:**
- [ ] Quickshell process running under Hyprland
- [ ] One custom QML widget renders and updates live

**Verification:**
- [ ] Manual visual check; `scripts/verify/quickshell.sh` confirms the process is running

**Dependencies:** Task 9

**Files likely touched:** `configs/quickshell/*.qml`, `scripts/verify/quickshell.sh`

**Estimated scope:** M

---

### Task 11: `Theme.qml` singleton + one functional-animation proof
**Description:** Build the lightweight `Theme.qml` singleton (named state tokens, `Behavior`/`ColorAnimation`/`Transition` primitives) recommended by the design research, and wire one real functional-animation behavior end to end — a window-class-matched border color rule — as proof the pattern works before building the rest of the animation vision.

**Acceptance criteria:**
- [ ] `Theme.qml` exists with at least one named color token
- [ ] A test window matching a specific class shows the rule-driven border color, confirmed live-updating via Hyprland's `windowrule` syntax

**Verification:**
- [ ] Manual visual check

**Dependencies:** Task 10

**Files likely touched:** `configs/quickshell/Theme.qml`, `configs/hypr/hyprland.conf` (windowrule addition)

**Estimated scope:** M

---

## Phase 2, Track C: AI engineering

### Task 12: Rootless Podman working
**Description:** Set up rootless Podman on the base system.

**Acceptance criteria:**
- [ ] `podman info` succeeds without root

**Verification:**
- [ ] `scripts/verify/podman.sh` created and passing

**Dependencies:** Task 5

**Files likely touched:** `scripts/setup-podman.sh`, `scripts/verify/podman.sh`

**Estimated scope:** S

---

### Task 13: Reproducible PyTorch + JupyterLab container, CPU-validated
**Description:** Build one reproducible container (pinned PyTorch version, lockfile) with JupyterLab, and confirm CPU-backed PyTorch operation inside it. This exact container definition is what Task 16 later validates against a rented GPU — build it carefully.

**Acceptance criteria:**
- [ ] Container builds from a pinned Containerfile/lockfile
- [ ] Inside the container: `import torch; torch.zeros(3).sum()` runs successfully on CPU
- [ ] JupyterLab starts and is reachable

**Verification:**
- [ ] `scripts/verify/ai-core.sh` created and passing

**Dependencies:** Task 12

**Files likely touched:** `configs/containers/ai-core/Containerfile`, lockfile, `scripts/verify/ai-core.sh`

**Estimated scope:** M

---

### Task 14: Ollama installed, CPU inference confirmed
**Description:** Install Ollama, pull one small model, confirm a CPU inference request returns output.

**Acceptance criteria:**
- [ ] `ollama list` shows a pulled model
- [ ] A prompt via `ollama run` (or the API) returns a real response

**Verification:**
- [ ] `scripts/verify/ollama.sh` created and passing

**Dependencies:** Task 5 (does not depend on Podman track)

**Files likely touched:** `scripts/setup-ollama.sh`, `scripts/verify/ollama.sh`

**Estimated scope:** S

---

### Task 15: Garak/PyRIT probe run
**Description:** Install Garak and PyRIT, run one probe (e.g. `dan.DAN_Jailbreak`) against the local Ollama model, and confirm a report is produced.

**Acceptance criteria:**
- [ ] `garak --version` succeeds
- [ ] A probe run against the local model completes and produces a readable report file

**Verification:**
- [ ] `scripts/verify/garak.sh` created and passing; report file exists and is non-empty

**Dependencies:** Task 14

**Files likely touched:** `scripts/setup-redteam-ai.sh`, `scripts/verify/garak.sh`

**Estimated scope:** S

---

## Checkpoint: Core tracks
- [ ] Tracks A, B, C each pass all their `scripts/verify/*.sh` checks independently
- [ ] **Review with Akash before Task 16 — it's the first task that spends real money**

---

## Phase 3: GPU validation (isolated, explicit go-ahead required)

### Task 16: Rent a GPU, validate the AI-core container
**Description:** Rent a Vast.ai (or RunPod fallback) RTX 4090 spot instance, run Task 13's exact container definition unmodified, and confirm `torch.cuda.is_available()` returns `True`. Tear the instance down immediately after — never leave it running.

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
