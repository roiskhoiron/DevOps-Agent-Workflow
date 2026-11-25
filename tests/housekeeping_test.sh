#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
H=$(mktemp -d); trap 'rm -rf "$H"' EXIT
export HOME="$H/home" HK_TMP="$H/tmp" AGENT_WORKFLOW_STATE="$H/home/.agent-workflow" DOCKER="$H/docker"
mkdir -p "$HOME/.ansible/tmp" "$HK_TMP/qa" "$HK_TMP/validate" "$AGENT_WORKFLOW_STATE/runs"
cat > "$DOCKER" <<'D'
#!/bin/sh
echo "$*" >> "$(dirname "$0")/docker.calls"
D
chmod +x "$DOCKER"
old() { mkdir -p "$1"; touch -d "${2:-20} days ago" "$1" 2>/dev/null || touch -t "$(date -v-"${2:-20}"d +%Y%m%d%H%M 2>/dev/null)" "$1"; }
old "$HK_TMP/qa/OPS-1"; mkdir -p "$HK_TMP/qa/OPS-2"; old "$HOME/.ansible/tmp/ansible-tmp-1"; old "$AGENT_WORKFLOW_STATE/runs/r1" 40
old "$AGENT_WORKFLOW_STATE/runs/r2" 20   # younger than 30 days
ts() { date -d "$1" +%s 2>/dev/null || date -j -f '%Y-%m-%d %H:%M' "$1" +%s; }
SUN=$(ts '2026-11-29 04:00')   # a Sunday

HK_NOW=$(ts '2026-11-25 02:00') HK_BUSY=0 bash "$REPO/bin/housekeeping.sh"
assert_eq yes "$([ -d "$HK_TMP/qa/OPS-1" ] && echo yes || echo no)" "before 03:00: nothing pruned"
HK_NOW=$(ts '2026-11-25 04:00') HK_BUSY=0 bash "$REPO/bin/housekeeping.sh"
assert_eq no "$([ -d "$HK_TMP/qa/OPS-1" ] && echo yes || echo no)" "daily: old qa dir pruned"
assert_eq yes "$([ -d "$HK_TMP/qa/OPS-2" ] && echo yes || echo no)" "daily: fresh qa dir kept"
assert_eq no "$([ -d "$HOME/.ansible/tmp/ansible-tmp-1" ] && echo yes || echo no)" "daily: ansible tmp pruned"
assert_eq no "$([ -d "$AGENT_WORKFLOW_STATE/runs/r1" ] && echo yes || echo no)" "daily: old run log pruned"
assert_eq yes "$([ -d "$AGENT_WORKFLOW_STATE/runs/r2" ] && echo yes || echo no)" "daily: fresh run log kept"
assert_eq no "$([ -f "$H/docker.calls" ] && echo yes || echo no)" "weekday: no docker cleanup"
HK_NOW=$SUN HK_BUSY=1 bash "$REPO/bin/housekeeping.sh"
assert_eq no "$(grep -q 'container prune' "$H/docker.calls" 2>/dev/null && echo yes || echo no)" "sunday busy: containers kept"
rm -f "$AGENT_WORKFLOW_STATE/state/weekly"
HK_NOW=$SUN HK_BUSY=0 bash "$REPO/bin/housekeeping.sh"
assert_eq yes "$(grep -q 'container prune -f --filter label=owner=molecule --filter until=24h' "$H/docker.calls" && echo yes || echo no)" "sunday: molecule containers pruned"
assert_eq 1 "$(grep -c 'container prune' "$H/docker.calls")" "weekly once per day"
HK_NOW=$SUN HK_BUSY=0 bash "$REPO/bin/housekeeping.sh"
assert_eq 1 "$(grep -c 'container prune' "$H/docker.calls")" "weekly not repeated"
exit $((FAILS>0))
