# Research & Reference Document List — JAZZ

**Project name:** JAZZ
**Built by:** Akash Navet, Holy Cow Studios Pvt Ltd, and Claude

## 0. Concrete gotchas found (31 Aug 2026 second research pass) — read before Task 1

These are operational findings, not just references — things that would likely have cost real debugging time if discovered mid-build instead of now.

- **WHPX cannot render an OVMF/UEFI graphical framebuffer on this host at all — confirmed 2 Sept 2026, broader than the originally-documented pflash bug.** The standard `-drive if=pflash,format=raw,file=OVMF_CODE.fd` invocation fails under `-accel whpx` with `WHPX: Failed to emulate MMIO access` — a long-standing QEMU bug ([#513](https://gitlab.com/qemu-project/qemu/-/issues/513)), and the documented fix is `-bios OVMF_CODE.fd` instead of the pflash syntax. **That fix alone was not sufficient on this machine.** Extensive Task 3 testing (many isolation tests: with/without pflash, with/without disks, q35 vs i440fx, a hand-verified-correct monolithic OVMF build sourced from `retrage/edk2-nightly`) found WHPX simply never draws anything to the display under any OVMF/UEFI graphical boot path — the firmware runs correctly (real CPU burn; the exact same firmware rendered the actual UEFI boot-device menu perfectly under `-accel tcg`), WHPX just doesn't display it. **Working fix: bypass firmware graphics entirely.** Use QEMU's direct kernel boot (`-kernel <vmlinuz>`, `-initrd <initramfs>`, `-append "console=ttyS0,115200 ..."`), which boots via SeaBIOS (legacy BIOS) straight into the kernel — no firmware boot menu is ever rendered, so the broken WHPX graphics path is never exercised — with output captured as plain text over a serial console instead of a framebuffer. See `vm/launch-dev-vm.ps1` and `vm/README.md` for the working implementation. **Important consequence:** the live installer environment this boots is BIOS-mode, not UEFI (`/sys/firmware/efi` won't exist in that session) — but SPEC.md requires the *installed target system* to be UEFI (systemd-boot). Task 4/5 must explicitly verify archinstall still produces a correct UEFI target regardless of how the live environment itself booted — don't assume this is automatic.
- **No TAP networking on Windows QEMU.** User-mode NAT (`-netdev user`) is the practical default. This means `ping`-based host↔guest reachability checks won't work (no ICMP under user-mode NAT) — use an SSH port-forward or similar for any verification script that needs to confirm the guest is reachable.
- **Iterative test-cycle workflow: use qcow2 backing-file overlays, not full reinstalls.** Build the base install once into a backing image, then `qemu-img create -f qcow2 -b base.qcow2 -F qcow2 test.qcow2` per test run; delete/recreate the overlay to reset instantly. Snapshot right after a clean Arch install, before running this project's own scripts.
- **Check `/etc/mkinitcpio.conf`'s `MODULES=()` explicitly during Stage 1** rather than assuming virtio modules are picked up automatically — usually fine via the `autodetect` hook, but occasionally needs a manual addition per community reports.
- **archinstall: Hyprland is a built-in profile**, not something needing a custom one (`archinstall/default_profiles/desktops/hyprland.py` ships in the official repo). Use archinstall's own interactive mode once, choose the Hyprland desktop profile, then use its **"Save configuration" export** as the unattended JSON config — don't hand-author the JSON from scratch, since hand-edited configs are known to crash `--silent` mode. AI tooling (Podman/Python/Ollama) and Quickshell/dotfiles belong in a **separate idempotent bash script layered on afterward**, matching every comparable project researched — not crammed into one custom Python profile, even though archinstall's `custom-commands` option technically supports that.
- **archinstall + Btrfs encryption has known bugs** (encryption sometimes silently not applied, compression requests ignored — [#3975](https://github.com/archlinux/archinstall/issues/3975), [#1031](https://github.com/archlinux/archinstall/issues/1031)). Not relevant now (no encryption in Phase 1 scope) — flag for whenever Stage 7 security hardening picks back up.
- **This exact GPU (Intel Arc 140V, PCI ID `64a0`) is known to fall back to pure software rendering** on some kernels — an Arch forum thread on this specific chip confirms a kernel warning "not officially supported by xe driver in this kernel version." Fix when it matters: boot parameters `xe.force_probe=64a0 i915.force_probe='!64a0'`. **Not relevant to the current QEMU VM work** (no GPU passthrough to the guest) — flag for whenever bare-metal/dual-boot is revisited. Suspend/resume is also a known weak spot on this CPU generation (stuck-at-400MHz-after-resume reports) — same "not blocking now, relevant later" status.
- **Post-install updates: no migrations system needed for v1.** `git pull` + re-run the (already-required-to-be-idempotent) install script, with Snapper's existing auto-snapshot as the rollback safety net, is the honest simplest-thing-that's-safe answer — confirmed by comparing Omarchy's real migrations system (built because raw re-runs can't handle one-time non-idempotent changes) against this project's idempotency requirement, which avoids needing that system in the first place. Add a plain-text CHANGELOG for visibility. Revisit only if a real non-idempotent breaking change actually forces it.
- **Dotfiles: skip chezmoi.** It solves a multi-machine personal-dotfiles problem this project doesn't have. Write configs to reference `$HOME`/XDG variables natively — the pattern every comparable project (Omarchy included) actually uses. Add a **Gitleaks pre-commit hook** (`gitleaks detect --staged`) from the first commit as a cheap, near-zero-maintenance automated backstop, on top of (not instead of) writing configs genericized from the start.


**Purpose:** curated, phase-ordered references to consult while actually building — prior art repos, official docs, and the specific pages that answer questions this project will hit. Supersedes/extends the original blueprint's §23 reading list with what the "shippable product" research (31 Aug 2026) surfaced.

**How to use this:** each entry says *when* you'll need it, not just what it is. Don't read this front-to-back — pull the relevant section when a task actually requires it, per the spec's context-engineering approach.

---

## 0b. Design research findings (31 Aug 2026 third research pass) — read before Stage 5

Reality-checks and concrete architecture recommendations for the desktop/interface layer, against the original blueprint's §6 design vision.

- **Hyprland's "functional animation" vision (§6.4) splits roughly in half.** Workspace-transition and border-color behaviors (trust-domain transitions, red border for offensive VMs) are achievable natively via Hyprland's `windowrule = <action>, match:<property>` syntax (the current form — `windowrulev2` is now deprecated), which re-evaluates live as window properties change; states Hyprland has no native concept of (network status, external-access indication) need a script reacting to Hyprland's own event socket (`.socket2.sock`) and pushing updates via `hyprctl keyword` at runtime — purpose-built wrappers exist (`hyprwatch`, `hyprwhenthen`) rather than hand-rolling raw socket handling. The other half — the GPU-inference pulse, the lab-reset shield transition, network-topology animation — have no window to color at all; these are inherently **Quickshell-side custom widgets**, not Hyprland theming. Scope them as separate QML components from the start.
- **Theming architecture: build a small custom `Theme.qml` singleton, don't adopt Noctalia's or Omarchy's wholesale.** Noctalia's `ThemeService`/Matugen pipeline solves "match my terminal and GTK apps to my wallpaper" — a different problem than this project has. Omarchy's Quattro shell solves "replace 8 separate daemon processes with one plugin-based Quickshell process" — a good architectural idea, but not a theming pattern. The right-sized approach: a `Theme.qml` singleton exposing named state tokens (per-workspace color, trust-domain color, pulse color), driven by QML's standard `Behavior on <property>`, `ColorAnimation`, and `Transition` blocks — ordinary Qt Quick, nothing Quickshell-specific required.
- **Skip dynamic wallpaper-based theming (matugen) for the core design — use it only for non-semantic chrome, if at all.** matugen is the current standard tool for Material-You-style wallpaper color extraction and Quickshell has native support for it, but this project's design principle gives color deliberate *semantic* meaning (red = offensive VM, amber = external network) that only works if color is a designed, reliable signal — not something that drifts with whatever wallpaper is active. Omarchy's own choice validates this: it ships 22 curated static themes as the core experience, with dynamic wallpaper theming as an optional extra, not the default. Build a hand-designed static palette per workspace identity; consider matugen later, only for accent colors that carry no trust-state meaning.
- **Screen-reader compatibility is not currently achievable on Hyprland — reclassify from a goal to aspirational.** Orca (the standard Linux screen reader) depends on AT-SPI2/D-Bus integration that wlroots-based compositors like Hyprland haven't reliably implemented, unlike GNOME/KDE Wayland. The original blueprint's §6.5 phrasing ("screen-reader compatibility *where feasible*") turns out to be doing real, load-bearing work — as of 2026 this isn't feasible on this compositor without upstream changes outside this project's control. Don't plan build time against it.
- **Reduced-motion mostly works, with one real gap:** `animations:enabled = false` in `hyprland.conf` globally disables animations, but trackpad swipe-gesture animations are a confirmed open Hyprland bug that this setting doesn't cover ([hyprwm/Hyprland#3878](https://github.com/hyprwm/Hyprland/issues/3878)). No off-the-shelf desktop-wide `prefers-reduced-motion` signal exists that both GTK/Qt apps and a custom Quickshell shell would automatically share — building that link is project-specific plumbing, not a checkbox.
- **High-contrast/scaling is achievable but is genuinely three separate systems to keep in sync** (GTK, Qt/QML, and XWayland legacy apps each theme independently) — plan real coordination work, not one global toggle.
- **Keyboard-only operation is the strong point, as expected** given Hyprland's tiling-by-design nature — no evidence of Quickshell widgets categorically requiring a mouse, just deliberate keybinding design per widget.
- **AI Command Centre dashboard (§6.3): most of it is buildable now, but the GPU panel specifically is blocked on upstream tooling, not a build task.** `GET http://localhost:11434/api/ps` (Ollama) gives loaded models with VRAM/context/quantization, trivially pollable. `podman stats --no-stream --format json` gives per-container CPU/mem/network cleanly. CPU/memory/temperature/power are standard `/proc`/`/sys` reads (reference `tomgonz/quickshell-simpleperfmeters` for a low-overhead pattern). **But Intel's own GPU tooling doesn't expose VRAM/utilization for Xe-driver GPUs** (confirmed: `intel_gpu_top` explicitly says use `gputop` instead, and even that doesn't expose utilization/memory on Xe) — no confirmed-working tool exists yet for this exact hardware (`xpu-smi` is untested, worth verifying directly before relying on it). Scope the dashboard's v1 to CPU/mem/temp/power + Ollama model list + Podman container status; treat the GPU-utilization panel and the "pulse on active inference" animation as blocked until either `xpu-smi` is verified or GPU work moves to NVIDIA hardware where `nvidia-smi` solves this trivially.

## 1. Needed now — Stage 1 (manual install) and repo scaffolding

- **ArchWiki Installation Guide** — <https://wiki.archlinux.org/title/Installation_guide> — the manual install walkthrough, still the correct starting point per the research addendum
- **archinstall (ArchWiki)** — <https://wiki.archlinux.org/title/Archinstall> — Arch's own official scriptable installer; this is the mechanism v1's "install script" should likely be built on, not a raw bash script from scratch
- **archlinux/archinstall (GitHub)** — <https://github.com/archlinux/archinstall> — source, `--script` parameter, works as a Python library
- **archinstall profile system** — <https://deepwiki.com/archlinux/archinstall/2.3-profile-system> — how to define a custom JSON-driven profile (this is how the desktop/AI-core packages would get pre-selected for someone running this project's installer)
- **QEMU Windows Hypervisor Platform docs** — <https://www.qemu.org/docs/master/system/whpx.html> — host-side VM setup reference

## 2. Needed now — prior art to actually read, not just cite

Read these repos' `install.sh`/profile structure directly before writing this project's own — don't reinvent what's already a proven pattern:

- **basecamp/omarchy** — <https://github.com/basecamp/omarchy> — the strongest prior art: bootstrap script → clone → `install.sh` sourcing ordered modules (`preflight/`, `packaging/`, hardware-specific handling); minimal README pointing to a full manual; MIT licensed
- **JaKooLit/Arch-Hyprland** — <https://github.com/JaKooLit/Arch-Hyprland> — dotfiles + `install.sh` pattern, widely used, good README convention reference
- **JaKooLit/Hyprland-Dots** — <https://github.com/JaKooLit/Hyprland-Dots> — README structure specifically (demo video, quick-install one-liner, screenshots linked out rather than inlined)
- **sudorook/archlinux** — <https://github.com/sudorook/archlinux> and **rickellis/ArchMatic** — <https://github.com/rickellis/ArchMatic> — smaller, simpler script-only examples if Omarchy's module system feels like more than is needed at v1 scale
- **noctalia-dev/noctalia** — <https://github.com/noctalia-dev/noctalia> and **CachyOS/cachyos-hypr-noctalia** — <https://github.com/CachyOS/cachyos-hypr-noctalia> — reference for how a Quickshell shell gets packaged/versioned independently of the distro config layer wrapping it

## 3. Needed now — desktop layer (Stage 5)

- **Hyprland Wiki** — <https://wiki.hypr.land/> — pin to the tagged release matching whatever version actually ships, per the research addendum
- **Hyprland Window Rules** — <https://wiki.hypr.land/0.41.2/Configuring/Window-Rules/> — the current `windowrule = <action>, match:<property>` syntax for dynamic border-color/state behaviors
- **Hyprland IPC** — <https://wiki.hypr.land/IPC/> — the event socket (`.socket2.sock`) for reacting to state Hyprland has no native concept of
- **hyprwatch** — <https://github.com/VirtCode/hyprwatch> and **hyprwhenthen** — run scripts on Hyprland events without hand-rolling raw socket handling
- **Quickshell** — <https://quickshell.org/> (may 403 to automated fetches — use the mirror below if so) — <https://git.outfoxxed.me> (`quickshell-mirror/quickshell` on Forgejo)
- **Qt 6.8 LTS QML docs** — <https://doc.qt.io/qt-6/qmlapplications.html> — target the LTS docs specifically, not general Qt docs
- **Qt Quick Transitions / ColorAnimation** — <https://doc.qt.io/qt-6/qml-qtquick-transition.html> — the primitives the project's own `Theme.qml` singleton should be built on
- **quickshell-simpleperfmeters** — <https://github.com/tomgonz/quickshell-simpleperfmeters> — reference pattern for low-overhead `/proc`/`/sys` system-monitor widgets
- **Ollama API: list running models** — <https://docs.ollama.com/api/ps> — `GET /api/ps` for the AI Command Centre's model/VRAM panel
- **Podman stats** — <https://docs.podman.io/en/stable/markdown/podman-stats.1.html> — `podman stats --no-stream --format json` for the container-status panel
- **matugen** — <https://pypi.org/project/matugen> — only if dynamic accent theming is added later for non-semantic chrome; not for the trust-state color system itself
- **PipeWire** — <https://docs.pipewire.org/>

## 4. Needed now — AI engineering layer (Stage 6, CPU-first)

- **PyTorch local installation** — <https://pytorch.org/get-started/locally/> — pin to CUDA 12.8+/13.0 pairing when the GPU-validation task comes up
- **Ollama documentation** — <https://docs.ollama.com/>
- **llama.cpp** — <https://github.com/ggml-org/llama.cpp>
- **Podman** — <https://podman.io/> — rootless setup specifically
- **NVIDIA Container Toolkit CDI support** — <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html> — needed only at the GPU-cloud-validation task; note the `/etc/nvidia-container-runtime/config.toml` rootless gotcha flagged in the research addendum

## 5. Needed now — AI red-teaming (§9.2, kept in scope)

- **Garak** — <https://github.com/NVIDIA/garak/>
- **PyRIT** — <https://github.com/microsoft/PyRIT> (corrected from the original blueprint's `Azure/PyRIT`, which is archived)
- **OWASP GenAI Red Teaming Guide** — <https://genai.owasp.org/resource/genai-red-teaming-guide/>
- **OWASP GenAI LLM Top 10 2026** — <https://genai.owasp.org/resource/owasp-genai-llm-top-10-2026/>

## 6. Needed now — filesystem/recovery (Stage 2 extension)

- **Btrfs + Snapper + grub-btrfs pattern** — <https://www.dwarmstrong.org/btrfs-snapshots-rollbacks/> — the concrete setup walkthrough referenced by the research addendum

## 7. Needed now — licensing and repo hygiene, before the first public push

- **Choose a License (MIT)** — <https://choosealicense.com/licenses/mit/> — for original scripts/configs
- **Arch RFC 0040 — Licensing package sources** — <https://rfc.archlinux.page/0040-license-package-sources/> — 0BSD is what Arch itself now uses for PKGBUILD sources; mirror this for any PKGBUILDs this project writes, rather than defaulting to MIT for those specifically
- No CODE_OF_CONDUCT/CONTRIBUTING/issue templates needed yet — every project researched added these only after gaining outside contributors, not at first release

## 8. Deferred — only needed if/when a custom ISO becomes worth building

Do not read these for v1. They're here so they're easy to find later, once there's real demand for a GUI-first onboarding experience beyond a script:

- **archiso** — <https://wiki.archlinux.org/title/Archiso>
- **ALCI (Arch Linux Calamares Installer)** — <https://alci.online/> — community tooling that patches the Arch/Calamares partitioning incompatibility
- **Calamares** — <https://github.com/calamares/calamares>
- **ArcoLinuxISO's documented archiso+Calamares maintenance workflow** — <https://www.arcolinuxiso.com/updating-archiso-and-calamares-workflow-process/> — realistic picture of the ongoing work this represents
- **archiso GitHub Actions pattern** — <https://github.com/nlhomme/archiso-builder> — containerized `mkarchiso` in CI
- **GitHub larger-runner nested virtualization** — <https://github.com/orgs/community/discussions/160591> — needed for CI boot-testing an ISO; free-tier runners don't have this
- **Actuated (KVM-backed CI runners)** — <https://actuated.com/blog/kvm-in-github-actions> — paid third-party alternative if boot-testing is needed before qualifying for GitHub's larger runners

## 9. Deferred — conventional red-team lab layer

Per `Blueprint_Phase1_AI_Engineering_First.md` §4, this whole layer is out of scope until a nested-virt-capable environment exists. When it's picked back up, the original blueprint's §23.8–23.9 reading list (QEMU/libvirt, Qubes architecture, Kali tools) is still the right starting point — no update needed there yet.

---

## Where this list came from

Sections 1–7 are grounded in four parallel research passes (31 Aug 2026) into: comparable shipped solo/small Arch-based distro projects, CI/CD practices for archiso, OSS repo/documentation standards for distro-type projects, and installer approach (script vs. custom ISO). All four converged independently on the same conclusion — ship a documented install script on vanilla Arch first, defer the custom-ISO/Calamares/signing-infrastructure work — which is why section 8 is explicitly marked deferred rather than folded into the main build path.
