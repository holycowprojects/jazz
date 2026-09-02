"""Read-only viewer for the dev VM's serial console.

Usage: python vm/watch-serial.py [port]

Connects to the TCP serial socket launch-dev-vm.ps1 opens (default 4445) and
prints everything the guest sends. Does not forward keystrokes - see
serial-console.py for a two-way client. Only one client can hold the
connection at a time; close this before running the interactive client.
"""
import socket
import sys
import time

port = int(sys.argv[1]) if len(sys.argv) > 1 else 4445

for attempt in range(30):
    try:
        s = socket.create_connection(("127.0.0.1", port), timeout=5)
        break
    except OSError:
        time.sleep(1)
else:
    print(f"Could not connect to serial port {port}")
    sys.exit(1)

print(f"Connected to VM serial console on port {port} (read-only). Ctrl+C to close.")
s.settimeout(1)
while True:
    try:
        chunk = s.recv(4096)
        if chunk:
            sys.stdout.buffer.write(chunk)
            sys.stdout.flush()
    except socket.timeout:
        continue
    except (ConnectionResetError, OSError):
        print("\n[connection closed]")
        break
