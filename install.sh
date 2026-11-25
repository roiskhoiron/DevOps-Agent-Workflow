#!/usr/bin/env bash
# Pasang workflow agen DevOps ke satu atau beberapa AI coding agent.
#
# Usage: install.sh [--agent LIST] [--scope global|project] [--project DIR] [--home DIR] [--force] [--yes]
#   --agent    claude,codex,gemini,cursor,copilot,opencode (koma) atau "all". Default: claude.
#   --scope    global  = untuk semua project di komputer ini (folder home tool)          [default]
#              project = hanya untuk satu repo (folder .claude/, .agents/, .github/, ... di repo itu)
#   --project  folder repo untuk --scope project (default: root git folder saat ini)
#   --home     folder home lain (untuk tes); default $HOME
#   --force    ganti skill/agen bernama sama yang terpasang dari repo lain (mis. workflow Mobile)
#   --yes      jangan bertanya; pakai flag/default
# Tanpa flag di terminal interaktif: installer menanyakan tool dan scope.
# Idempoten: aman dijalankan ulang (memperbarui link, file peran, hook, dan blok instruksi).
#
# Selalu dipasang: ~/.agent-workflow/devops -> repo ini (lokasi netral yang dirujuk semua skill),
# folder log, dan job housekeeping (macOS launchd; Linux: baris cron dicetak).
# Exit: 0 ok, 2 salah pakai, 3 bentrok dengan workflow lain (pakai --force).
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd -P)"
ALL_AGENTS="claude codex gemini cursor copilot opencode"
DEST="$HOME"; CUSTOM=0; FORCE=0; YES=0; AGENTS=''; SCOPE=''; PROJ=''

usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
while [ $# -gt 0 ]; do
  case $1 in
    --agent|--agents) AGENTS="${2:?--agent butuh nilai}"; shift 2;;
    --agent=*|--agents=*) AGENTS="${1#*=}"; shift;;
    --scope) SCOPE="${2:?--scope butuh nilai}"; shift 2;;
    --scope=*) SCOPE="${1#*=}"; shift;;
    --project) PROJ="${2:?--project butuh folder}"; shift 2;;
    --project=*) PROJ="${1#*=}"; shift;;
    --home) DEST="${2:?--home butuh folder}"; CUSTOM=1; shift 2;;
    --force) FORCE=1; shift;;
    --yes|-y) YES=1; shift;;
    -h|--help) usage;;
    *) echo "opsi tidak dikenal: $1" >&2; usage;;
  esac
done

# --- interactive choice (only on a terminal, only for what flags did not say) ---
ask() { local a; read -r -p "$1" a < /dev/tty; echo "${a:-$2}"; }
if [ "$YES" = 0 ] && [ -t 0 ] && [ -t 1 ] && { [ -z "$AGENTS" ] || [ -z "$SCOPE" ]; }; then
  if [ -z "$AGENTS" ]; then
    echo "AI coding agent mana yang dipasang? (boleh lebih dari satu, pisahkan dengan koma)"
    i=1; for a in $ALL_AGENTS; do echo "  $i) $a"; i=$((i+1)); done; echo "  7) all"
    sel=$(ask "Pilihan [1]: " 1); AGENTS=''
    for n in ${sel//,/ }; do
      case $n in 7|all) AGENTS=all;; [1-6]) AGENTS+="$(echo $ALL_AGENTS | cut -d' ' -f"$n"),";; *) AGENTS+="$n,";; esac
    done
  fi
  if [ -z "$SCOPE" ]; then
    echo "Scope pemasangan:"
    echo "  1) global  - semua project di komputer ini"
    echo "  2) project - hanya satu repo"
    case $(ask "Pilihan [1]: " 1) in 2|project) SCOPE=project;; *) SCOPE=global;; esac
  fi
  if [ "$SCOPE" = project ] && [ -z "$PROJ" ]; then
    d=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    PROJ=$(ask "Folder repo project [$d]: " "$d")
  fi
