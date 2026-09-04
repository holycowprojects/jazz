#!/usr/bin/env bash
# Installs Ollama and pulls one small model for local CPU inference (Task 14).
# Run this AS ROOT. Independent of the Podman track (Task 12/13) - Ollama
# runs as its own systemd service, not inside a container, matching how
# most people actually run it day-to-day.
#
# Usage: setup-ollama.sh [model]
set -eu

MODEL="${1:-qwen2.5:0.5b}"

pacman -Sy --noconfirm --needed ollama

systemctl enable --now ollama

# Wait for the API to actually be up before pulling.
for i in $(seq 1 30); do
    if curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

ollama pull "$MODEL"

echo "Ollama installed and $MODEL pulled:"
ollama list
