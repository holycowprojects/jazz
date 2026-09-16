#!/usr/bin/env bash
# Verifies Ollama actually performs CPU inference (Task 14), not just that
# it's installed. Checks structurally (a completed, non-empty response)
# rather than pinning to exact wording - a small model like qwen2.5:0.5b
# won't reliably follow "say exactly X" instructions, so asserting content
# would make this flaky for the wrong reason.
#
# Usage: verify/ollama.sh [model]
set -uo pipefail

MODEL="${1:-qwen2.5:0.5b}"
pass=0
fail=0

if ollama list 2>/dev/null | grep -qF "$MODEL"; then
    echo "PASS: ollama list shows $MODEL"
    pass=$((pass + 1))
else
    echo "FAIL: ollama list does not show $MODEL"
    fail=$((fail + 1))
fi

response_json=$(curl -sf http://127.0.0.1:11434/api/generate \
    -d "{\"model\":\"$MODEL\",\"prompt\":\"Say hello.\",\"stream\":false}" 2>&1)

if echo "$response_json" | grep -q '"done":true' && echo "$response_json" | grep -qE '"response":"[^"]'; then
    echo "PASS: a real CPU inference request returned a non-empty completed response"
    pass=$((pass + 1))
else
    echo "FAIL: inference did not return a completed non-empty response"
    echo "$response_json"
    fail=$((fail + 1))
fi

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
