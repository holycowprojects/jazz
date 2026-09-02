# Research Addendum — Arch AI Engineering and Red-Team OS Blueprint

**Note:** this project is now officially named **JAZZ**, built by Akash Navet, Holy Cow Studios Pvt Ltd, and Claude.
**Companion to:** `Arch_AI_Engineering_and_Red_Team_OS_Blueprint.md` (28 August 2026)
**This addendum's date:** 31 August 2026
**Purpose:** Verify the blueprint's technical claims against current reality, flag anything stale or wrong, surface what's emerged since it was written, and give concrete first steps per layer.

Findings below are organized by blueprint section. Each area was researched independently; version numbers and dates are as found during this research pass.

---

## 1. Desktop / Wayland stack (§6, §23.6)

**Still accurate**
- Hyprland remains the right pick for an animated, keyboard-first tiling compositor — current **v0.56.2** (5 Aug 2026), fast release cadence.
- Quickshell is real, active, and increasingly validated by the wider ecosystem: **v0.3.1** (20 Aug 2026). Omarchy (DHH's distro) rebuilt its shell on Quickshell in its Aug 2026 "Quattro" release; CachyOS shipped a Quickshell-based shell (Noctalia) in June 2026. This strengthens, not weakens, the blueprint's choice.
- PipeWire **1.6.6** and XDG Desktop Portals are unchanged as the correct audio/screen-share/app-integration layer.
- Qt **6.8 LTS** (support through Oct 2029) is the right QML target for a shell needing multi-year stability.

**Changed / needs correction**
- **`quickshell.org` returned HTTP 403** to automated fetches (likely bot-blocking, not dead). Add the canonical source as a secondary link: GitHub org `quickshell-mirror/quickshell`, hosted on Forgejo at `git.outfoxxed.me`.
- **Not in the blueprint: niri**, a Rust-based, memory-safe, scrollable-tiling Wayland compositor that's become a credible, calmer alternative to Hyprland through 2026. It has far less animation/ricing culture, so it doesn't beat Hyprland for this project's stated goals — but the ADR in §24 item 4 should name it as a considered-and-rejected alternative rather than leave the choice unstated.
- **Governance risk, not currently in the threat model:** Hyprland's lead developer has an active controversy history — banned from submitting to Freedesktop.org, recurring community-toxicity criticism, and a 2025 sponsorship backlash that pulled in Omarchy/DHH. This doesn't block technical use, but since the compositor sits in the *trusted host* (§5.1), §7 (package trust) and §10 (threat model) should explicitly note **upstream project-governance risk** as a factor, not just code quality.
- Pin `wiki.hypr.land` docs to the tagged release matching whatever Hyprland version actually ships in v0.1 — the wiki is versioned per-commit.

**First steps:** install Hyprland via a preconfigured setup to get a working reference system, then work through the Master Tutorial from first principles rather than keeping the preconfig. Build one small Quickshell widget (clock, workspace indicator) from its Getting Started guide before attempting the §6.3 "AI Command Centre" dashboard — that's a much bigger QML project.

---

## 2. Arch build/boot/release engineering (§11, §17, §23.2, §23.3)

**Still accurate**
- UKI + Secure Boot + LTS fallback kernel remains ArchWiki's recommended architecture. `mkinitcpio` now delegates UKI generation to `systemd-ukify` when installed — same tool, cleaner integration.
- `sbctl` is still the right assisted path for Secure Boot key enrollment and signing (`sbctl sign-all` after UKI generation — kernel-install plugins only sign the kernel, not the bootloader).
- `systemd-boot` remains the modern default for UEFI+UKI; GRUB stays relevant only for legacy BIOS/multi-OS chainloading, correctly out of scope here.
- PKGBUILD/makepkg/clean-chroot (via `devtools`) and `archiso` for ISO builds are unchanged as the standard toolchain — nothing has replaced them.
- Package signing model (`archlinux-keyring`, `pacman-key --refresh-keys`) is unchanged — routine key rotations only, no scheme overhaul.

**Changed / worth updating**
- **archiso v49+** (current early 2026) added accessibility support (screen-reader-friendly boot menu, 15s timeout) — worth adopting given the blueprint's own §6.5 accessibility goals.
- The official releng profile now ships bcachefs-tools alongside the systemd-boot default — not a requirement for this project, but signals bcachefs is now mainstream enough to be worth a line in the §12.1 filesystem comparison, even if Btrfs stays the pick.
- archiso gained **copytoram**, so live/rescue USB media can be safely unplugged after boot — useful for the recovery image work in §22.
- Current Arch ISOs ship **kernel 6.18 LTS** — target that as the fallback-kernel baseline, not an unspecified older LTS line.

**First steps (confirmed still correct):** 2–3 fully manual installs per the plain ArchWiki Installation Guide in a UEFI VM (no UKI, no Secure Boot, ext4) to build muscle memory first. Only after that, layer in UKI → sbctl → Btrfs → archiso, one at a time — each adds its own failure mode that's easier to diagnose alone.

---

## 3. AI/GPU stack (§8, §23.7)

**Still accurate**
- Ollama + llama.cpp remain the right default for single-user local inference — llama.cpp still has the widest backend list (CUDA, ROCm, Vulkan, SYCL, CPU).
- Rootless Podman + NVIDIA Container Toolkit is still correct; NVIDIA's CDI (Container Device Interface) via `nvidia-ctk` is the modern rootless path, actively maintained.
- JupyterLab as the reproducible dev environment is unchanged.

**Changed / needs updating**
- PyTorch stable is now **~2.11–2.12**, paired with CUDA 12.6/12.8/13.0 — the blueprint doesn't pin a version; the AI environment spec (§24 item 8) should say "target CUDA 12.8+/13.0" explicitly.
- **ROCm is more solid on Arch than the blueprint implies**: `rocm-core`/`rocm-opencl-runtime` **7.2.4** is now in Arch's official `extra` repo, not just AUR. This upgrades `os-ai-amd`'s realism as a first-class v0.1 profile — worth raising confidence in §7's profile table.
- **Missing from the blueprint entirely: vLLM.** By 2026 it's the standard answer once you move past single-user chat (PagedAttention/continuous batching gives ~16–20x Ollama's concurrent throughput). Worth an optional `os-ai-serving` profile for multi-agent/multi-session workloads.
- One concrete gotcha to document in §8.2: rootless GPU containers still need a manual edit to `/etc/nvidia-container-runtime/config.toml` even with CDI — not zero-config yet.

