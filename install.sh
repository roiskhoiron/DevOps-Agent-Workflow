#!/usr/bin/env bash
# Usage: install.sh [--home DIR] [--force]   (default $HOME). Idempotent.
# Links skills and agents into DIR/.claude, installs the guard hook, the housekeeping job (macOS launchd;
# Linux: prints a cron line) and the global CLAUDE.md section.
# The flow commands (/validate-tiket, ...) and agent names (spv, coder, ...) are the same as in the other
# role workflows (mobile): an existing link that points to another repo is a conflict -> stop, unless --force.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd -P)"
DEST="$HOME"; CUSTOM=0; FORCE=0
while [ $# -gt 0 ]; do
  case $1 in
    --home) DEST="${2:?--home needs a dir}"; CUSTOM=1; shift 2;;
    --force) FORCE=1; shift;;
    *) echo "usage: $0 [--home DIR] [--force]" >&2; exit 2;;
  esac
done
C="$DEST/.claude"
mkdir -p "$C/skills" "$C/agents"

links=()  # "source<TAB>target"
for d in "$REPO"/skills/*/; do
  n=$(basename "$d"); [ "$n" = _shared ] && n=_devops-workflow-shared
  links+=("${d%/}"$'\t'"$C/skills/$n")
done
for f in "$REPO"/agents/*.md; do links+=("$f"$'\t'"$C/agents/$(basename "$f")"); done

conflicts=''
for l in "${links[@]}"; do
  src=${l%%$'\t'*} dst=${l#*$'\t'}
  if [ -L "$dst" ]; then
    cur=$(readlink "$dst")
    case $cur in "$REPO"/*) ;; *) conflicts+="  $dst -> $cur"$'\n';; esac
  elif [ -e "$dst" ]; then conflicts+="  $dst (bukan symlink)"$'\n'
  fi
done
if [ -n "$conflicts" ] && [ "$FORCE" = 0 ]; then
  echo "Bentrok: skill/agen dengan nama sama sudah terpasang dari repo lain:" >&2
  printf '%s' "$conflicts" >&2
  echo "Satu komputer = satu workflow role. Pakai --force untuk menggantinya dengan workflow DevOps." >&2
  exit 3
fi
for l in "${links[@]}"; do
  src=${l%%$'\t'*} dst=${l#*$'\t'}
  [ -e "$dst" ] && [ ! -L "$dst" ] && mv "$dst" "$dst.bak-devops-workflow"
  ln -sfn "$src" "$dst"
done

S="$C/settings.json"
[ -f "$S" ] || echo '{}' > "$S"
[ -e "$S.bak-devops-workflow" ] || cp "$S" "$S.bak-devops-workflow"  # keep the first original
tmp=$(mktemp)
jq --arg cmd "\"$REPO/hooks/guard.sh\"" --arg m 'Bash|Edit|Write|MultiEdit|NotebookEdit|mcp__claude_ai_Atlassian__.*' '
  def isguard: any((.hooks // [])[]?; .command | tostring | test("/guard\\.sh\"?$"));
  .hooks.PreToolUse = ((.hooks.PreToolUse // [])
    | if any(.[]; isguard) then map(if isguard then .matcher = $m | .hooks = [{type:"command",command:$cmd}] else . end)
      else . + [{matcher:$m, hooks:[{type:"command",command:$cmd}]}] end)' "$S" > "$tmp"
mv "$tmp" "$S"

mkdir -p "$DEST/.agent-workflow/logs"
P="$REPO/launchd/com.agentworkflow.devops.housekeeping.plist"
if [ "$(uname)" = Darwin ]; then
  out="$DEST/Library/LaunchAgents/$(basename "$P")"
  mkdir -p "$(dirname "$out")"
  sed -e "s|__AGENT_WORKFLOW_DIR__|$REPO|g" -e "s|__HOME__|$DEST|g" "$P" > "$out"
  if [ "$CUSTOM" = 0 ]; then
    launchctl bootout "gui/$(id -u)" "$out" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$out"
  fi
else
  echo "Linux: jadwalkan housekeeping tiap jam, mis. lewat 'crontab -e':"
  echo "  0 * * * * /bin/bash \"$REPO/bin/housekeeping.sh\""
fi
# global CLAUDE.md section, appended once
T="$REPO/templates/claude-global.md"
if [ -f "$T" ] && ! grep -qs '^# DevOps agent workflow' "$C/CLAUDE.md"; then
  { [ -s "$C/CLAUDE.md" ] && echo; cat "$T"; } >> "$C/CLAUDE.md"
fi
echo "installed into $DEST"
