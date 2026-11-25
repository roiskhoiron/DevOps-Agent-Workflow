#!/usr/bin/env bash
# Hourly (launchd on macOS, cron/systemd timer on Linux): cleans rebuildable test leftovers.
#   daily (after 03:00): agent work dirs in ${TMPDIR:-/tmp}/{qa,validate,audit} older than 7 days,
#     ~/.ansible/tmp older than 2 days, run logs in ~/.agent-workflow/runs older than 30 days
#   weekly (Sunday after 03:30): molecule containers older than 24h, dangling docker images,
#     ~/.cache/molecule and ansible-compat caches older than 14 days, ansible-galaxy download cache
# Skips container cleanup while a staging lock is held by a live pid or molecule/ansible-playbook runs.
# Overrides (tests): HK_NOW HK_BUSY HK_TMP DOCKER AGENT_LOCK_DIR AGENT_WORKFLOW_STATE
set -u
[ -n "${HOME:-}" ] || { echo "housekeeping: HOME is empty" >&2; exit 1; }
AW=${AGENT_WORKFLOW_STATE:-$HOME/.agent-workflow}; STATE="$AW/state"; LOG="$AW/logs/housekeeping.log"
mkdir -p "$STATE" "$AW/logs"
NOW=${HK_NOW:-$(date +%s)}
DOCKER=${DOCKER:-docker}; TMPD=${HK_TMP:-${TMPDIR:-/tmp}}
FAILS=0

fmt() { date -d "@$1" "+$2" 2>/dev/null || date -r "$1" "+$2"; }  # GNU / BSD date
log() { echo "$(fmt "$NOW" '%F %T') $*" >> "$LOG"; }
fail() { log "ERROR $*"; FAILS=$((FAILS+1)); }
safe() { # a clean absolute path under $HOME or the temp dir, never the root of either
  case "$1" in *..*) return 1;; esac
  case "$1" in "$HOME"/?*|"${TMPD%/}"/?*) return 0;; esac
  return 1
}
prune() { # dir days: delete direct children older than N days
  local d=$1 n=$2
  safe "$d" || { fail "REFUSE $d"; return; }
  [ -d "$d" ] || return 0
  find "$d" -mindepth 1 -maxdepth 1 -mtime +"$n" -exec rm -rf {} + 2>/dev/null || fail "prune $d"
  log "pruned $d >${n}d"
}
dk() { # docker args...: skipped when docker is absent or not running
  command -v "$DOCKER" >/dev/null 2>&1 || return 0
  "$DOCKER" info >/dev/null 2>&1 || return 0
  "$DOCKER" "$@" >>"$LOG" 2>&1 || { fail "failed: docker $*"; return 0; }
  log "ran docker $*"
}
busy() {
  [ -n "${HK_BUSY:-}" ] && { [ "$HK_BUSY" = 1 ]; return; }
  local d pid
  for d in "${AGENT_LOCK_DIR:-$AW/locks}"/staging%3A*; do
    [ -d "$d" ] || continue
    pid=$(cat "$d/pid" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
  done
  pgrep -f 'molecule|ansible-playbook' >/dev/null 2>&1
}

daily() {
  local w
  for w in qa validate audit; do prune "$TMPD/$w" 7; done
  prune "$HOME/.ansible/tmp" 2
  prune "$AW/runs" 30
}
weekly() {
  if busy; then log "busy, container cleanup skipped"
  else
    dk container prune -f --filter label=owner=molecule --filter until=24h
    dk image prune -f
  fi
  prune "$HOME/.cache/molecule" 14
  prune "$HOME/.cache/ansible-compat" 14
  prune "$HOME/.ansible/galaxy_cache" 14
}

today=$(fmt "$NOW" %F); hm=$(fmt "$NOW" %H%M); dow=$(fmt "$NOW" %u)
if [ "$hm" -ge 0300 ] 2>/dev/null && [ "$(cat "$STATE/daily" 2>/dev/null)" != "$today" ]; then
  daily; echo "$today" > "$STATE/daily"
fi
if [ "$dow" = 7 ] && [ "$hm" -ge 0330 ] && [ "$(cat "$STATE/weekly" 2>/dev/null)" != "$today" ]; then
  weekly; echo "$today" > "$STATE/weekly"
fi
[ "$FAILS" -gt 0 ] && echo "housekeeping: $FAILS error(s), see $LOG" >&2
exit 0
