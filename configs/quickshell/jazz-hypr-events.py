#!/usr/bin/env python3
# Streams Hyprland's live IPC event feed (the .socket2.sock UNIX socket every
# status bar/widget ecosystem reads from) one event per line, unbuffered.
# Pure stdlib - same "no new dependency" precedent as scan-apps.py and
# jazz-agent-action. Used by Settings.qml's Developer tab (Task 28).
import os
import socket
import sys

sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
if not sig:
    sys.exit("HYPRLAND_INSTANCE_SIGNATURE not set - is Hyprland running?")

runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid())
sock_path = "%s/hypr/%s/.socket2.sock" % (runtime_dir, sig)

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock_path)
f = s.makefile("r")
for line in f:
    print(line.rstrip("\n"), flush=True)
