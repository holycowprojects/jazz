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

DIRS = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
]

FIELD_CODES = re.compile(r"%[fFuUick]")


def scan():
    seen_names = set()
    apps = []
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
            apps.append({
                "name": name,
                "icon": entry.get("Icon", ""),
                "exec": exec_clean,
                "wmClass": entry.get("StartupWMClass", ""),
                "desktopFile": os.path.splitext(os.path.basename(path))[0],
            })
    apps.sort(key=lambda a: a["name"].lower())
    print(json.dumps(apps))


if __name__ == "__main__":
    scan()
