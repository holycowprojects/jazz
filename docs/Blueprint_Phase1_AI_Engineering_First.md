# Phase 1 Blueprint — JAZZ (Arch AI Engineering OS, Red-Team Deferred)

**Project name:** JAZZ
**Built by:** Akash Navet, Holy Cow Studios Pvt Ltd, and Claude
**Status:** Working blueprint for the current build phase
**Date:** 31 August 2026
**Supersedes (for this phase only):** narrows the scope of `Arch_AI_Engineering_and_Red_Team_OS_Blueprint.md` — that document remains the long-term vision; this one is what actually gets built first.
**Companion documents in this folder:**
- `Arch_AI_Engineering_and_Red_Team_OS_Blueprint.md` — original full vision, both AI engineering and red-team
- `Arch_AI_Engineering_and_Red_Team_OS_Blueprint_Research_Addendum.md` — fact-check of the original blueprint against Aug 2026 reality
- `Host-Requirements-Check.md` — (not yet written; see note at end) this machine's actual hardware/software capabilities

---

## 1. Why this phase exists

Two things came out of researching how to actually build this:

1. **A hard technical blocker on the full scope.** The red-team lab layer (§5.3/§9.1 of the original blueprint) needs the Arch host to run its own hardware-accelerated nested VMs (Kali, targets, AD labs). Confirmed via QEMU's own issue tracker: Windows Hypervisor Platform (WHPX) — the only virtualization backend available on this machine, since it's Windows 11 **Home** with no Hyper-V Manager — does not support nested virtualization. Building the red-team layer today would mean testing it in pure software emulation, 10–50x slower, effectively unusable for its own purpose.
2. **A scope decision.** Rather than solve that with a dual-boot install or a paid always-on cloud VM, the call was made to **defer the red-team lab layer entirely** and build the AI engineering track first. This sidesteps the nested-virt problem completely — nothing in the AI engineering track needs nested virtualization.

This document describes what actually gets built in this phase.

---

## 2. This machine's environment

| Fact | Value |
|---|---|
| OS | Windows 11 Home Single Language, build 26200 |
| CPU | Intel Core Ultra 7 256V, 8 cores / 8 threads |
| RAM | 15.6 GB total |
| Disk | 739 GB free on C: |
| GPU | Intel Arc 140V integrated (8GB shared). **No NVIDIA/AMD GPU.** |
| Hypervisor | QEMU with WHPX acceleration (Windows Hypervisor Platform). Chosen over VirtualBox: coexists cleanly with the WSL2 hypervisor already active on this machine, and is the same tool the long-term blueprint uses for its own red-team lab VMs later — one tool, learned once. |
| Virtualization status | Confirmed working — `systeminfo` shows an active hypervisor already claiming VT-x. No BIOS changes needed. |

**Implication for this phase:** a single QEMU/WHPX VM running Arch Linux, entirely local, is sufficient for everything in scope below. No nested virtualization, no cloud dev VM, no dual-boot.

---

## 3. In scope for this phase

Everything that doesn't require nested virtualization or a local GPU:

- **Boot & base system** — UEFI boot, standard + LTS fallback kernel (target 6.18 LTS), manual Arch install per ArchWiki before any automation
- **Desktop** — Hyprland + Quickshell animated Wayland shell, PipeWire, XDG portals
- **Native dev tools** — Git, compilers, build systems, debuggers
- **AI engineering layer** — rootless Podman, one reproducible PyTorch + JupyterLab environment, pinned dependencies/lockfiles
- **Local inference** — Ollama and/or llama.cpp, CPU-backed on this machine
- **AI red-teaming** (§9.2 of the original blueprint) — Garak and PyRIT probing your own locally-running model. Kept in scope deliberately: it needs no VMs, no extra infrastructure, and is a Python tool talking to a local Ollama endpoint — genuinely part of AI engineering competence, not the red-team lab layer.
- **Filesystem & recovery** — Btrfs subvolumes, Snapper snapshots, rollback testing
- **Build/release basics** — PKGBUILD, makepkg, archiso, package signing fundamentals (learned on this single VM, not yet a maintained repository)