fi
AGENTS=${AGENTS:-claude}; SCOPE=${SCOPE:-global}
[ "$AGENTS" = all ] && AGENTS=$ALL_AGENTS
AGENTS=$(echo "${AGENTS//,/ }" | tr 'A-Z' 'a-z')
for a in $AGENTS; do case " $ALL_AGENTS " in *" $a "*) ;; *) echo "agent tidak dikenal: $a (pilihan: $ALL_AGENTS, all)" >&2; exit 2;; esac; done
case $SCOPE in
  global) B="$DEST";;
  project)
    [ -n "$PROJ" ] || PROJ=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    [ -d "$PROJ" ] || { echo "folder project tidak ada: $PROJ" >&2; exit 2; }
    B="$(cd "$PROJ" && pwd -P)"
    [ "$B" != "$REPO" ] || { echo "--project tidak boleh repo workflow ini sendiri" >&2; exit 2; };;
  *) echo "--scope harus global atau project" >&2; exit 2;;
esac
command -v jq >/dev/null || { echo "jq tidak ditemukan; pasang jq dulu" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 tidak ditemukan; pasang python3 dulu" >&2; exit 2; }

ROLES=("$REPO"/agents/*.md)
SKILLS=$(for d in "$REPO"/skills/*/; do n=$(basename "$d"); [ "$n" = _shared ] || echo "$n"; done)
G="\"$REPO/hooks/guard.sh\""
A="\"$REPO/hooks/adapter.sh\""
NOTES=()

# --- per-agent layout (verified against each tool's docs, 2026-11; see docs/pasang.md) ---
# skills: Claude reads only .claude/skills; every other tool reads the shared .agents/skills.
skills_dir() { case $1 in claude) echo "$B/.claude/skills";; *) echo "$B/.agents/skills";; esac; }
roles_dir() {
  case "$1:$SCOPE" in
    claude:*) echo "$B/.claude/agents";;
    codex:*) echo "$B/.codex/agents";;
    gemini:*) echo "$B/.gemini/agents";;
    cursor:*) echo "$B/.cursor/agents";;
    copilot:global) echo "$B/.copilot/agents";;
    copilot:project) echo "$B/.github/agents";;
    opencode:global) echo "$B/.config/opencode/agents";;
    opencode:project) echo "$B/.opencode/agents";;
  esac
}
instr_file() {
  case "$1:$SCOPE" in
    claude:global) echo "$B/.claude/CLAUDE.md";;
    claude:project) echo "$B/CLAUDE.md";;
    codex:global) echo "$B/.codex/AGENTS.md";;
    gemini:global) echo "$B/.gemini/GEMINI.md";;
    gemini:project) echo "$B/GEMINI.md";;
    cursor:global) echo "";;   # Cursor user rules live only in its UI
    copilot:global) echo "$B/.copilot/copilot-instructions.md";;
    opencode:global) echo "$B/.config/opencode/AGENTS.md";;
    *:project) echo "$B/AGENTS.md";;
  esac
}

