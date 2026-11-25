#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
L="$REPO/bin/lock.sh"
T=$(mktemp -d); trap 'rm -rf "$T"; kill $SP 2>/dev/null' EXIT
export AGENT_LOCK_DIR="$T/locks"
R=staging:infra/inventories/staging
sleep 60 & SP=$!; disown "$SP"

assert_exit 0 "acquire free" -- env AGENT_LOCK_PID=$SP "$L" acquire "$R" OPS-1-qa1
assert_eq "OPS-1-qa1" "$("$L" who "$R")" "who = owner"
assert_eq "yes" "$([ -d "$T/locks/staging%3Ainfra%2Finventories%2Fstaging" ] && echo yes || echo no)" "resource encoded (: and /)"
assert_exit 1 "held by live pid" -- env AGENT_LOCK_PID=$$ "$L" acquire "$R" OPS-2-qa1
assert_eq "OPS-1-qa1" "$(AGENT_LOCK_PID=$$ "$L" acquire "$R" OPS-2-qa1)" "prints holder"
assert_exit 0 "same owner re-acquires" -- env AGENT_LOCK_PID=$$ "$L" acquire "$R" OPS-1-qa1
assert_exit 0 "release by other owner is a no-op" -- "$L" release "$R" OPS-2-qa1
assert_eq "OPS-1-qa1" "$("$L" who "$R")" "still held"
assert_exit 0 "release by owner" -- "$L" release "$R" OPS-1-qa1
assert_eq "" "$("$L" who "$R")" "free after release"
AGENT_LOCK_PID=$SP "$L" acquire "$R" OPS-1-qa1; kill $SP; wait $SP 2>/dev/null
assert_exit 0 "dead holder = stale, reclaimed" -- env AGENT_LOCK_PID=$$ "$L" acquire "$R" OPS-3-qa1
assert_eq "OPS-3-qa1" "$("$L" who "$R")" "new owner"
assert_exit 2 "usage" -- "$L" acquire "$R"
assert_exit 2 "unknown verb" -- "$L" move "$R" a b
exit $((FAILS>0))