**First steps:** validate the GPU path *before* any desktop or container work — `pacman -S nvidia-open nvidia-container-toolkit` (or `rocm-hip-sdk` for AMD) → `nvidia-ctk cdi generate` → rootless Podman run of a CUDA/PyTorch base image → confirm `torch.cuda.is_available()`. Only then layer JupyterLab on top, matching the blueprint's own §22 success criteria #5–6.

---

## 4. AI red-team tooling (§9.2, §23.9)

All of the blueprint's document names and URLs check out — one real correction (PyRIT's repo location).

**Still accurate**
- **Garak** — actively maintained, v0.14.0 (Feb 2026), Apache 2.0, native Ollama support.
- **"OWASP GenAI LLM Top 10 2026"** is a real document, published 4 Aug 2026; the blueprint's URL is correct. Prompt Injection and Sensitive Info Disclosure top the list; Excessive Agency jumped to #3.
- **"OWASP GenAI Red Teaming Guide"** — real, URL correct, covers model/implementation/infrastructure/runtime testing as described.
- **MITRE ATLAS** — 16 tactics, 84 techniques, v5.1.0 (Nov 2025), still active at the cited repo.
- **Kali metapackages** — structure matches; Kali 2026.1 is current.

**Changed, needs correction**
- **PyRIT moved orgs.** The blueprint implies `Azure/PyRIT` — that repo was archived 27 March 2026 and now redirects to the canonical **`github.com/microsoft/PyRIT`**. `azure.github.io/PyRIT/` may still resolve via redirect but any spec naming the repo should say `microsoft/PyRIT`. Latest release v0.11.0 (Feb 2026), still MIT, still active.
- **Worth adding, not wrong just incomplete: Promptfoo.** Acquired by OpenAI (~$86M) in March 2026 but stayed MIT-licensed. YAML-declarative, 50+ vuln types, strong CI/CD fit — a good complement to Garak/PyRIT for automated regression testing of the OS's own AI-red-team profile.

