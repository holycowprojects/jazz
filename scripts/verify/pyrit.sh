#!/usr/bin/env bash
# Verifies PyRIT actually runs a jailbreak probe against the local Ollama
# model and produces a real, readable report (Task 15) - not just that it
# imports. Run this ON THE INSTALLED GUEST, as root (Ollama's API is
# loopback-only here, so no special user context is needed).
#
# Usage: verify/pyrit.sh [model]
set -uo pipefail

VENV=/opt/jazz-pyrit/venv
MODEL="${1:-qwen2.5:0.5b}"
REPORT=/root/pyrit-jailbreak-report.txt
pass=0
fail=0

version_out=$("$VENV/bin/python" -c "import pyrit; print(pyrit.__version__)" 2>&1)
if [[ "$version_out" == "1.0.1" ]]; then
    echo "PASS: pyrit importable, version $version_out"
    pass=$((pass + 1))
else
    echo "FAIL: pyrit version check failed: $version_out"
    fail=$((fail + 1))
fi

# PyRIT's OpenAI-compatible target points at Ollama's own OpenAI-compatible
# endpoint (http://.../v1 - the OpenAI SDK appends /chat/completions itself).
# Real finding (4 Sept 2026): pyrit_scan's backend unconditionally validates
# a "default objective target" (OPENAI_CHAT_*) even when only the
# differently-named "ollama" target is actually used - so both must be set,
# pointed at the same place, or every pyrit_scan call 400s before it even
# gets to the scenario you asked for.
export OLLAMA_CHAT_ENDPOINT="http://127.0.0.1:11434/v1"
export OLLAMA_MODEL="$MODEL"
export OPENAI_CHAT_ENDPOINT="http://127.0.0.1:11434/v1"
export OPENAI_CHAT_MODEL="$MODEL"
export OPENAI_CHAT_KEY="not-needed"

# airt.jailbreak: built-in scenario testing jailbreak-template vulnerability
# against HarmBench objectives, auto-scored for refusal. Kept small
# (max-dataset-size/num-jailbreaks/num-jailbreak-attempts all 1) since this
# is a verify check, not a full audit, and the target is a 0.5B CPU model.
"$VENV/bin/pyrit_scan" airt.jailbreak \
    --target ollama \
    --initializers target "load_default_datasets:dataset_names=harmbench" \
    --start-server \
    --max-dataset-size 1 \
    --num-jailbreaks 1 \
    --num-jailbreak-attempts 1 \
    > "$REPORT" 2>&1
run_status=$?

"$VENV/bin/pyrit_scan" --stop-server > /dev/null 2>&1

if [[ $run_status -eq 0 ]] && [[ -s "$REPORT" ]] && grep -q "Running scenario: airt.jailbreak" "$REPORT" && ! grep -q "^Error (" "$REPORT"; then
    echo "PASS: airt.jailbreak probe ran against the local Ollama model and produced a report ($REPORT)"
    pass=$((pass + 1))
else
    echo "FAIL: jailbreak probe did not complete cleanly - see $REPORT"
    tail -40 "$REPORT"
    fail=$((fail + 1))
fi

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
