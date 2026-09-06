# JAZZ v2 — Forward Planning

**Status:** Living backlog for what comes after v1 (Phase 1, `SPEC.md`). Not scoped into concrete tasks yet - items here get promoted into real `tasks/todo.md` entries only once Akash is ready to commit to building them. Add to this file as new v2 ideas come up; don't start building against any of them without a real scoping conversation first.

**Built by:** Akash Navet, Holy Cow Studios Pvt Ltd, and Claude

---

## 1. What v1 actually is (context for building v2 from it)

v1's own spec (`SPEC.md`) and full task history (`tasks/todo.md`) are the authoritative record - this section is a compressed summary so v2 planning doesn't have to re-derive it from scratch.

**Install mechanism:** a documented bash script chain (`scripts/install-jazz.sh`) run after booting the *official vanilla Arch ISO* + `archinstall` - deliberately not a custom-built ISO. This matched what every comparable project studied seemed to do at the time it was decided (31 Aug 2026) - since corrected (7 Sept 2026): Omarchy specifically *does* ship a real, actively-maintained custom ISO (`omacom/omarchy-iso`). See §2 below - this is v2's lead item.

**Architecture, as it stands:**
- **Base OS:** Arch Linux, Btrfs + Snapper (snapshot/rollback), systemd-boot, UEFI-only
- **Desktop:** Hyprland (compositor) + Quickshell/QML (shell) - JAZZ owns its own `hyprland.lua` base config (Task 21) after discovering Hyprland's package auto-generates a stock one that silently ate every prior config attempt
- **Theme system:** `Theme.qml` singleton - six workspace identity colors (Forge/Lab/Arena/Observe/Vault/Range, per `Design-Vision.md` sec 2) that stay *constant* across light/dark mode by design (they're a semantic signal, not chrome); `panel`/`panelInk` chrome tokens are the actual dark/light toggle
- **Shell surfaces (`configs/quickshell/shell.qml`):** a top bar that retints to the active workspace's color live (JAZZ's real visual signature - none of Windows/macOS/Omarchy do this), an always-visible dock (macOS-style: pinned + currently-running apps combined, real icons, running-dot), a native app launcher (workspace-color-themed, real icons, real `.desktop`-file backed - not wofi, not a hardcoded list), a split Settings system (shallow quick-toggles flyout + a real multi-section Settings panel: Appearance/Network/Bluetooth/Sound/Display), a Tier-1 widget stack (World clock/Notes/To-do/Pomodoro) with a real per-widget edit/toggle panel
- **Real app discovery:** `configs/quickshell/scan-apps.py` - a genuine XDG `.desktop` file scanner (not a hardcoded app list), the single source of truth for the dock and launcher; a newly-installed package just appears on the next scan, no code changes needed
- **Wallpaper:** `configs/quickshell/gen_wallpaper.py` (Pillow) generates a real JAZZ-branded dark/light pair - calm neutral base, subtle Forge-blue glow, a restrained waveform motif nodding to "Jazz" as music - set via `swaybg` (hyprpaper's own IPC genuinely doesn't work against this Hyprland build, confirmed live)
- **AI engineering stack:** rootless Podman, Ollama, a pinned AI-core container (CPU-verified; GPU/CUDA verification against real NVIDIA hardware still pending - v1's Task 16), PyRIT red-teaming against the local Ollama model
- **Verification discipline:** every setup script has a matching `scripts/verify/*.sh` - the closest thing v1 has to a regression suite; 42/42 passing on real hardware (Lenovo Yoga 6, Ryzen 7 4700U) as of the last full checkpoint

**What v1 explicitly does NOT have yet (known, tracked gaps at the time of this writing):**
- A fixed, deep root-cause fix for AMD ACP audio not initializing on the Yoga 6 (`tasks/todo.md` Task 24)
- Real GPU/CUDA verification of the AI-core container on actual NVIDIA hardware (Task 16 - drafted, not executed, waiting on Akash finding a real GPU machine or renting one)
- A finished design pass - Task 22/23's dock/launcher/settings/wallpaper rebuild is functionally complete and live-verified, but Akash's own words closing that session were "we need to improve design of jazz for sure, i would research more" (tracked as the deliberately-unscoped Task 25)
- Public-repo readiness (README, LICENSE/CHANGELOG, hygiene gate, clean-clone rebuild test - `SPEC.md`'s Phase 4)
- Tier 2-4 of the daily-life widget backlog (`Design-Vision.md` sec 6) - screenshot tool, quick-settings restyle, now-playing/battery/network/clipboard *widgets* specifically (note: now-playing/notifications/clipboard/wifi/battery already exist as real top-bar *tray icons*, built ad hoc during Task 22 - but not as the dedicated widget-stack entries Design-Vision.md sec 6 originally described)

---

## 2. Custom bootable ISO with JAZZ branding

Recorded 7 Sept 2026. Akash wants JAZZ to eventually ship its own bootable ISO - its own boot logo/splash, packages baked in - rather than v1's "script on vanilla Arch" method, "like Omarchy."

**Real correction made the same day** (see `docs/Research-Reference-List.md` sec 8): the research this project did back on 31 Aug 2026 concluded no comparable small/solo Arch-based project ships a custom ISO. That conclusion was wrong. Confirmed live via `gh api`: Omarchy has a real, actively-maintained custom ISO - `omacom/omarchy-iso` (265 stars, MIT licensed, its own branches for OEM install / dual-boot / Steam Deck variants), distributed from `iso.omarchy.org`. There's even third-party tooling (`tahayvr/omarchyiso`) for customizing an Omarchy ISO further. This doesn't erase the real cost of doing this - it removes the false premise that a solo/small project can't reasonably carry it.

**What it would actually take (per the original research, still accurate on the cost side):**
- `archiso` - Arch's own ISO-building toolkit, to bake JAZZ's packages + install chain into a bootable image
- A Plymouth boot splash - JAZZ's own logo/animation during boot, not a generic Arch one
- Signing infrastructure - a bootable ISO people download needs to be signed/verified
- CI boot-testing - needs nested-virtualization-capable runners (GitHub's free tier doesn't have this; either its larger runners or a paid alternative like Actuated)

**Not scoped as a numbered task yet** - deliberately, since this is a real undertaking on the scale of the Task 22 rebuild (a full dedicated pass), not a quick add. When Akash is ready to commit to it, give it its own task number and real acceptance criteria rather than starting speculatively.

---

## 3. (Space for more v2 items as they come up)
