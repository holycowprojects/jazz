#!/usr/bin/env bash
# Verifies rootless Podman actually works (Task 12) - not just that it's
# installed, but that a real container runs as a non-root user. Run this
# ON THE INSTALLED GUEST, as root (it su's into the target user itself).
#
# Usage: verify/podman.sh <username>
set -uo pipefail

USERNAME="${1:?Usage: verify/podman.sh <username>}"
pass=0
fail=0

if [[ "$(id -u "$USERNAME")" == "0" ]]; then
    echo "FAIL: $USERNAME resolves to UID 0 - not a meaningful rootless test"
    fail=$((fail + 1))
fi

if su - "$USERNAME" -c "podman info" > /dev/null 2>&1; then
    echo "PASS: podman info succeeds as $USERNAME (no root)"
    pass=$((pass + 1))
else
    echo "FAIL: podman info failed as $USERNAME"
    fail=$((fail + 1))
fi

output=$(su - "$USERNAME" -c "podman run --rm docker.io/library/alpine:latest echo rootless-container-ok" 2>&1)
if [[ "$output" == *"rootless-container-ok"* ]]; then
    echo "PASS: a real rootless container ran and produced expected output"
    pass=$((pass + 1))
else
    echo "FAIL: rootless container run did not produce expected output"
    echo "$output"
    fail=$((fail + 1))
fi

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