**First steps:**
```
ollama serve   # ensure the target model is pulled and running locally
garak --model_type ollama --model_name <your-local-model> --probes dan.DAN_Jailbreak
```

---

## 5. Virtualization/isolation & supply chain (§10, §12, §17.1, §23.5, §23.8)

**Still accurate**
- Btrfs + Snapper remains the standard Arch snapshot/rollback pairing in 2026; combining with `grub-btrfs` gives one-command rollback from the boot menu.
- AppArmor is still the more Arch-native LSM choice (path-based, low setup cost) vs. SELinux — the blueprint's "investigate AppArmor or SELinux" framing holds, but AppArmor should be the default lean.
- Qubes OS is still Xen-based (4.2 line, no move to KVM) — remains the right *architectural reference to study*, not something to imitate directly on a single-host Arch design.
- QEMU/KVM + libvirt is still the correct, well-documented choice for disposable lab VMs.

**Changed / needs updating**
- Sigstore/cosign has graduated OpenSSF and is used by npm/PyPI/Homebrew, but mainstream Linux distro package signing (Debian, Fedora, and by extension Arch/pacman's GPG model) **has not moved off GPG**. Treat the blueprint's §23.5 Sigstore/TUF references as background reading for later, not a near-term replacement for pacman's signing in v0.1 — don't over-invest there yet.
- No lightweight alternative (Firecracker, systemd-nspawn) displaces QEMU/KVM+libvirt for *full* disposable attacker/target VMs — AD labs and Windows targets need real hardware/kernel isolation. systemd-nspawn is worth adding later as a *lighter* option for quick Linux-only resets, but shouldn't replace libvirt in the architecture.

**First steps:**
1. Partition with Btrfs subvolumes (`@`, `@home`, `@snapshots` minimum), install `snapper` + `snap-pac` (auto-snapshot on pacman transactions) + `grub-btrfs`.
2. `pacman -S qemu-full libvirt virt-manager dnsmasq iptables-nft`, enable `libvirtd`, add your user to the `libvirt` group, then `virsh net-define` a second **isolated** (no-forward) network distinct from the default NAT network — this gives the blueprint's "Isolated" vs "NAT" lab modes immediately.

---

## Summary: what to change in the blueprint itself

| Item | Action |
|---|---|
| PyRIT URL | Update to `github.com/microsoft/PyRIT` |
| Quickshell URL | Add `quickshell-mirror/quickshell` (Forgejo/GitHub mirror) as secondary source |
| niri | Add one line to the future ADR (§24 item 4) as a deliberately-rejected alternative to Hyprland |
| Hyprland governance risk | Add a line to §7 (package trust) and §10 (threat model) — trusted-host components carry upstream-governance risk, not just code-quality risk |
| Fallback kernel version | Target 6.18 LTS explicitly, not an unstated LTS line |
| ROCm confidence | Upgrade §7's `os-ai-amd` from "supported" framing to "first-class, now in official `extra` repo" |
| vLLM | Add as optional `os-ai-serving` profile for multi-session workloads |
| Promptfoo | Add to §9.2's tool list alongside Garak/PyRIT |
| PyTorch/CUDA pinning | §24 item 8 (AI environment spec) should pin a specific CUDA pairing, not leave it open |
| Sigstore/TUF | Reclassify from "candidate control" to "future research," not v0.1 scope |

## One consistent signal across all five research threads

Every fork's "first steps" converged on the same shape independently: **validate one narrow, isolated piece by hand before composing layers** — manual Arch install before archiso, plain UEFI boot before UKI+Secure Boot, GPU-in-a-container before the desktop shell, one Garak probe before a full red-team profile, one isolated libvirt network before a full lab. That matches the blueprint's own Stage 1 ("System builder") and its layered-trust architectural decision (§25) — the research didn't surface a reason to reorder the learning progression, only to update specifics within it.

**Concrete next action:** spin up a UEFI VM (VirtualBox, Hyper-V, or QEMU on Windows) and do a fully manual Arch install following the ArchWiki Installation Guide end to end — no UKI, no Secure Boot, no Btrfs yet. That's Stage 1, and every research thread above independently confirmed it's still the correct starting point.
