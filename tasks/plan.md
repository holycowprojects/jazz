# Implementation Plan: JAZZ Phase 1

**Derived from:** `SPEC.md`, `Research-Reference-List.md`
**Built by:** Akash Navet, Holy Cow Studios Pvt Ltd, and Claude
**Date:** 31 August 2026

## Overview

Build Phase 1 of JAZZ — a custom Arch Linux AI-engineering workstation — entirely inside a local QEMU/WHPX VM on Windows, shipping as a documented install-script (archinstall profile + a separate idempotent script), not a custom ISO. Red-team and full security hardening are explicitly deferred. The plan follows the dependency graph below, sliced vertically so each phase leaves a genuinely working, testable system rather than one horizontal layer at a time.

## Architecture Decisions

(Full rationale in `SPEC.md` and `Research-Reference-List.md`; summarized here for plan context.)

- **Two-layer install, no custom ISO:** archinstall's built-in Hyprland profile (base system + Btrfs) + a separate idempotent bash script (AI tooling, Quickshell, dotfiles) — the pattern every comparable shipped project uses.
- **`-bios OVMF_CODE.fd`, never the pflash drive syntax** — the only form that boots under WHPX.
- **Vertical tracks, not horizontal layers:** once the base system exists, filesystem/recovery, desktop, and AI-engineering work proceed as three independent, parallelizable tracks — a setback in one doesn't block the others.
- **GPU validation is isolated and on-demand:** a single deliberate, money-spending task against a rented GPU, not a persistent cloud resource.
- **Public-repo readiness is load-bearing, not an afterthought:** Gitleaks from commit #1, genericized configs from the moment they're written, not cleaned up retroactively.

## Dependency Graph

```
Task 1 (repo scaffolding + Gitleaks)
        │
Task 2 (QEMU installed, WHPX confirmed)
        │
Task 3 (OVMF sourced, launch script with -bios fix + qcow2 overlay workflow)
        │
Task 4 (archinstall config generated via interactive export)
        │
Task 5 (unattended install → boots to login)   ◄── the actual Stage 1 moment
        │
Task 6 (repeat install — reproducibility check)
        │
   ═══════════ CHECKPOINT: Foundation ═══════════
        │
        ├─────────────┬─────────────────┐
        │              │                  │
Track A: Filesystem   Track B: Desktop   Track C: AI engineering
  Task 7 Snapper        Task 9 Hyprland    Task 12 Podman
  Task 8 rollback test  Task 10 Quickshell Task 13 PyTorch+Jupyter
                         Task 11 Theme.qml  Task 14 Ollama
                                            Task 15 Garak/PyRIT
        │              │                  │
        └─────────────┴─────────────────┘
                        │
   ═══════════ CHECKPOINT: Core tracks ═══════════
                        │
        Task 16 (GPU cloud validation — isolated, ask-first)
                        │
        Task 17 (README) ─── Task 18 (LICENSE/CHANGELOG)
                        │
        Task 19 (hygiene gate)
                        │
        Task 20 (clean-clone rebuild test)
                        │
   ═══════════ CHECKPOINT: Public-repo ready ═══════════
```

## Task List

### Phase 0: Foundation
- [ ] Task 1: Repo scaffolding + Gitleaks
- [ ] Task 2: QEMU installed, WHPX confirmed
- [ ] Task 3: OVMF + launch script (with the `-bios` fix and qcow2 overlay workflow)

### Phase 1: Base system (Stage 1)
- [ ] Task 4: archinstall config generated
- [ ] Task 5: Unattended install boots to login
- [ ] Task 6: Repeat install — reproducibility check

### Checkpoint: Foundation
- [ ] `git log` shows commits; Gitleaks hook active
- [ ] VM boots via the launch script without falling back to TCG
- [ ] Two independent installs from the same config both reach a login prompt unattended

### Phase 2: Three parallel tracks
**Track A — Filesystem/recovery**
- [ ] Task 7: Snapper + snap-pac configured
- [ ] Task 8: Rollback tested against a deliberate breaking change

**Track B — Desktop**
- [ ] Task 9: Hyprland reaches a working desktop
- [ ] Task 10: Quickshell running with one custom widget
- [ ] Task 11: `Theme.qml` singleton + one windowrule-driven border-color proof

**Track C — AI engineering**
- [ ] Task 12: Rootless Podman working
- [ ] Task 13: Reproducible PyTorch + JupyterLab container, CPU-validated
- [ ] Task 14: Ollama installed, model pulled, CPU inference confirmed
- [ ] Task 15: Garak/PyRIT probe run against the local model

### Checkpoint: Core tracks
- [ ] All three tracks independently pass their `scripts/verify/*.sh` checks
- [ ] Review with the user before spending any money (Task 16)

### Phase 3: GPU validation (isolated, explicit go-ahead required)
- [ ] Task 16: Rent a GPU, run Task 13's exact container, confirm `torch.cuda.is_available()`

### Phase 4: Public-repo readiness
- [ ] Task 17: README (demo + install instructions)
- [ ] Task 18: LICENSE (MIT, Akash Navet / Holy Cow Studios Pvt Ltd) + CHANGELOG.md
- [ ] Task 19: Hygiene gate — full-history Gitleaks scan, config genericization check
- [ ] Task 20: Clean-clone rebuild test

### Checkpoint: Public-repo ready
- [ ] All 12 of SPEC.md's success criteria met
- [ ] Explicit user go-ahead obtained before the first public push (per SPEC.md boundaries — this plan does not authorize that step on its own)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| WHPX acceleration silently degrades to TCG | High — everything downstream slows to unusable | Task 2 explicitly verifies accel is active before any further work |
| 15.6GB host RAM starves under VM + Windows | Medium | 6GB VM allocation (per SPEC open question default); qcow2 overlays keep disk light; close host apps during heavy sessions |
| archinstall silent-mode config is hand-edited and crashes | Medium | Task 4 explicitly generates the config via interactive export, never hand-authored, per the research finding |
| Scope creep back into deferred red-team work | Medium | Already an explicit "ask first" boundary in SPEC.md; no task in this plan touches §9.1/§5.3 content |
| Secrets/personal paths land in git history | High if public | Gitleaks hook from Task 1 (first commit); Task 19 re-verifies full history before any public push |
| GPU cloud costs creep | Low | Task 16 is a single isolated task — spin up, validate, tear down; never a standing resource |

## Open Questions

None blocking — SPEC.md's five open questions were resolved with stated defaults for planning purposes (see SPEC.md and `tasks/plan.md`'s architecture decisions above). Flag now if any should change before Task 1 starts.
