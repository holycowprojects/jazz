# Design Vision — JAZZ

**Status:** Pre-implementation alignment document. Written 31 August 2026, before any desktop work has started (Track B / Tasks 9–11 in `tasks/todo.md`). Purpose: capture the agreed design intent now, so implementation doesn't drift from it or require re-deriving it from scratch later.
**Built by:** Akash Navet, Holy Cow Studios Pvt Ltd, and Claude
**Grounded in:** the design research findings in `Research-Reference-List.md` §0b — every claim below about what's achievable is backed by that research, not aspiration.

This is a living document. If implementation reveals something here doesn't work as described, update this file first, then proceed — don't let code silently diverge from the recorded intent.

---

## 1. Design philosophy

Keyboard-first and calm by default. Color and animation do real work — they tell you something true about system state — rather than existing as decoration. A workspace switch, a border color, a pulse: each one should be honest. Where something can't be made real yet (GPU utilization, for instance), the interface shows a visible gap rather than a fake or misleading number.

## 2. Workspace identities

Each workspace has a **hand-designed static color**, not a wallpaper-derived one — dynamic theming (matugen) was deliberately rejected for this layer, because color here carries semantic meaning that only works if it's a reliable, designed signal (see Research-Reference-List.md §0b). Dynamic theming may still be added *later*, but only for non-semantic UI chrome, never for these identity colors.

| Workspace | Purpose | Color | Status in Phase 1 |
|---|---|---|---|
| **Forge** | Coding, AI app engineering | Cool slate blue | Active — the default, highest-traffic workspace |
| **Lab** | Notebooks, PyTorch/Jupyter experiments | Teal/green | Active |
| **Arena** | AI red-teaming (Garak/PyRIT against local models) | Amber — deliberately not red, since this is testing your own model, not a hostile boundary | Active (§9.2 stayed in scope) |
| **Observe** | Logs, metrics, the AI Command Centre | Muted grey-cyan — meant to recede, not compete for attention | Active |
| **Vault** | Secrets, sensitive config | Near-black, restrained accent — deliberately the least inviting workspace | Active |
| **Range** | Conventional cybersecurity red-team lab | Reserved red (held, not implemented) | **Dormant** — the identity exists in the design language now so it doesn't need to be invented later, but has no functional content until the red-team layer is picked back up |

## 3. Animation: two mechanisms, chosen honestly per behavior

Confirmed via research — roughly half of what "functional animation" can mean here is native Hyprland config; the other half is inherently a Quickshell-side widget. Don't fight the wrong mechanism for either kind:

- **Native Hyprland** (`windowrule = <action>, match:<property>`, live-reevaluating): window border colors tied to window class/workspace, workspace-transition styling. This covers, e.g., a border color keyed to which workspace a window lives in.
- **Quickshell custom widgets** (built on `Theme.qml`'s state tokens + standard Qt Quick `Behavior`/`ColorAnimation`/`Transition`): anything with no window to attach color to — the active-inference pulse, and (when Range becomes active later) the lab-reset shield transition and network-topology animation.
- **External state → Hyprland**, when needed: pushed live via `hyprctl keyword` reacting to Hyprland's own event socket, using `hyprwatch`/`hyprwhenthen` rather than hand-rolled socket code — this is how something like "amber border for external network access" would work, since network state isn't a property Hyprland tracks natively.

`Theme.qml` is a small custom singleton exposing named tokens (workspace color, trust-state color, pulse color) — not borrowed wholesale from Noctalia's palette-service architecture or Omarchy's plugin system, both of which solve different problems than this one.

## 4. AI Command Centre (Observe workspace dashboard)

Scoped to what's actually measurable on this hardware today, confirmed via research:

**Real now:**
- CPU / memory / temperature / power (standard `/proc`/`/sys` reads)
- Ollama: loaded models, VRAM-equivalent size, context length, quantization — via `GET /api/ps`
- Podman: per-container CPU/memory/network — via `podman stats --format json`

**Deliberately shown as pending, not faked:**
- GPU utilization / VRAM graph — Intel's own tooling (`intel_gpu_top`) doesn't expose this for the Xe driver this hardware needs; no confirmed-working alternative exists yet (`xpu-smi` untested). The dashboard shows this panel as explicitly blocked-on-upstream-tooling, not a number that doesn't mean anything.
- The "pulse indicates active GPU inference" animation from the original blueprint's §6.4 — same blocker; can still pulse on CPU-inference activity (which *is* measurable) until GPU monitoring becomes real.
- Token throughput — not an existing metric anywhere; would need to be computed client-side by timing Ollama's streaming response, not pulled from a source. Worth doing, just not free.

## 5. Accessibility — what's promised vs. honestly aspirational

- **Keyboard-only operation:** the strong point, by design — Hyprland is tiling/keybind-driven natively. Every Quickshell widget gets deliberate keybinding design, no exceptions.
- **Reduced motion:** works for compositor animations (`animations:enabled = false`), but does **not** cover trackpad swipe-gesture animations — a confirmed, still-open Hyprland bug, not a choice we're making. No off-the-shelf signal exists that both GTK/Qt apps and Quickshell would share automatically; building that link is project-specific plumbing, tracked as real work, not assumed free.
- **High-contrast / scalable text:** achievable, but GTK, Qt/QML, and XWayland legacy apps are three separate theming systems — plan real coordination work across all three, not one global toggle.
- **Screen-reader compatibility:** **not currently achievable on Hyprland** — Orca's dependencies (AT-SPI2/D-Bus integration) aren't reliably implemented on wlroots-based compositors as of 2026. This is reclassified from "planned" to "aspirational, blocked on upstream" — don't scope build time against it, and say so plainly in the README rather than implying it works.

## 6. Daily-life widget backlog (added 5 Sept 2026, Akash's request)

**Status: backlog, not yet broken into `tasks/todo.md` tasks.** Captured here first, deliberately, since Track B hasn't even confirmed Quickshell renders reliably under WHPX yet (Task 9 not started) — scoping individual tasks for 20 widgets before that's proven would be premature. Break these out once Task 10/11's single MVP widget is confirmed working end to end.

These sit **alongside**, not replacing, the AI Command Centre (§4) — the Centre stays Observe-workspace-scoped AI/dev telemetry (CPU/mem, Ollama, Podman, GPU-pending). These are daily-life/productivity widgets and most naturally belong on a persistent panel visible across all workspaces, rather than tied to one workspace's identity color.

Grouped by what each actually requires to build — sequence roughly Tier 1 → Tier 2 → Tier 3 → Tier 4, since dependency risk rises each tier:

**Tier 1 — pure local, no external dependency:**
- Clock (large digital/analogue + date) — the likely Task 10 pick
- World clock (same widget, multiple timezones)
- Notes / sticky notes
- To-do widget
- Pomodoro timer

**Tier 2 — wraps an existing Hyprland-ecosystem tool (Quickshell UI over an existing backend):**
- Screenshot widget → `grim`/`slurp` (full/area/window), `wf-recorder` for recording
- App launcher → a rofi/wofi-style launcher, restyled
- Clipboard history → `cliphist`
- Quick settings panel → NetworkManager/BlueZ/`brightnessctl`/`wpctl` wrapped in one panel
- Notification centre → Hyprland's own notification protocol, or a `mako`/`swaync`-equivalent

**Tier 3 — standard Linux desktop APIs, well-trodden, no external service:**
- Now Playing (Spotify/YouTube Music/MPD/browser) → MPRIS covers all of these uniformly
- Volume mixer (per-app) → PipeWire/WirePlumber
- Battery widget → `upower`/`/sys/class/power_supply`
- Bluetooth devices panel → BlueZ
- Network widget (Wi-Fi strength/SSID) → NetworkManager
- Storage widget → `df`/`statvfs`
- Recent files widget → XDG recently-used tracking
- Package update indicator → `checkupdates` (pacman-contrib) — shows "12 updates available", never raw terminal output

**Tier 4 — needs a real external service/API (genuine integration work, plus a design call on offline behavior and API keys):**
- Weather (current + hourly + rain chance + sunrise/sunset) — needs a weather API + a location source
- Calendar + agenda — needs a real backend (CalDAV, Google Calendar, or a local `.ics`) to be more than decoration
- Currency converter — needs a live FX-rate API

## 7. What this document is for

Read this before starting Tasks 9–11 (Hyprland desktop, Quickshell, `Theme.qml` + first animation proof) in `tasks/todo.md`. If something here turns out wrong once real implementation starts, fix this document first — it should stay the accurate record of intent, not a stale aspiration next to code that quietly does something else.