# --- conflicts: a skill/role link of the same name that points to another repo ---
conflicts=''
check_link() { # dst
  local cur
  if [ -L "$1" ]; then cur=$(readlink "$1"); case $cur in "$REPO"/*) ;; *) conflicts+="  $1 -> $cur"$'\n';; esac
  elif [ -e "$1" ] && ! grep -qs 'devops-agent-workflow:generated' "$1"; then conflicts+="  $1 (bukan milik workflow ini)"$'\n'
  fi
}
for a in $AGENTS; do
  for n in $SKILLS; do check_link "$(skills_dir "$a")/$n"; done
  for f in "${ROLES[@]}"; do  # generated role files are ours only if they carry the marker
    n=$(basename "$f" .md)
    case $a in claude) e=md;; codex) e=toml;; copilot) e=agent.md;; *) e=md;; esac
    check_link "$(roles_dir "$a")/$n.$e"
  done
done
if [ -n "$conflicts" ] && [ "$FORCE" = 0 ]; then
  echo "Bentrok: skill/agen dengan nama sama sudah terpasang dari repo lain:" >&2
  printf '%s' "$conflicts" | sort -u >&2
  echo "Satu tempat = satu workflow role. Pakai --force untuk menggantinya dengan workflow DevOps." >&2
  exit 3
fi

link() { # src dst
  mkdir -p "$(dirname "$2")"
  [ -e "$2" ] && [ ! -L "$2" ] && mv "$2" "$2.bak-devops-workflow"
  ln -sfn "$1" "$2"
}

# role files: Claude uses agents/*.md as is; other tools get a converted copy
gen_role() { # tool src out
  python3 - "$1" "$2" "$3" <<'PY'
import json, re, sys
tool, src, out = sys.argv[1:4]
text = open(src, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
meta = dict(re.findall(r"^([A-Za-z_-]+):[ \t]*(.*)$", m.group(1), re.M))
body = m.group(2).lstrip("\n")
name, desc = meta["name"], meta["description"]
mark = "devops-agent-workflow:generated (jangan diedit; sumber: agents/%s.md)" % name
q = json.dumps  # a JSON string is a valid YAML double-quoted / TOML basic string
if tool == "codex":
    assert "'''" not in body
    res = "# %s\nname = %s\ndescription = %s\ndeveloper_instructions = '''\n%s'''\n" % (mark, q(name), q(desc), body)
else:
    fm = {"gemini": [("name", q(name)), ("description", q(desc))],
          "cursor": [("name", q(name)), ("description", q(desc)), ("model", "inherit")],
          "copilot": [("name", q(name)), ("description", q(desc))],
          "opencode": [("description", q(desc)), ("mode", "subagent")]}[tool]
    res = "---\n" + "".join("%s: %s\n" % kv for kv in fm) + "---\n<!-- %s -->\n%s" % (mark, body)
open(out, "w", encoding="utf-8").write(res)
PY
}
install_roles() { # tool
  local t=$1 d f n ext
  d=$(roles_dir "$t"); mkdir -p "$d"
  for f in "${ROLES[@]}"; do
    n=$(basename "$f" .md)
    case $t in
      claude) link "$f" "$d/$n.md"; continue;;
      codex) ext=toml;; copilot) ext=agent.md;; *) ext=md;;
    esac
    gen_role "$t" "$f" "$d/$n.$ext"
  done
  return 0
}

# instructions: one marked block, replaced on reinstall, shared by tools that read the same file
install_instr() { # file
  local f=$1 tmp
  [ -n "$f" ] || return 0
  mkdir -p "$(dirname "$f")"; touch "$f"
  tmp=$(mktemp)
  if grep -q '<!-- devops-agent-workflow:start -->' "$f"; then
    awk -v blk="$REPO/templates/instructions.md" '
      /<!-- devops-agent-workflow:start -->/ { print; while ((getline l < blk) > 0) print l; skip = 1; next }
      /<!-- devops-agent-workflow:end -->/ { skip = 0 }
      !skip' "$f" > "$tmp" && cat "$tmp" > "$f"
  elif ! grep -q '^# DevOps agent workflow' "$f"; then  # older install wrote the heading without markers
    { [ -s "$f" ] && echo; echo '<!-- devops-agent-workflow:start -->'; cat "$REPO/templates/instructions.md"; echo '<!-- devops-agent-workflow:end -->'; } >> "$f"
  fi
  rm -f "$tmp"
}

# JSON hook config: {hooks: {EVENT: [{matcher, hooks: [{type: command, command}]}]}}, our entry replaced
merge_hook() { # file event matcher command [extra-json-for-hook]
  local f=$1 x=${5:-} tmp; [ -n "$x" ] || x='{}'; mkdir -p "$(dirname "$f")"
  [ -s "$f" ] || echo '{}' > "$f"
  [ -e "$f.bak-devops-workflow" ] || cp "$f" "$f.bak-devops-workflow"
  tmp=$(mktemp)
  jq --arg e "$2" --arg m "$3" --arg c "$4" --argjson x "$x" '
    def ours: any((.hooks // [])[]?; (.command // "") | tostring | test("/hooks/(guard|adapter)\\.sh\"?( [a-z]+)?$"));
    .hooks[$e] = ([(.hooks[$e] // [])[] | select(ours | not)] + [{matcher: $m, hooks: [{type: "command", command: $c} + $x]}])' "$f" > "$tmp"
  mv "$tmp" "$f"
}

install_hook() { # tool
  local t=$1 f tmp
  case $t in
    claude) merge_hook "$B/.claude/settings.json" PreToolUse 'Bash|Edit|Write|MultiEdit|NotebookEdit|mcp__claude_ai_Atlassian__.*' "$G";;
    codex)
      merge_hook "$B/.codex/hooks.json" PreToolUse Bash "$G" '{"statusMessage":"DevOps guard"}'
      NOTES+=("codex: hook baru harus dipercaya dulu: jalankan /hooks di Codex lalu setujui 'DevOps guard' (hook project hanya jalan di project yang dipercaya).");;
    gemini) merge_hook "$B/.gemini/settings.json" BeforeTool run_shell_command "$A gemini" '{"name":"devops-guard","timeout":60000}';;
    cursor)
      f="$B/.cursor/hooks.json"; mkdir -p "$(dirname "$f")"; [ -s "$f" ] || echo '{}' > "$f"
      [ -e "$f.bak-devops-workflow" ] || cp "$f" "$f.bak-devops-workflow"
      tmp=$(mktemp)
      jq --arg c "$A cursor" '.version = (.version // 1)
        | .hooks.beforeShellExecution = ([(.hooks.beforeShellExecution // [])[] | select((.command // "") | test("/hooks/adapter\\.sh\"? cursor$") | not)] + [{command: $c}])' "$f" > "$tmp"
      mv "$tmp" "$f";;
    copilot)
      case $SCOPE in global) f="$B/.copilot/hooks/devops-guard.json";; project) f="$B/.github/hooks/devops-guard.json";; esac
      mkdir -p "$(dirname "$f")"
      jq -n --arg c "$A copilot" '{version: 1, hooks: {preToolUse: [{type: "command", bash: $c, timeoutSec: 30}]}}' > "$f"
      NOTES+=("copilot: hook masih preview; hook repo butuh folder tepercaya (VS Code: chat.useHooks).");;
    opencode)
      NOTES+=("opencode: TIDAK punya hook pemblokir, jadi guard tidak terpasang. Semua pagar hanya aturan yang dipatuhi agen. Batasi dengan aturan 'permissions' (deny) di opencode.json; lihat docs/pasang.md.");;
  esac
  return 0
}

# --- install ---
link "$REPO" "$DEST/.agent-workflow/devops"   # neutral path used by every skill
mkdir -p "$DEST/.agent-workflow/logs" "$DEST/.agent-workflow/projects"
done_instr=' '
for a in $AGENTS; do
  sd=$(skills_dir "$a")
  for n in $SKILLS; do link "$REPO/skills/$n" "$sd/$n"; done
  if [ "$a" = claude ] && [ -L "$sd/_devops-workflow-shared" ]; then rm -f "$sd/_devops-workflow-shared"; fi  # old layout
  install_roles "$a"
  f=$(instr_file "$a")
  if [ -z "$f" ]; then
    NOTES+=("cursor: aturan global Cursor hanya bisa diisi lewat UI (Settings → Rules). Tempel isi templates/instructions.md di sana, atau pasang dengan --scope project (AGENTS.md).")
  elif [[ $done_instr != *" $f "* ]]; then install_instr "$f"; done_instr+="$f "
  fi
  install_hook "$a"
done

if [ "$(uname)" = Darwin ]; then
  P="$REPO/launchd/com.agentworkflow.devops.housekeeping.plist"
  out="$DEST/Library/LaunchAgents/$(basename "$P")"
  mkdir -p "$(dirname "$out")"
  sed -e "s|__AGENT_WORKFLOW_DIR__|$REPO|g" -e "s|__HOME__|$DEST|g" "$P" > "$out"
  if [ "$CUSTOM" = 0 ]; then
    launchctl bootout "gui/$(id -u)" "$out" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$out"
  fi
else
  NOTES+=("housekeeping (Linux): jadwalkan tiap jam lewat 'crontab -e':  0 * * * * /bin/bash \"$REPO/bin/housekeeping.sh\"")
fi

echo "Terpasang: agent = $AGENTS, scope = $SCOPE ($B)"
[ "$SCOPE" != project ] || echo "Folder yang dibuat di repo berisi symlink ke $REPO: tiap anggota tim menjalankan install.sh sendiri (atau masukkan ke .gitignore)."
for n in ${NOTES[@]+"${NOTES[@]}"}; do echo "- $n"; done
exit 0
