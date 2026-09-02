# Spec: JAZZ — Phase 1 (Arch AI Engineering OS)

**Built by:** Akash Navet, Holy Cow Studios Pvt Ltd, and Claude

## Objective
Build Phase 1 of **JAZZ**, a custom Arch Linux–based AI engineering workstation that is both a learning vehicle *and* a genuinely workable, publishable operating system. The end state is public-repo-ready: clean git history from commit #1 (no secrets or personal data ever enters it — this can't be scrubbed after the fact), a real license, and documentation sufficient for a stranger to clone and build it themselves. Learning stays primary for *how* we work — every stage should leave the user able to explain it, not just have run it — but "good enough to understand" is not the bar for anything that ships; "good enough for someone else to use" is.

The conventional red-team lab layer is deferred for this phase (see `Blueprint_Phase1_AI_Engineering_First.md` §4 for why — WHPX, the only virtualization backend available on this Windows 11 Home machine, doesn't support the nested virtualization the lab layer needs).

**User:** the developer themself first (personal use/learning), with the explicit intent of later opening the repo to anyone who wants to build the same system. Windows 11 Home laptop, no NVIDIA/AMD GPU, 15.6GB RAM, 739GB free disk.

## Tech Stack
- Guest OS: Arch Linux (x86_64), standard + LTS fallback kernel (target 6.18 LTS)
- Install mechanism, two layers (confirmed via research 31 Aug 2026, see `Research-Reference-List.md` §0): (1) `archinstall`'s **built-in Hyprland desktop profile** for base system + disk/Btrfs layout + desktop selection, driven by a JSON config generated through archinstall's own interactive "Save configuration" export — not hand-authored, since hand-edited configs are known to crash `--silent` mode; (2) a **separate idempotent bash script** layered on afterward for AI tooling (Podman/Python/Ollama) and Quickshell/dotfiles. Run after booting the official vanilla Arch ISO — **not** a custom-built ISO. Every comparable shipped project studied (Omarchy, CachyOS/Noctalia, JaKooLit/Arch-Hyprland, mat-kubiak/HyprArch, and others) uses this same two-layer pattern; none build their own ISO or cram everything into one custom profile
- Desktop: Hyprland (compositor, v0.56.x) + Quickshell/Qt 6.8 LTS QML (shell) + PipeWire + XDG Desktop Portals
- Containers: rootless Podman
- AI: Python via `uv`, PyTorch (~2.11/2.12, CUDA 12.8+/13.0 target for the cloud-validated profile), JupyterLab
- Local inference: Ollama, llama.cpp
- AI red-team: Garak (v0.14.x), PyRIT (`microsoft/PyRIT`, v0.11.x) — probing the local Ollama endpoint only
- Filesystem: Btrfs subvolumes + Snapper + grub-btrfs (or systemd-boot bootloader-spec equivalent) for snapshot/rollback
- Host tooling (Windows, not part of the guest): QEMU + WHPX acceleration, used to develop and test the install profile/script against a disposable VM — not to build a shipped artifact
- Deferred (not v1 scope): PKGBUILD/makepkg, archiso, Calamares — custom-ISO tooling and its CI/signing infrastructure, revisited only if there's real demand for GUI-first onboarding (see `Research-Reference-List.md` §8)

## Commands
No single build/test entrypoint yet (this is an OS install, not an app) — the operative commands are:

```
# Launch the dev VM (exact flags finalized in Task 1; illustrative here)
qemu-system-x86_64 -accel whpx -m 6144 -smp 4 \
  -drive file=vm/arch-dev.qcow2,if=virtio \
  -cdrom vm/archlinux-x86_64.iso -boot d \
  -bios <path-to-OVMF_CODE.fd> \
  -netdev user,id=n0 -device virtio-net,netdev=n0

# Run the install profile against a freshly-booted vanilla Arch ISO in the dev VM
# (exact invocation finalized in Task 1; illustrative here)
archinstall --config install/profile.json --silent

# Snapshot before a risky change (inside the guest, once Btrfs/Snapper exist)
snapper create --description "before <change>"

# Per-stage verification (examples; concrete list lives per-task in tasks/todo.md)
systemctl is-system-running
hyprctl version
podman info
ollama list
garak --version
```

Once shell/Python tooling exists: `shellcheck scripts/*.sh`, `ruff check .`, `pytest` for any Python helpers.

## Project Structure
```
jazz/                          git repo root
  README.md                    public-facing: what JAZZ is, how to build it, current status
  CHANGELOG.md                 plain-text update visibility, no migrations framework needed
  LICENSE                      chosen once the license question below is resolved; copyright held by Akash Navet / Holy Cow Studios Pvt Ltd
  .pre-commit-config.yaml      gitleaks hook, run before every commit
  docs/                        blueprint, research addendum, phase-1 blueprint, this spec, reference list
  tasks/                       plan.md + todo.md (spec-driven-development convention)
  install/                     archinstall profile/config (or fallback bash script) — the actual install mechanism a stranger runs after booting vanilla Arch
  scripts/                     idempotent shell/Python setup scripts, one per stage, invoked from install/
  scripts/verify/              corresponding verification scripts (the closest thing to a regression suite)
  configs/                     dotfiles, Hyprland/Quickshell configs, systemd units — version controlled, genericized (no personal paths/usernames)
  vm/                          QEMU launch scripts for the local dev/test VM only (not for building a shipped ISO); disk images/ISOs live here but are gitignored
  .gitignore                   excludes *.qcow2, *.iso, venvs, model weights, secrets
```

## Code Style
- Shell: `#!/usr/bin/env bash`, `set -euo pipefail`, shellcheck-clean, idempotent (safe to re-run without side effects on a second run)
- Python: PEP 8, type hints on function signatures, `uv` for environment management
- QML: Qt 6 conventions, one component per file
- Naming: kebab-case for scripts, snake_case for Python, PascalCase for QML components
- No comments explaining *what* code does — only *why*, where a choice is non-obvious

## Testing Strategy
No traditional unit-test suite in the early install stages — there's no application code yet. Verification instead means:
- A per-task **acceptance check**: an explicit command plus its expected output, run immediately after each task
- Once `scripts/` exists (Stage 2+), each setup script gets a matching `scripts/verify/*.sh` asserting the expected end-state (service running, package installed, file present) — the closest thing to a regression suite, per the blueprint's own §18 philosophy ("failures become automated regression tests")
- Any Python tooling that emerges (installer helpers, validation utilities) gets `pytest` coverage as it's written, not retrofitted later
- **Update model:** `git pull` + re-run the idempotent install script, with Snapper's existing auto-snapshot as the rollback safety net — no custom migrations framework for v1 (confirmed via research: this only becomes necessary once a real non-idempotent breaking change occurs that a re-run can't handle, which the idempotency requirement above is specifically designed to avoid). A plain-text `CHANGELOG.md` gives update visibility without extra infrastructure
- Before any public push: a full clean-clone rebuild test — boot a fresh vanilla Arch ISO in a disposable VM, clone the repo, run only what's in `install/`, and confirm it reproduces a working system using nothing but the repo and its README

