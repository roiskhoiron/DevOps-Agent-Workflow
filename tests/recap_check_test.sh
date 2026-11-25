#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
R="$REPO/bin/recap-check.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cat > "$T/run1.log" <<'X'
PLAY [web] *********
TASK [Install nginx] *********
changed: [web-stg-1]

PLAY RECAP *********************************************************************
web-stg-1                  : ok=5    changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
web-stg-2                  : ok=5    changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
X
printf 'PLAY RECAP ****\n\033[0;33mweb-stg-1\033[0m                  : \033[0;32mok=5   \033[0m changed=0    unreachable=0    failed=0    skipped=1\n' > "$T/run2.log"
cat "$T/run1.log" > "$T/twice.log"; cat "$T/run2.log" >> "$T/twice.log"
printf 'PLAY RECAP ****\ndb-stg-1 : ok=1 changed=0 unreachable=1 failed=0\n' > "$T/unreach.log"

assert_exit 0 "run 1 ok (changes allowed)" -- "$R" "$T/run1.log"
assert_exit 1 "run 1 not idempotent" -- "$R" --idempotent "$T/run1.log"
assert_exit 0 "run 2 idempotent (ANSI colors stripped)" -- "$R" --idempotent "$T/run2.log"
assert_exit 0 "last recap block wins" -- "$R" --idempotent "$T/twice.log"
assert_eq "web-stg-1	5	2	0	0" "$("$R" "$T/run1.log" | head -1)" "TSV row"
assert_eq "2" "$("$R" "$T/run1.log" | wc -l | tr -d ' ')" "one row per host"
assert_exit 1 "unreachable host fails" -- "$R" "$T/unreach.log"
assert_exit 0 "stdin" -- sh -c "\"$R\" - < \"$T/run2.log\""
echo 'no recap' > "$T/none.log"
assert_exit 2 "no PLAY RECAP" -- "$R" "$T/none.log"
assert_exit 2 "usage" -- "$R"
exit $((FAILS>0))
