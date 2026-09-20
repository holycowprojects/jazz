#!/usr/bin/env python3
"""Real XDG .desktop file scanner for JAZZ's dock/launcher (Task 22).

Adapted from the real, working pattern in bjarneo/quickshell's AppScan.qml
(confirmed via research, not invented) - scans the standard XDG
application directories, skips NoDisplay/Hidden entries, strips %f/%F/%u/
%U/%i/%c/%k field codes from Exec, and emits one JSON array on stdout.

This is the single source of truth for "what apps are installed" - the
dock, any future all-apps view, and running-window-to-icon matching all
read from this same scan. A newly installed package's .desktop file is
picked up on the next scan with zero code changes - unlike a hardcoded
app list.
"""
import configparser
import glob
import json
import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor

DIRS = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
]

# The last two DIRS entries are Flatpak's own export dirs - anything found
# there is Flatpak-owned, everything else is pacman-owned (or unowned).
# Used by the launcher's right-click Update/Uninstall (20 Sept 2026,
# Akash's request) to know which package manager and which real
# package/app id to act on.
FLATPAK_DIRS = set(DIRS[2:])


def owning_pkg(desktop_path):
    """Real package-manager lookup, not guessed - `pacman -Qoq` asks pacman
    itself which installed package owns this exact file. Returns "" for a
    .desktop file pacman doesn't know about (hand-placed, or owned by
    something outside pacman's database)."""
    try:
        result = subprocess.run(
            ["pacman", "-Qoq", desktop_path],
            capture_output=True, text=True, timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip().splitlines()[0] if result.stdout.strip() else ""

FIELD_CODES = re.compile(r"%[fFuUick]")

# Task 25 design polish, 15 Sept 2026: real bug found live (Akash: "many
# apps needs icons") - Quickshell.iconPath()'s QIcon::fromTheme() lookup
# only reliably resolves icons an app ships bundled in the universal
# `hicolor` fallback theme. This session has no QT_QPA_PLATFORMTHEME
# integration (qt6ct isn't installed; Kvantum only styles QtWidgets apps,
# it doesn't drive icon-theme resolution) wiring the real active theme
# (Adwaita, confirmed via gsettings) into Qt's icon lookup - confirmed via
# real research (ArchWiki "Uniform look for Qt and GTK applications",
# Hyprland wiki's hyprqt6engine docs) before touching anything, same root
# cause already found and fixed for Files.qml's mimetype icons. Rather
# than depend on that uncertain runtime lookup at all, resolve every app's
# real icon file ONCE here, by walking the actual theme directories on
# disk - deterministic, verified, and reusable by every consumer of this
# scan (dock, launcher), not a one-off per-icon patch.
# 20 Sept 2026 addition: Flatpak (Bazaar) installs export their icons to
# these two dirs, never system-wide under /usr/share/icons - real bug
# found live (Akash: freshly Bazaar-installed apps like KStars/
# SeriousSamClassic showed no icon at all, since neither dir was in this
# list before). Appended after the three system theme dirs so a name
# collision still resolves to the system theme first, same priority
# rule the function below already documents.
ICON_THEME_DIRS = [
    "/usr/share/icons/Adwaita", "/usr/share/icons/Papirus", "/usr/share/icons/hicolor",
    "/var/lib/flatpak/exports/share/icons",
    os.path.expanduser("~/.local/share/flatpak/exports/share/icons"),
]
ICON_EXTS = (".svg", ".png")
# Prefer the largest/scalable variant available for a given name - crisper
# at the sizes both the dock (36px) and launcher (36px/22px) actually use.
SIZE_PRIORITY = ["scalable", "256x256", "128x128", "96x96", "64x64", "48x48", "32x32", "24x24", "22x22", "16x16"]


def build_icon_index():
    """One name -> absolute path map, built by walking the real theme dirs
    in priority order (first match for a name wins, so Adwaita/Papirus
    take precedence over hicolor's often-lower-resolution fallbacks)."""
    index = {}

    def consider(name, path):
        if name not in index:
            index[name] = path

    for theme_dir in ICON_THEME_DIRS:
        if not os.path.isdir(theme_dir):
            continue
        # Walk size-priority order first so a theme's own best variant
        # wins over its lower-res ones, without needing every combination
        # of size/category spelled out - os.walk covers whatever category
        # subdirectories (apps/devices/mimetypes/...) actually exist.
        ordered_dirs = [os.path.join(theme_dir, s) for s in SIZE_PRIORITY if os.path.isdir(os.path.join(theme_dir, s))]
        remaining = [os.path.join(theme_dir, d) for d in sorted(os.listdir(theme_dir))
                     if os.path.join(theme_dir, d) not in ordered_dirs and os.path.isdir(os.path.join(theme_dir, d))]
        for base in ordered_dirs + remaining:
            for root, _dirs, files in os.walk(base):
                for fname in files:
                    stem, ext = os.path.splitext(fname)
                    if ext.lower() in ICON_EXTS:
                        consider(stem, os.path.join(root, fname))
    # Flat pixmaps dir (older-style apps, no size/category subfolders)
    if os.path.isdir("/usr/share/pixmaps"):
        for fname in os.listdir("/usr/share/pixmaps"):
            stem, ext = os.path.splitext(fname)
            if ext.lower() in ICON_EXTS or ext.lower() == ".xpm":
                consider(stem, os.path.join("/usr/share/pixmaps", fname))
    return index


def scan():
    icon_index = build_icon_index()
    seen_names = set()
    apps = []
    # (app dict, its .desktop path) for every pacman-candidate entry, so
    # their `pacman -Qoq` lookups can run in parallel below - done serially
    # this took ~3.5s (one pacman process spawn per file dominates, not the
    # lookup itself), real UX problem since this reruns on every launcher
    # open. A thread pool cuts that to comfortably under a second.
    pacman_pending = []
    for d in DIRS:
        for path in glob.glob(os.path.join(d, "*.desktop")):
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(path, encoding="utf-8")
            except (configparser.Error, UnicodeDecodeError, OSError):
                continue
            if "Desktop Entry" not in cp:
                continue
            entry = cp["Desktop Entry"]
            if entry.get("NoDisplay", "false").lower() == "true":
                continue
            if entry.get("Hidden", "false").lower() == "true":
                continue
            if entry.get("Type", "Application") != "Application":
                continue
            name = entry.get("Name", "")
            exec_raw = entry.get("Exec", "")
            if not name or not exec_raw:
                continue
            if name in seen_names:
                continue
            seen_names.add(name)
            exec_clean = FIELD_CODES.sub("", exec_raw).strip()
            icon_name = entry.get("Icon", "")
            if icon_name.startswith("/"):
                icon_path = icon_name if os.path.isfile(icon_name) else ""
            else:
                icon_path = icon_index.get(icon_name, "")
            app = {
                "name": name,
                "icon": icon_name,
                "iconPath": icon_path,
                "exec": exec_clean,
                "wmClass": entry.get("StartupWMClass", ""),
                "desktopFile": os.path.splitext(os.path.basename(path))[0],
                "origin": "",
                "pkgId": "",
            }
            if d in FLATPAK_DIRS:
                app["origin"] = "flatpak"
                # X-Flatpak is written into every exported .desktop file by
                # flatpak itself - trust it over guessing from the filename,
                # since a multi-entry app (e.g. an expansion-pack launcher)
                # can have a .desktop basename that isn't the real app id.
                app["pkgId"] = entry.get("X-Flatpak", "") or os.path.splitext(os.path.basename(path))[0]
            else:
                pacman_pending.append((app, path))
            apps.append(app)

    if pacman_pending:
        with ThreadPoolExecutor(max_workers=16) as pool:
            results = pool.map(owning_pkg, [path for _app, path in pacman_pending])
        for (app, _path), pkg_id in zip(pacman_pending, results):
            app["pkgId"] = pkg_id
            app["origin"] = "pacman" if pkg_id else ""

    apps.sort(key=lambda a: a["name"].lower())
    print(json.dumps(apps))


if __name__ == "__main__":
    scan()
