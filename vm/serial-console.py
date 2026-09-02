"""Two-way console for the dev VM's serial port.

Usage: python vm/serial-console.py [port]

Connects to the TCP serial socket launch-dev-vm.ps1 opens (default 4445).
Prints everything the guest sends, and forwards each line you type (plus a
newline) once you press Enter.

Known limitation: this is line-buffered, not a raw terminal - fine for
running shell commands, but full-screen TUI programs (menus, editors) that
expect live keypresses will not render correctly. If Task 4's interactive
archinstall session needs that, this script will need a raw-mode rewrite
(e.g. via msvcrt on Windows) - noted here rather than solved speculatively.
"""
import socket
import sys
import threading
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

print(f"Connected to VM serial console on port {port}. Type commands, Enter to send. Ctrl+C to quit.")


def reader():
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


t = threading.Thread(target=reader, daemon=True)
t.start()

try:
    for line in sys.stdin:
        s.send(line.encode())
except (KeyboardInterrupt, EOFError):
    pass
finally:
    s.close()
