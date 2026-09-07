#!/usr/bin/env bash
# Verifies jazz-agent-action (Task 30) actually works end-to-end - not just
# installed, but real tier classification, a real Snapper checkpoint, a real
# ledger entry, and a real Undo. Run this ON THE INSTALLED GUEST, as root
# (needs snapper access).
#
# Usage: verify/agent-safety.sh
set -u
pass=0
fail=0

TESTFILE="/root/jazz-agent-safety-verify.txt"
echo original > "$TESTFILE"

# 1. Tier classification
tier=$(jazz-agent-action classify install_package | grep -oP 'tier=\K\w+')
if [[ "$tier" == "yellow" ]]; then
    echo "PASS: install_package classifies as yellow"
    pass=$((pass + 1))
else
    echo "FAIL: install_package classified as '$tier', expected yellow"
    fail=$((fail + 1))
fi

# 2. Green-tier action runs with zero prompts
out=$(jazz-agent-action run --type read_status --description "verify green" -- echo green-ok 2>&1)
if [[ "$out" == *"green-ok"* ]]; then
    echo "PASS: green-tier action ran with no prompt"
    pass=$((pass + 1))
else
    echo "FAIL: green-tier action did not run cleanly"
    fail=$((fail + 1))
fi

# 3. Yellow-tier action, auto-confirmed via --yes, creates a real checkpoint
before=$(snapper -c root list | tail -1 | cut -d'|' -f1 | tr -d ' ')
out=$(jazz-agent-action run --type move_files --description "verify yellow" --yes -- bash -c "echo modified > $TESTFILE" 2>&1)
ledger_id=$(echo "$out" | grep -oP '\[ledger: \K[a-f0-9]+')
after=$(snapper -c root list | tail -1 | cut -d'|' -f1 | tr -d ' ')
if [[ -n "$ledger_id" && "$after" -gt "$before" ]]; then
    echo "PASS: yellow-tier action created a real Snapper checkpoint (snapshot #$after) and a ledger entry ($ledger_id)"
    pass=$((pass + 1))
else
    echo "FAIL: yellow-tier action did not checkpoint or log correctly"
    fail=$((fail + 1))
fi

# 4. Red-tier action without confirmation phrase is blocked (exit code 3 is
# the tool's documented "blocked" code - the command's own name legitimately
# appears in the tool's echoed-back diagnostic line, so check the exit code
# specifically rather than grepping output for the command text)
jazz-agent-action run --type sudo_exec --description "verify red blocked" -- echo should-not-run > /tmp/red-block-test.out 2>&1
red_rc=$?
if [[ $red_rc -eq 3 ]]; then
    echo "PASS: red-tier action blocked without --confirm-red (exit 3)"
    pass=$((pass + 1))
else
    echo "FAIL: red-tier action did not block correctly (exit $red_rc)"
    cat /tmp/red-block-test.out
    fail=$((fail + 1))
fi
rm -f /tmp/red-block-test.out

# 4b. Red-tier action WITH the confirmation phrase actually runs
out=$(jazz-agent-action run --type sudo_exec --description "verify red confirmed" --confirm-red "I UNDERSTAND" -- echo red-ok 2>&1)
if [[ "$out" == *"red-ok"* ]]; then
    echo "PASS: red-tier action ran once --confirm-red was supplied"
    pass=$((pass + 1))
else
    echo "FAIL: red-tier action did not run even with correct confirmation"
    fail=$((fail + 1))
fi

# 5. Undo works end-to-end on the yellow-tier action from step 3
if [[ -n "$ledger_id" ]]; then
    content_before_undo=$(cat "$TESTFILE")
    jazz-agent-action undo "$ledger_id" > /dev/null 2>&1
    content_after_undo=$(cat "$TESTFILE")
    if [[ "$content_before_undo" == "modified" && "$content_after_undo" == "original" ]]; then
        echo "PASS: undo reverted the yellow-tier action's real file change"
        pass=$((pass + 1))
    else
        echo "FAIL: undo did not revert the change (before='$content_before_undo' after='$content_after_undo')"
        fail=$((fail + 1))
    fi
else
    echo "FAIL: no ledger id from step 3, cannot test undo"
    fail=$((fail + 1))
fi

rm -f "$TESTFILE"

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
