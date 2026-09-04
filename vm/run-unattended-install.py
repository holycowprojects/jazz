"""Task 5: push install/base-profile.json + install/base-credentials.json into
the live archiso VM over the serial console (no shared filesystem exists
between host and guest - see docs/Research-Reference-List.md), then kick off
`archinstall --config ... --creds ... --silent`.

Usage: python vm/run-unattended-install.py [serial_port]

Logs everything received to stdout so the caller can see install progress
and the final result.
"""
import socket
import sys
import time
from pathlib import Path

port = int(sys.argv[1]) if len(sys.argv) > 1 else 4445
repo_root = Path(__file__).resolve().parent.parent
config_path = repo_root / "install" / "base-profile.json"
creds_path = repo_root / "install" / "base-credentials.json"

s = socket.create_connection(("127.0.0.1", port), timeout=15)
s.settimeout(1)


def drain(seconds, echo=True):
    buf = bytearray()
    deadline = time.time() + seconds
    while time.time() < deadline:
        try:
            chunk = s.recv(4096)
            if chunk:
                buf.extend(chunk)
                if echo:
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.flush()
        except socket.timeout:
            continue
        except OSError:
            break
    return bytes(buf)


def send_line(line):
    s.sendall((line + "\n").encode())


def push_file(local_path, remote_path):
    content = local_path.read_text()
    send_line(f"cat > {remote_path} << 'JAZZEOF'")
    for line in content.splitlines():
        send_line(line)
    send_line("JAZZEOF")


print(f"--- connecting, waiting for login prompt on port {port} ---", flush=True)
drain(55)
send_line("root")
drain(3)

print("--- pushing base-profile.json ---", flush=True)
push_file(config_path, "/root/base-profile.json")
drain(2)

print("--- pushing base-credentials.json ---", flush=True)
push_file(creds_path, "/root/base-credentials.json")
drain(2)

print("--- validating JSON landed correctly ---", flush=True)
send_line("python -m json.tool /root/base-profile.json > /dev/null && echo CONFIG_JSON_OK || echo CONFIG_JSON_BAD")
drain(3)
send_line("python -m json.tool /root/base-credentials.json > /dev/null && echo CREDS_JSON_OK || echo CREDS_JSON_BAD")
drain(3)

print("--- starting archinstall --silent (this will take a while) ---", flush=True)
marker = "JAZZ_ARCHINSTALL_EXIT="
send_line(f"archinstall --config /root/base-profile.json --creds /root/base-credentials.json --silent; echo {marker}$?")

# The shell echoes the typed command line back immediately, which contains
# the literal (unexpanded) marker text - drain that first so it never gets
# mistaken for the real, post-completion marker line (with $? substituted).
drain(3)

# Long install: stream output for up to 20 minutes, watching for the real
# marker (only appears once $? has actually been substituted).
deadline = time.time() + 1200
seen = b""
while time.time() < deadline:
    chunk = drain(5)
    seen += chunk
    if marker.encode() in seen:
        break

print("\n--- done streaming (either exit marker seen or 20min cap hit) ---", flush=True)