## Boundaries
- **Always:** create a Btrfs/Snapper snapshot before any risky change inside the guest, once the filesystem supports it; state the underlying concept before or while running each command, not just the command itself; verify a command's real effect before running anything destructive (partitioning, `rm -rf`, `dd`); keep configs genericized (native `$HOME`/XDG variable references, no hardcoded personal paths/usernames, no templating tool needed) as they're written, not cleaned up later; run Gitleaks (`gitleaks detect --staged`, installed as a pre-commit hook from the first commit) before any commit
- **Ask first:** spending any money (cloud GPU rental sessions — user handles payment themselves); installing anything on the Windows host outside the VM; expanding scope beyond this Phase 1 spec (e.g. touching the deferred red-team layer); anything that would touch the Windows host's own disk or bootloader; pushing the first commit to a public remote or flipping repo visibility to public
- **Never:** touch the Windows host's partition table or bootloader in this phase; commit VM disk images, ISOs, secrets, personal file paths, or model weights to git; introduce red-team-lab content (malware samples, exploit VMs) into this environment; skip the teaching explanation to move faster

## Success Criteria
Functional (from `Blueprint_Phase1_AI_Engineering_First.md` §5, with #1 tightened for public reproducibility):

1. Build reproducibly **from the repo alone** — a stranger cloning it fresh, with none of this session's VM state or memory, can identify unintended differences
2. Boot reliably in the QEMU/WHPX VM
3. Install onto a clean virtual disk
4. Reach a working animated Hyprland/Quickshell desktop
5. Launch an isolated AI environment (rootless Podman + PyTorch + Jupyter)
6. Validate CPU-backed PyTorch operation locally
7. Validate GPU-backed PyTorch operation via a rented cloud GPU, against the same container definition
8. Run a local model through Ollama or llama.cpp
9. Run a basic AI red-team assessment (Garak or PyRIT) against that local model
10. Update and recover through a documented Btrfs/Snapper rollback

Public-repo readiness (new, additive — not required to complete Phase 1's technical work, required before any public push):

11. **Documentation exists** — a README (plus per-stage notes) sufficient for a stranger to go from clone to a working system using only what's in the repo
12. **Repo hygiene gate** — before any public push: no secrets or personal data anywhere in commit history, LICENSE present, all tracked configs genericized

## Open Questions
1. **License** — defaulting to MIT, copyright held jointly by Akash Navet and Holy Cow Studios Pvt Ltd (simplest, most permissive, matches the learning-in-public style of the user's other showcase projects) unless told otherwise. Can also be deferred until there's something to license.
2. Confirm the project folder becomes a git repo now (recommended — needed for "spec lives in version control," and Stage 2 of the blueprint's own progression calls for it anyway).
3. Confirm the directory structure above, or adjust it.
4. VM RAM allocation — proposing 6GB to the guest, leaving ~9GB for Windows on this 15.6GB machine. Confirm or adjust.
5. Confirm moving the three existing docs into `docs/` as part of repo setup, or keep them flat in the project root.
