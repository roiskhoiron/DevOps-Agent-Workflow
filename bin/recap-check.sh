#!/usr/bin/env bash
# Usage: recap-check.sh [--idempotent] <ansible-log | ->
# Reads the LAST "PLAY RECAP" block of an ansible-playbook log and prints one TSV row per host:
#   host <TAB> ok <TAB> changed <TAB> unreachable <TAB> failed
# Default: every host must have failed=0 and unreachable=0 (staging run succeeded).
# --idempotent: also changed=0 (second run changed nothing; /verify-idempotent).
# Exit: 0 pass, 1 a host violates the rule (offenders on stderr), 2 usage or no PLAY RECAP found.
idem=''
[ "${1:-}" = --idempotent ] && { idem=1; shift; }
[ $# -eq 1 ] || { echo "usage: $0 [--idempotent] <ansible-log | ->" >&2; exit 2; }
src=$1; [ "$src" = - ] && src=/dev/stdin
[ "$src" = /dev/stdin ] || [ -r "$src" ] || { echo "log tidak bisa dibaca: $1" >&2; exit 2; }
# strip ANSI colors, keep only the last recap block
rows=$(sed 's/\x1b\[[0-9;]*m//g' "$src" | awk '
  /^PLAY RECAP/ { buf = ""; inr = 1; next }
  inr && /^[^ ].*: *ok=/ { buf = buf $0 "\n"; next }
  inr && NF == 0 { next }
  inr { inr = 0 }
  END { printf "%s", buf }')
[ -n "$rows" ] || { echo "tidak ada PLAY RECAP di log" >&2; exit 2; }
rc=0
while IFS= read -r l; do
  host=$(printf '%s' "$l" | sed -E 's/[[:space:]]*:.*//')
  get() { printf '%s' "$l" | grep -oE "(^|[[:space:]])$1=[0-9]+" | grep -oE '[0-9]+$' || echo 0; }
  ok=$(get ok); ch=$(get changed); un=$(get unreachable); fa=$(get failed)
  printf '%s\t%s\t%s\t%s\t%s\n' "$host" "$ok" "$ch" "$un" "$fa"
  if [ "$fa" != 0 ] || [ "$un" != 0 ] || { [ -n "$idem" ] && [ "$ch" != 0 ]; }; then
    echo "gagal: $host (changed=$ch unreachable=$un failed=$fa)" >&2; rc=1
  fi
done <<< "$rows"
exit $rc
