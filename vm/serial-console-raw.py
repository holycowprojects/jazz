"""Raw-mode two-way console for the dev VM's serial port.

Usage: python vm/serial-console-raw.py [port]

Unlike serial-console.py (line-buffered - fine for running shell commands but
cannot drive a full-screen TUI), this puts the Windows console into raw mode
and forwards every keystroke to the guest immediately, byte for byte -
required for archinstall's interactive installer (Task 4), which is a
full-screen Textual app: confirmed via a live probe that it enables the
alternate screen buffer (\x1b[?1049h) and mouse tracking (\x1b[?1000h etc.)
the instant it starts, which a line-buffered client cannot drive (arrow keys,
Tab, single-key selections all need immediate per-keystroke delivery, not
"type a line, press Enter").

How it works: Windows' ENABLE_VIRTUAL_TERMINAL_INPUT console mode flag makes
ReadFile/os.read() on the console input handle emit standard xterm-style
escape sequences for arrow keys, function keys, etc. automatically, so no
manual scan-code translation is needed - just forward the raw bytes read.
ENABLE_VIRTUAL_TERMINAL_PROCESSING on stdout makes the console render the
guest's ANSI/VT output (color, cursor movement) correctly instead of showing
literal escape codes.

Ctrl+C is forwarded to the guest (as byte 0x03) rather than killing this
script - press Ctrl+] to quit instead.

Only one client (this or serial-console.py) can hold the serial connection
at a time.
"""
import ctypes
import os
import socket
import sys
import threading
import time

port = int(sys.argv[1]) if len(sys.argv) > 1 else 4445

STD_INPUT_HANDLE = -10
STD_OUTPUT_HANDLE = -11
ENABLE_PROCESSED_INPUT = 0x0001
ENABLE_LINE_INPUT = 0x0002
ENABLE_ECHO_INPUT = 0x0004
ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200
ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
ENABLE_WRAP_AT_EOL_OUTPUT = 0x0002

kernel32 = ctypes.windll.kernel32
h_in = kernel32.GetStdHandle(STD_INPUT_HANDLE)
h_out = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)

orig_in_mode = ctypes.c_uint32()
orig_out_mode = ctypes.c_uint32()
kernel32.GetConsoleMode(h_in, ctypes.byref(orig_in_mode))
kernel32.GetConsoleMode(h_out, ctypes.byref(orig_out_mode))


def set_raw_mode():
    kernel32.SetConsoleMode(h_in, ENABLE_VIRTUAL_TERMINAL_INPUT)
    kernel32.SetConsoleMode(
        h_out,
        orig_out_mode.value | ENABLE_VIRTUAL_TERMINAL_PROCESSING | ENABLE_WRAP_AT_EOL_OUTPUT,
    )


def restore_mode():
    kernel32.SetConsoleMode(h_in, orig_in_mode.value)
    kernel32.SetConsoleMode(h_out, orig_out_mode.value)


for attempt in range(30):
    try:
        s = socket.create_connection(("127.0.0.1", port), timeout=5)
        break
    except OSError:
        time.sleep(1)
else:
    print(f"Could not connect to serial port {port}")
    sys.exit(1)

print(f"Connected (raw mode) to VM serial console on port {port}.")
print("Every keystroke forwards immediately. Ctrl+] to quit.\n")
time.sleep(1)


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
            break


t = threading.Thread(target=reader, daemon=True)
t.start()

set_raw_mode()
try:
    while True:
        chunk = os.read(0, 1024)
        if not chunk:
            break
        if b"\x1d" in chunk:  # Ctrl+]
            break
        s.send(chunk)
except (KeyboardInterrupt, OSError):
    pass
finally:
    restore_mode()
    s.close()
    print("\n[disconnected]")
