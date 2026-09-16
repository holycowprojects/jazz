#!/usr/bin/env bash
# Installs PyRIT (Microsoft's AI red-teaming framework) for Task 15, as a
# standard part of the JAZZ OS build - same tier as setup-ollama.sh and
# setup-podman.sh, not a one-off manual step. Run this AS ROOT.
#
# PyRIT is pip-only (no Arch package) and needs Python 3.10-3.14 (confirmed
# via PyPI metadata for pyrit==1.0.1) - this VM has no Python installed at
# all yet. Arch's system Python is "externally managed" (PEP 668), so PyRIT
# lives in its own venv rather than fighting that with --break-system-packages.
set -euo pipefail

VENV=/opt/jazz-pyrit/venv

pacman -Sy --noconfirm --needed python python-pip

python -m venv "$VENV"
# numpy pinned to 2.3.5 (not left to pip's default resolution): a newer
# numpy wheel (2.5.2, pulled in automatically as pyrit's dependency) was
# built assuming x86-64-v2 baseline CPU features that QEMU's default WHPX
# virtual CPU doesn't expose, crashing at import with "NumPy was built with
# baseline optimizations... but your machine doesn't support" - a different
# numpy issue from Task 13's, but the same pinned version already proven to
# work on this exact VM.
"$VENV/bin/pip" install --no-cache-dir pyrit==1.0.1 numpy==2.3.5

# Expose the CLI on PATH like any other preinstalled tool, without polluting
# system Python.
ln -sf "$VENV/bin/pyrit_scan" /usr/local/bin/pyrit_scan
ln -sf "$VENV/bin/pyrit_shell" /usr/local/bin/pyrit_shell

echo "PyRIT installed:"
"$VENV/bin/python" -c "import pyrit; print('pyrit', pyrit.__version__)"