### GPU/CUDA validation (deferred until actually needed, not blocking)

No NVIDIA/AMD GPU exists locally or in any VM on this machine. When the AI engineering track reaches GPU validation:
- The exact reproducible container/environment definition built for `os-ai-nvidia` gets run, unmodified, on a rented GPU (not an OS install — just the same Podman/Docker image).
- **Vast.ai** first choice on cost (RTX 4090 spot, ~$0.35–0.50/hr median), **RunPod** as the more-reliable fallback (~$0.34–0.69/hr, 99% uptime SLA).
- Expected cost: occasional validation sessions, roughly **$2–10/month**, not continuous. Account creation and payment are yours to handle — not something I do on your behalf.

---

## 4. Explicitly deferred to a later phase

- **Conventional red-team lab** (§9.1, §5.3) — Kali/target/AD-lab VMs, isolated libvirt networks. Blocked by the nested-virt finding above. Revisit when either: (a) a Linux host with real KVM becomes available (dual-boot this machine, or a different machine), or (b) a cloud VM with nested-virt support (GCP explicitly supports it; certain AWS 8th-gen families do too) is judged worth the recurring cost.
- **Full security-engineer hardening** (Stage 7 of the original blueprint: LUKS, Secure Boot, AppArmor, signed repo) — not urgent while this is a single learning VM with no red-team content on it. Worth doing eventually, not blocking AI engineering work.
- **Reversing/binary-analysis profile** (`os-reversing`) — no driver here yet.

---

## 5. Revised success criteria for this phase

Adapted from the original blueprint's §22.1, dropping the red-team-lab item and splitting the GPU item:

1. Build reproducibly enough to identify unintended differences
2. Boot reliably in the QEMU/WHPX VM
3. Install onto a clean virtual disk
4. Reach a working animated Hyprland/Quickshell desktop
5. Launch an isolated AI environment (rootless Podman + PyTorch + Jupyter)
6. Validate CPU-backed PyTorch operation locally
7. Validate GPU-backed PyTorch operation via a rented cloud GPU, against the same container definition
8. Run a local model through Ollama or llama.cpp
9. Run a basic AI red-team assessment (Garak or PyRIT) against that local model
10. Update and recover through a documented Btrfs/Snapper rollback

---

## 6. Cost summary

| Item | Cost |
|---|---|
| Local build (QEMU/WHPX VM on owned hardware) | $0 recurring |
| Cloud GPU rental (only once GPU validation is reached, occasional sessions) | ~$2–10/month |
| Cloud dev VM | Not needed in this phase |
| Dual-boot / new hardware | Not needed in this phase |

Effectively **$0/month until Stage 6**, then a few dollars a month only when actively validating the GPU profile.

---

## 7. Safety posture for this phase

Nothing in this phase's scope involves malware samples, exploit code, or vulnerable-target VMs — the categories of risk that motivated the earlier cloud-vs-local safety analysis. AI red-teaming here means sending adversarial *text prompts* to your own local model and reading its output — no code execution risk to the host beyond what any local LLM chat session already carries. The host-safety-sensitive design work (isolated networks, disposable VM boundaries, clipboard/USB controls for the red-team lab) is explicitly deferred along with that layer, and should be re-designed fresh when that phase actually starts — likely cloud-hosted from day one, per the earlier analysis, rather than retrofitted onto this machine.

---

## 8. Immediate next step once this is approved

Install QEMU for Windows (`winget install --id SoftwareFreedomConservancy.QEMU`), then do a fully manual Arch Linux install in a plain UEFI VM — no UKI, no Secure Boot, no Btrfs yet — following the ArchWiki Installation Guide end to end. That's Stage 1 of the learning progression, teaching partitioning, pacstrap, fstab, and the boot chain from first principles before any of this document's automation gets layered on top.
