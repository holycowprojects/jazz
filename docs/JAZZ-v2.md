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

## 3. What Omarchy's "Beautiful, Fun & Agentic" actually means, and what JAZZ v2 should learn from it

Recorded 7 Sept 2026, after Akash asked to research Omarchy's own positioning more deeply. Confirmed via `gh api` (issue/PR history on `omacom/omarchy-iso`), not guessed:

**The tagline itself evolved.** "Beautiful, Fun & Agentic Linux by DHH" started as "Beautiful, Fun & **Opinionated**" (issue #136) and changed to "...Agentic" (issue #144) as AI coding agents became central to the product - it was never a founding principle, it's a repositioning as the ecosystem shifted. Worth noting for JAZZ too: positioning can and should evolve as the product does, not be fixed on day one.

**"Beautiful" - concrete execution:** 22 built-in themes, each a *complete bundle* - wallpaper, terminal, Neovim, btop, browser, and the entire shell chrome (top bar, menu, notifications, OSD, even the lock screen) restyle together as **one atomic switch** (`Super+Space` → Style → Theme), not a wallpaper change with some chrome colors following along. Separately, there's a funded "Artist In Residence" program ($2,500/month, 6 months) paying outside artists to build themes/plugins - visual design treated as an ongoing, named product surface with its own contributor path, not a one-off task.

**"Fun" - concrete execution:** a retro Winamp-style music player bundled alongside serious tools (Neovim, Chromium, Obsidian) - a deliberate, slightly absurd personality touch. Documentation voice is conversational and self-aware ("Neovim (btw)"). Fun lives in small, specific, deliberate touches and in tone of voice - not in doing more.

**"Agentic" - concrete execution, and the important one:** this is **literal AI-coding-agent integration**, not a vague nod to user agency/hackability. Pre-wired launcher commands for ~10 coding agents as first-class citizens (`claude`, `codex`, `copilot`, `agy`/Google Antigravity, `crush`, `grok`, and more via `omarchy-mise-install`), a `omarchy default agent <name>` picker, and a genuinely distinctive feature: **crashing processes can auto-route their logs to your chosen AI agent for diagnosis**. Their own definition of "agentic" is tools that *autonomously execute*, not just chat/suggest.

**What this means for JAZZ v2, decided:**

1. **JAZZ already has the stronger, more literal claim to "agentic" than Omarchy does** - Ollama/PyTorch/PyRIT are real AI-*engineering* infrastructure (building and red-teaming AI systems), not coding-assistant launchers (using AI to write code faster). Don't just copy the word - earn it differently: *Omarchy is the OS where agents help you build; JAZZ is the OS where you build agents.* Lead with that distinction in any future JAZZ positioning/README copy.
2. **Theme system is JAZZ's single biggest concrete visual gap** vs. Omarchy's actual execution. JAZZ's current dark/light toggle is far short of "one switch restyles wallpaper + terminal + shell + lock-screen together, with a picker." Build JAZZ's eventual theme system around the six existing workspace identity colors (Forge/Lab/Arena/Observe/Vault/Range) as the *seed* for full bundles, not just chrome tokens - this is a real v2 task once scoped, bigger than Task 25's polish pass.
3. **Worth adopting near-verbatim: a multi-agent coding-tool launcher** (`jazz default agent <name>`-style, wrapping Claude Code/Aider - Track C's `setup-aider.sh` already exists as a starting point) - JAZZ has the AI-engineering backend already, missing this day-to-day convenience layer.
4. **Worth adopting near-verbatim: crash-to-agent auto-diagnosis** - route a crashing process's logs to the user's chosen coding agent for analysis. Low effort, high "agentic" credibility, fits JAZZ's identity naturally. Concrete mechanism (explained to Akash 7 Sept 2026): `systemd-coredump` already captures crash dumps/logs for every crashed process on any systemd system, JAZZ included - nothing new needed there. A small hook (a systemd unit or a script watching `journalctl` for crash events) fires on a crash, extracts the relevant log lines/stack trace, and pipes them to an AI model for diagnosis - surfaced via a `dunst` notification (already running, Task 22), click to see the full explanation. **JAZZ-specific choice, not a copy of Omarchy's**: default this to the local Ollama model, not a cloud coding agent - fully offline, and it's a more on-brand "agentic" story for an OS whose whole identity is *local* AI engineering, not calling out to a cloud assistant.
5. **JAZZ currently has zero deliberate "fun" touches** - cheap to add, currently absent. Jazz/music motifs are a natural, unclaimed lane here (distinct from Omarchy's Winamp reference) - one deliberate personality touch (a retro toy app, an easter-egg command, a distinctive boot/login message) would go a long way. Doesn't need to be extensive, just deliberate and specific to JAZZ's own identity.
6. **A funded contributor program (AIR) isn't directly replicable at JAZZ's scale**, but the underlying move - treat visual/theme design as an explicit, ongoing, named workstream with its own path for outside contribution once public, not a one-off task buried in a general todo list - is worth adopting in spirit (e.g. a future `docs/JAZZ-Themes.md` once the repo is public).

## 4. More v2 ideas (Claude's proposals, 7 Sept 2026, none built yet)

Akash asked for more forward-looking ideas beyond the Omarchy research above. These lean on infrastructure JAZZ already has (Ollama, PyRIT, Podman, Snapper, the Quickshell shell built in Tasks 21-23), rather than inventing new dependencies.

**a. Build the AI Command Centre - already fully designed, never built.** `Design-Vision.md` sec 4 specs this in detail (CPU/mem/temp/power via `/proc`/`/sys`, Ollama's loaded model/context/quantization via `GET /api/ps`, Podman per-container stats via `podman stats --format json`, GPU utilization deliberately shown as pending-not-faked) - it was written 31 Aug 2026 and never actually built. Tonight's Task 22 work (`Process` + `SplitParser`/`StdioCollector` polling patterns, already proven live for network/Bluetooth/volume/brightness) is exactly the mechanism this needs - there's no new technique to learn, just apply the same pattern to a new data source. This is probably the single highest-leverage v2 item: real, substantial, and the design work is already done.

**b. Fully-local natural-language OS control - a genuinely agentic feature, no cloud dependency.** A hotkey opens a prompt ("Jazz, open Firefox" / "Jazz, what's eating my CPU" / "Jazz, kill the frozen window"), routed to the local Ollama model, which either answers directly or *executes* a real action (matches Omarchy's own definition of "agentic" - autonomous execution, not chat) via Hyprland's dispatchers/`hyprctl`/shell commands. This is more ambitious than Omarchy's coding-agent launchers and more distinctive: a privacy-preserving, fully-offline agentic desktop-control layer is not something Windows/macOS/Omarchy have at all. Real risk to design carefully: an LLM executing arbitrary commands needs a constrained action-set (a fixed list of safe operations it can call, not raw shell access) - this is the actual design problem to solve if this gets scoped, not the AI integration itself.

**c. A visual Snapper/Btrfs rollback browser.** Track A already gives JAZZ real snapshot infrastructure (Snapper + snap-pac, auto-snapshotting every pacman transaction) - currently CLI-only (`snapper list`/`snapper rollback`). A Quickshell panel showing a visual timeline of snapshots (what changed, when, one-click preview/rollback) would be a genuinely "beautiful" feature built entirely on infrastructure that already exists and already works - no new backend, just a new front-end for real data, the same shape as Task 22's dock/launcher work.

**d. One concrete "fun" touch: a jazz-themed terminal MOTD.** Small, cheap, deliberate (per sec 3 above's finding that "fun" doesn't need to be extensive). A login/new-terminal greeting with a small ASCII-art motif (a saxophone, sound-wave bars matching the wallpaper's own waveform motif from Task 23) plus a rotating one-line jazz quote or trivia fact - genuinely unclaimed territory distinct from Omarchy's Winamp reference, ties back to the project's own name/identity rather than borrowing someone else's.

**e. Package update indicator, properly this time.** Already listed in `Design-Vision.md` sec 6 Tier 3 as backlog ("shows '12 updates available', never raw terminal output") and still not built as a dedicated widget - worth folding into whatever tier-2/3 widget pass eventually happens, using `checkupdates` (pacman-contrib, already a known dependency per that doc).

## 5. (Space for more v2 items as they come up)
