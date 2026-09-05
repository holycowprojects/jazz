#!/usr/bin/env bash
# Verifies Task 16: Task 13's exact AI-core container (unmodified) actually
# gets real CUDA on a rented GPU instance - not just that it builds.
#
# Unlike every other scripts/verify/*.sh, this one does NOT run on the
# target - the target is a short-lived rented GPU box (Vast.ai/RunPod),
# never the Windows host or the local dev VM. Run this ON YOUR LOCAL
# MACHINE; it SSHes out to the already-rented instance and drives
# everything remotely over that one connection.
#
# Deliberately does NOT start the container's default JupyterLab command
# (see Containerfile - no auth token, binds 0.0.0.0) - that's fine on the
# local dev VM's loopback-only network, but not something to ever start on
# an internet-facing rented box. This script only ever runs a one-shot
# `python -c "..."` inside the container, nothing that opens a port.
#
# Usage: verify/gpu-cuda.sh <ssh-host> <ssh-port> [ssh-key-path]
#   <ssh-host>     the host Vast.ai/RunPod gave you (its own SSH line looks
#                  like `ssh -p <port> root@<host>`)
#   <ssh-port>     that same SSH line's port
#   [ssh-key-path] defaults to your normal SSH identity (omit -i entirely)
#                  if not given
set -u

HOST="${1:?Usage: verify/gpu-cuda.sh <ssh-host> <ssh-port> [ssh-key-path]}"
PORT="${2:?Usage: verify/gpu-cuda.sh <ssh-host> <ssh-port> [ssh-key-path]}"
KEY="${3:-}"
REMOTE_DIR="/root/jazz-gpu-verify"
IMAGE="jazz-ai-core-gpu:test"
LOCAL_AI_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../configs/containers/ai-core" && pwd)"

pass=0
fail=0

ssh_opts=(-p "$PORT" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)
scp_opts=(-P "$PORT" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)
if [[ -n "$KEY" ]]; then
    ssh_opts+=(-i "$KEY")
    scp_opts+=(-i "$KEY")
fi

remote() {
    ssh "${ssh_opts[@]}" "root@$HOST" "$@"
}

echo "=== Task 16: GPU-CUDA verify against root@$HOST:$PORT ==="

if remote "echo connected" 2>/dev/null | grep -q "^connected$"; then
    echo "PASS: SSH connection to the rented instance succeeds"
    pass=$((pass + 1))
else
    echo "FAIL: could not SSH to root@$HOST:$PORT - check the instance is running and the SSH line is correct"
    echo "---"
    echo "$pass passed, $fail failed"
    exit 1
fi

gpu_name=$(remote "nvidia-smi --query-gpu=name --format=csv,noheader" 2>&1)
if [[ -n "$gpu_name" ]] && ! echo "$gpu_name" | grep -qi "error\|not found"; then
    echo "PASS: nvidia-smi sees a real GPU on the instance ($gpu_name)"
    pass=$((pass + 1))
else
    echo "FAIL: nvidia-smi did not report a usable GPU - $gpu_name"
    fail=$((fail + 1))
    echo "---"
    echo "$pass passed, $fail failed"
    exit 1
fi

# docker preferred over podman here - Vast.ai/RunPod GPU images ship
# nvidia-container-toolkit wired for docker's --gpus flag by default;
# podman's GPU passthrough (CDI) is comparatively unproven on these hosts.
ENGINE=""
if remote "command -v docker" > /dev/null 2>&1; then
    ENGINE="docker"
elif remote "command -v podman" > /dev/null 2>&1; then
    ENGINE="podman"
fi

if [[ -n "$ENGINE" ]]; then
    echo "PASS: a container engine ($ENGINE) is available on the instance"
    pass=$((pass + 1))
else
    echo "FAIL: neither docker nor podman found on the instance"
    fail=$((fail + 1))
    echo "---"
    echo "$pass passed, $fail failed"
    exit 1
fi

remote "mkdir -p $REMOTE_DIR" || true
scp "${scp_opts[@]}" "$LOCAL_AI_CORE_DIR/Containerfile" "$LOCAL_AI_CORE_DIR/requirements.txt" \
    "root@$HOST:$REMOTE_DIR/" > /dev/null 2>&1

if remote "test -f $REMOTE_DIR/Containerfile && test -f $REMOTE_DIR/requirements.txt"; then
    echo "PASS: Task 13's Containerfile/requirements.txt copied to the instance unmodified"
    pass=$((pass + 1))
else
    echo "FAIL: could not copy Containerfile/requirements.txt to the instance"
    fail=$((fail + 1))
    echo "---"
    echo "$pass passed, $fail failed"
    exit 1
fi

# docker/podman both understand -f Containerfile . the same way
if remote "cd $REMOTE_DIR && $ENGINE build -t $IMAGE -f Containerfile ." > /tmp/gpu-cuda-build.log 2>&1; then
    echo "PASS: the unmodified Task 13 container builds on the rented instance"
    pass=$((pass + 1))
else
    echo "FAIL: container build failed on the instance"
    remote "tail -40 /tmp/gpu-cuda-build.log" 2>/dev/null
    fail=$((fail + 1))
    echo "---"
    echo "$pass passed, $fail failed"
    exit 1
fi

# stdout/stderr kept separate - same reasoning as verify/ai-core.sh: torch
# can emit non-fatal warnings on stderr that must not corrupt a strict
# stdout comparison.
cuda_out=$(remote "$ENGINE run --rm --gpus all $IMAGE python -c 'import torch; print(torch.cuda.is_available())' 2>/tmp/gpu-cuda-torch-stderr.log")
if [[ "$cuda_out" == "True" ]]; then
    echo "PASS: torch.cuda.is_available() returns True inside the unmodified container"
    pass=$((pass + 1))
else
    echo "FAIL: expected 'True', got: $cuda_out"
    remote "cat /tmp/gpu-cuda-torch-stderr.log" 2>/dev/null
    fail=$((fail + 1))
fi

echo "---"
echo "$pass passed, $fail failed"
echo
echo ">>> TERMINATE THE INSTANCE NOW to stop billing - this script does not do that for you. <<<"
[[ $fail -eq 0 ]]
