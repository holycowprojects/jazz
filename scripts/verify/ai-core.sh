#!/usr/bin/env bash
# Verifies the JAZZ AI-core container (Task 13): builds from the pinned
# Containerfile/lockfile, confirms CPU-backed PyTorch works, confirms
# JupyterLab starts and is reachable. Run this AS THE TARGET NON-ROOT USER
# (rootless Podman, per Task 12) - assumes ~/ai-core/{Containerfile,
# requirements.txt} already exist (copy configs/containers/ai-core/* there
# before calling this).
set -uo pipefail

pass=0
fail=0
IMAGE="localhost/jazz-ai-core:test"
CONTAINER="jazz-ai-core-verify"

cd ~/ai-core || { echo "FAIL: ~/ai-core not found"; exit 1; }

if podman build -t "$IMAGE" -f Containerfile . > /tmp/ai-core-build.log 2>&1; then
    echo "PASS: container builds from the pinned Containerfile/lockfile"
    pass=$((pass + 1))
else
    echo "FAIL: container build failed - see /tmp/ai-core-build.log"
    tail -40 /tmp/ai-core-build.log
    fail=$((fail + 1))
    echo "---"
    echo "$pass passed, $fail failed"
    exit 1
fi

# stdout and stderr are kept separate on purpose: torch/numpy can emit
# UserWarnings on stderr (e.g. numpy init warnings) that must not corrupt
# a strict stdout comparison - a real Task 13 finding (4 Sept 2026).
torch_out=$(podman run --rm "$IMAGE" python -c "import torch; print(torch.zeros(3).sum().item())" 2>/tmp/ai-core-torch-stderr.log)
if [[ "$torch_out" == "0.0" ]]; then
    echo "PASS: CPU-backed PyTorch runs inside the container (torch.zeros(3).sum() == $torch_out)"
    pass=$((pass + 1))
else
    echo "FAIL: PyTorch check did not return expected output: $torch_out"
    cat /tmp/ai-core-torch-stderr.log
    fail=$((fail + 1))
fi

podman rm -f "$CONTAINER" > /dev/null 2>&1 || true
podman run -d --name "$CONTAINER" -p 8888:8888 "$IMAGE" > /dev/null

ready=0
for _ in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:8888/api" > /dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done

if [[ "$ready" == "1" ]]; then
    echo "PASS: JupyterLab starts and answers requests on port 8888"
    pass=$((pass + 1))
else
    echo "FAIL: JupyterLab did not become reachable within 30s"
    podman logs "$CONTAINER" 2>&1 | tail -20
    fail=$((fail + 1))
fi

podman rm -f "$CONTAINER" > /dev/null 2>&1 || true

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
