#!/bin/bash
# Claude Code PreToolUse guard (DevOps). stdin = hook JSON. exit 0 = allow, exit 2 + stderr = block.
# One check_<tool> function per tool; unknown tools and unparseable input are allowed.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
PROTECTED='main|master|develop'
VTAG='v[0-9]+\.[0-9]+\.[0-9]+'
# a path segment / vault label that names production (fail-safe even before inventories are set up)
PROD_RE='(^|[/_.@-])(prod|production|prd|live)([/_.@-]|$)'
# ansible ad-hoc modules that only read; the only modules allowed against production and in audit mode
READ_MODULES=' ping setup gather_facts service_facts package_facts stat '

block() { echo "DIBLOKIR oleh guard: $*" >&2; exit 2; }

JQ=$(command -v jq) || block "jq tidak ditemukan, guard tidak bisa memeriksa perintah. Install jq."
PY=$(command -v python3)
STATE=${AGENT_WORKFLOW_STATE:-$HOME/.agent-workflow}

# resolve $1 against $2 (dir); pure string, python normalizes later
join_path() { case $1 in /*) echo "$1";; *) echo "$2/$1";; esac; }

# expand leading ~ / $HOME / ${HOME}; leaves other $vars untouched
expand_home() {
  case $1 in
    '~') echo "$HOME";;
    '~/'*) echo "$HOME/${1#\~/}";;
    '$HOME'|'${HOME}') echo "$HOME";;
    '$HOME/'*) echo "$HOME/${1#\$HOME/}";;
    '${HOME}/'*) echo "$HOME/${1#\$\{HOME\}/}";;
    *) echo "$1";;
  esac
}

# every ref is a version tag vX.Y.Z (name, refs/tags/name, or name:refs/tags/name) and not a local branch
version_tags_only() { # dir ref...
  local d=$1 r s; shift
  for r; do
    s=${r%%:*}; s=${s#refs/tags/}
    case $r in *:*) [ "${r#*:}" = "refs/tags/$s" ] || return 1;; esac
    echo "$s" | grep -Eqx "$VTAG" || return 1
    case ${r%%:*} in refs/tags/*) ;; *) ! git -C "$d" show-ref -q --verify "refs/heads/$s" 2>/dev/null || return 1;; esac
  done
}

# git [global opts] push ...   ($d = directory git runs in)
# Sets GSUB_OFF = index of git's subcommand among the args (so `git rm` isn't checked as rm).
check_git() {
  local d=$wd n=$# unk=''
  while [ $# -gt 0 ]; do
    case $1 in
      -C) d=$(join_path "$(expand_home "$2")" "$wd"); shift 2;;
      -c|--git-dir|--work-tree|--namespace|--super-prefix|--config-env) shift 2;;
      --*=*|-p|-P|--paginate|--no-pager|--bare|--no-replace-objects|--no-optional-locks|--*-pathspecs) shift;;
      -*) unk=1; shift;;
      *) break;;
    esac
  done
  GSUB_OFF=$((n - $#))
  [ -n "$AUDIT" ] && check_git_audit "$@"
  [ "$1" = worktree ] && case ${2:-} in add|remove|move) check_worktree "$d" "${@:2}";; esac
  # unknown global option may have swallowed a value: if `push` appears anywhere, treat as push
  if [ "$1" != push ] && [ -n "$unk" ]; then
    while [ $# -gt 0 ] && [ "$1" != push ]; do shift; done
  fi
  [ "$1" = push ] || return 0
  shift
  local remote='' repo='' destructive='' bulk='' refs=() r dst br
  while [ $# -gt 0 ]; do
    case $1 in
      --repo=*) repo=${1#--repo=};;
      --repo) repo=$2; shift;;
      -o|--push-option|--receive-pack|--exec) shift;;
      --force*|--mirror|--delete) destructive=1;;
      --tags|--follow-tags|--all|--branches) bulk=1;;
      --*) ;;
      -*[fd]*) destructive=1;;
      -*) ;;
      *) if [ -z "$remote" ]; then remote=$1; else refs+=("$1"); fi;;
    esac
    shift
  done
  [ -n "$remote" ] || remote=$repo  # positional remote wins over --repo
  # Release pushes version tags to origin and upstream; explicit refs only, never force/delete/bulk
  [ -z "$destructive$bulk" ] && [ ${#refs[@]} -gt 0 ] && version_tags_only "$d" "${refs[@]}" && return 0

  br=$(git -C "$d" symbolic-ref --short -q HEAD 2>/dev/null)
  if [ -z "$remote" ]; then
    remote=$(git -C "$d" config "branch.$br.pushRemote" 2>/dev/null ||
             git -C "$d" config remote.pushDefault 2>/dev/null ||
             git -C "$d" config "branch.$br.remote" 2>/dev/null)
    [ -n "$remote" ] || block "remote untuk 'git push' tidak bisa dipastikan. Tulis eksplisit: git push origin <branch>."
  fi
  if [ "$remote" != origin ]; then
    local ou ru
    ou=$(git -C "$d" remote get-url --push origin 2>/dev/null)
    ru=$(git -C "$d" remote get-url --push "$remote" 2>/dev/null || echo "$remote")
    [ -n "$ou" ] && [ "$ru" = "$ou" ] ||
      block "push ke remote '$remote' dilarang; hanya boleh ke origin (fork). Gunakan: git push origin <branch>, lalu buat PR/MR."
  fi

  [ ${#refs[@]} -eq 0 ] && refs=(HEAD)
  for r in "${refs[@]}"; do
    dst=${r#+}; dst=${dst##*:}; dst=${dst#refs/heads/}
    [ "$dst" = HEAD ] && dst=$br
    case $r in +*|:*) ;; *) [ -n "$destructive" ] || continue;; esac
    if echo "$dst" | grep -Eqx "$PROTECTED"; then
      block "force-push/hapus branch terlindungi '$dst' dilarang. Push tanpa --force/+, atau ke branch fitur."
    fi
  done
}

audit_block() { block "$1 dilarang: mode audit hanya-baca (/audit-issue). Catat temuan di laporan, jangan ubah repo/Jira/server."; }

# audit mode: only read-only git subcommands; branch/tag only list, never create/delete
check_git_audit() {
  local s=${1:-} a list='' skip=''
  shift
  case $s in
    ''|show|log|grep|blame|diff|status|ls-files|ls-tree|rev-parse|rev-list|describe|cat-file|for-each-ref|show-ref|shortlog|name-rev|merge-base|help|version|--version|--help) return 0;;
    fetch) for a; do case $a in *:*) audit_block "git fetch $a (refspec menulis branch lokal)";; esac; done;;
    reflog) case ${1:-} in expire|delete) audit_block "git reflog $1";; esac;;
    branch|tag)
      for a; do
        [ -n "$skip" ] && { skip=''; continue; }
        case $a in
          -l|--list) list=1;;
          --contains|--no-contains|--merged|--no-merged|--points-at|--sort|--format) skip=1;;
          -a) [ "$s" = tag ] && audit_block "git tag -a";;
          -d|-D|-m|-M|-c|-C|-f|-u|-s|-F|-e|--delete|--move|--copy|--force|--annotate|--sign|--edit-description|--unset-upstream|--set-upstream-to*|--track*|--file*|--message*) audit_block "git $s $a";;
          -*) ;;
          *) [ -n "$list" ] || audit_block "git $s $a";;
        esac
      done;;
    remote)
      case ${1:-} in -v|--verbose) shift;; esac
      case ${1:-} in ''|get-url|show) ;; *) audit_block "git remote $1";; esac;;
    config) for a; do case $a in --get|--get-all|--get-regexp|--list|-l) return 0;; esac; done; audit_block "git config";;
    worktree) [ "${1:-}" = list ] || audit_block "git worktree ${1:-}";;
    stash) case ${1:-} in list|show) ;; *) audit_block "git stash ${1:-}";; esac;;
    *) audit_block "git $s";;
  esac
  return 0
}

# audit mode: glab read-only (gh is not checked here, same decision as the mobile workflow)
check_forge() {
  local a prev=''
  case ${1:-} in
    ''|search|status|help|version|--version|--help|-h) ;;
    auth) [ "${2:-}" = status ] || audit_block "gh/glab auth ${2:-}";;
    api)
      for a; do
        case $a in -f*|-F*|--field*|--raw-field*|--input*) audit_block "gh/glab api $a";; esac
        case $prev in -X|--method) [ "$a" = GET ] || audit_block "gh/glab api $prev $a";; esac
        case $a in --method=*) [ "${a#*=}" = GET ] || audit_block "gh/glab api $a";; -X?*) [ "${a#-X}" = GET ] || audit_block "gh/glab api $a";; esac
        prev=$a
      done;;
    *) case ${2:-} in view|list|ls|status|diff|checks|show|watch|-h|--help) ;; *) audit_block "gh/glab $1 ${2:-}";; esac;;
  esac
  return 0
}

# gh/glab, every mode: agents never start a pipeline (deploys are run by a human or by the pipeline itself)
check_deploy() { # tool args...
  local t=$1 a; shift
  case "$t ${1:-} ${2:-}" in
    'gh workflow run'|'gh workflow enable'|'gh run rerun'|'glab ci run'|'glab ci retry'|'glab ci trigger'|'glab pipeline run'|'glab job retry'|'glab job play'|'glab ci play')
      block "$t ${1:-} ${2:-} dilarang: agen tidak memicu pipeline. Penerapan dijalankan manusia atau pipeline; minta user.";;
  esac
  if [ "${1:-}" = api ]; then
    for a; do case $a in */dispatches|*/dispatches\?*|*/pipeline|*/pipeline\?*|*/trigger/pipeline*|*/jobs/*/play|*/jobs/*/retry|*/rerun|*/rerun-failed-jobs)
      block "$t api $a dilarang: memicu pipeline/workflow. Minta user.";; esac; done
  fi
  return 0
}

# true when $1 resolves inside ${TMPDIR:-/tmp}/audit or /tmp/audit (symlinks like /tmp -> /private/tmp resolved)
in_audit_dir() {
  "$PY" -c '
import os, sys
def rp(p):
    head, tail = p, ""
    while not os.path.exists(head) and head != "/":
        head, t = os.path.split(head); tail = os.path.join(t, tail) if tail else t
    return os.path.normpath(os.path.join(os.path.realpath(head), tail))
f = rp(sys.argv[1])
sys.exit(0 if any(f.startswith(rp(r).rstrip("/") + "/") for r in sys.argv[2:]) else 1)
' "$1" "${TMPDIR:-/tmp}/audit" /tmp/audit
}

# git worktree add/remove: only a sibling of the current checkout; remove only ticket
# worktrees (<repo>-<number>) and release worktrees, never forced (rules.md, Workspace & worktree)
check_worktree() {
  local d=$1 op=$2 p='' top
  shift 2
  [ "$op" = move ] && block "git worktree move dilarang: jangan memindah worktree. Minta user."
  while [ $# -gt 0 ]; do
    case $1 in
      -b|-B|--reason) shift 2;;
      -f|--force) [ "$op" = remove ] && block "git worktree remove --force dilarang: worktree yang masih ada perubahan tidak boleh dipaksa hapus. Commit + push dulu, atau minta user."; shift;;
      -*) shift;;
      *) [ -n "$p" ] || p=$1; shift;;
    esac
  done
  [ -n "$p" ] || return 0
  [ -n "$PY" ] || block "python3 tidak ditemukan, guard tidak bisa memeriksa path worktree."
  top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || block "git worktree $op: repo tidak dikenali di $d."
  p=$("$PY" -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$(join_path "$(expand_home "$p")" "$d")")
  top=$("$PY" -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "$top")
  [ "${p%/*}" = "$top" ] || block "git worktree $op hanya untuk folder sejajar checkout ini ($top/<repo>-<nomor tiket>), tulis path apa adanya tanpa variabel: $p (rules.md, Workspace & worktree)."
  [ "$op" = remove ] && ! [[ ${p##*/} =~ -[0-9]+$|-rilis-v[0-9][0-9.]*$ ]] && block "git worktree remove hanya untuk worktree tiket <repo>-<nomor tiket> atau worktree rilis sementara <repo>-rilis-vX.Y.Z: ${p##*/} bukan worktree agen (worktree domain/milik user tidak dihapus agen)."
  return 0
}

# orca: no new projects/repos or workspaces outside the user's domain (rules.md, Workspace & worktree)
check_orca() {
  local a
  case "$1 ${2:-}" in
    'repo add'|'project setup-'*) block "orca $1 $2 dilarang: agen tidak membuat project/repo Orca baru. Minta user.";;
    'worktree create') [ -n "$AUDIT" ] && audit_block "orca worktree create";;
    'terminal split') block "orca terminal split dilarang: agen tambahan = teammate (tool Agent dengan name \"<Nama>-<Label><n>\") (rules.md, Orkestrasi).";;
    'terminal create'|'agent launch') block "orca $1 $2 dilarang: membuka tab baru. Agen tambahan = teammate (tool Agent dengan name) (rules.md, Orkestrasi).";;
    'orchestration worker-start') case " $* " in *' --agent '*|*' --agent='*) block "worker-start --agent dilarang: membuka tab baru. Agen tambahan = teammate (rules.md, Orkestrasi).";; esac;;
  esac
  for a; do
    case $a in
      --no-parent|new-child|new-top-level|--worktree=new-child|--worktree=new-top-level)
        block "orca $a dilarang: semua agen bekerja di workspace domain (teammate di workspace ini). Lihat rules.md.";;
    esac
  done
}

# rm -r/-R/--recursive: every target must be strictly inside the project root
check_rm() {
  local rec='' endopt='' paths=() a bad wts
  for a; do
    if [ -z "$endopt" ]; then
      case $a in
        --) endopt=1; continue;;
        --recursive) rec=1; continue;;
        --*) continue;;
        -*[rR]*) rec=1; continue;;
        -*) continue;;
      esac
    fi
    paths+=("$(expand_home "$a")")
  done
  [ -n "$rec" ] || return 0
  for a in ${paths[@]+"${paths[@]}"}; do
    case $a in *'$'*|*'`'*|'~'*|*'{}'*) block "rm -r dengan variabel/path tak pasti ('$a') dilarang. Tulis path literal di dalam proyek.";; esac
  done
  [ ${#paths[@]} -gt 0 ] || block "rm -r tanpa path literal (mis. lewat xargs) dilarang. Tulis path di dalam proyek secara eksplisit."
  # other worktrees of this repo: only rebuildable test/lint caches
  wts=$(git -C "$root" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
  bad=$(WTS="$wts" "$PY" -c '
import os, sys
ART = {".molecule", ".tox", ".cache", ".pytest_cache", "__pycache__", ".ansible"}
c, root = sys.argv[1], os.path.realpath(sys.argv[2])
wts = [os.path.realpath(w) for w in os.environ.get("WTS", "").splitlines() if w]
TMP = [os.path.realpath(p) + os.sep for p in ("/tmp/qa", "/tmp/validate")]
def artifact(r):
    if any(r.startswith(t) for t in TMP):  # temporary QA / validation output
        return True
    for w in wts:
        if r.startswith(w + os.sep) and ART & set(os.path.relpath(r, w).split(os.sep)):
            return True
    return False
for p in sys.argv[3:]:
    n = os.path.normpath(os.path.join(c, p))
    # trailing slash makes rm follow a symlink, so check its target
    r = os.path.realpath(n) if p.endswith("/") else os.path.join(os.path.realpath(os.path.dirname(n)), os.path.basename(n))
    if not r.startswith(root + os.sep) and not artifact(r):
        print(p); break
' "$wd" "$root" "${paths[@]}" 2>/dev/null) || block "path rm -r tidak bisa diverifikasi (python3 gagal)."
  [ -z "$bad" ] || block "rm -r di luar proyek ($root) dilarang: '$bad'. Hapus hanya path di dalam proyek, cache uji (.molecule, .tox, .cache, __pycache__) di worktree lain repo ini, atau isi /tmp/qa dan /tmp/validate."
}

# Tokenize like a shell (quotes kept together); one line per simple command, tokens joined by \x1f.
# Strings run by `sh -c`/`eval`, and $(...)/`...` contents, are tokenized again as extra lines.
TOKENIZER='
import json, re, shlex, sys
SEP = set("();<>|&\n")
def toks(c):
    c = re.sub(r"(?<!\\)((?:\\\\)*)\\\n", r"\1", c)  # line continuation
    try:
        l = shlex.shlex(c, posix=True, punctuation_chars="();<>|&\n")
        l.whitespace = " \t\r"  # unquoted newline separates commands
        l.whitespace_split = True; l.commenters = ""
        return list(l)
    except ValueError:  # unbalanced quotes: crude split, fail closed
        return [t.strip("\"\x27") for t in re.findall(r"[();<>|&\n]+|[^\s();<>|&]+", c)]
def segs(c, depth=0):
    out, cur, prev = [], [], ""
    for t in toks(c):
        if t and all(ch in SEP for ch in t):
            out.append(cur); cur = []; prev = t; continue
        if not t.strip(): continue  # stray escaped whitespace
        if depth < 3 and ("$(" in t or "`" in t or (re.search(r"\s", t) and (re.fullmatch(r"-\w*c", prev) or prev == "eval"))):
            out += segs(t.replace("`", " "), depth + 1)
        t = t.replace("`", "").replace("\n", " ").replace("\x1f", " ")
        cur.append(t)
        if t != "--": prev = t  # sh -c -- "cmd"
    return out + [cur]
cmd = (json.load(sys.stdin).get("tool_input") or {}).get("command") or ""
for s in segs(cmd):
    if s: print("\x1f".join(s))
'

# --- locks (bin/lock.sh): staging hosts are used by one agent at a time ---
lock_dir() { printf '%s/%s' "${AGENT_LOCK_DIR:-$STATE/locks}" "$(printf '%s' "$1" | sed 's/%/%25/g; s#/#%2F#g; s/:/%3A/g')"; }

# $$ and up to 8 ancestor pids (cached in ANC); a lock of any of them is our own
ancestors() {
  [ -n "${ANC:-}" ] && return 0
  local p=$$
  for _ in 0 1 2 3 4 5 6 7 8; do
    ANC="$ANC $p"
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    [ -n "$p" ] && [ "$p" -gt 1 ] || break
  done
  ANC="$ANC "
}

# <res> must be locked by a live pid that is us (or our ancestor)
require_own_lock() {
  local d p o
  d=$(lock_dir "$1"); p=$(cat "$d/pid" 2>/dev/null); o=$(cat "$d/owner" 2>/dev/null)
  if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
    ancestors; [[ $ANC == *" $p "* ]] && return 0
    block "host staging $1 sedang dikunci $o. Tunggu atau tanya SPV/user (infra.md → Host staging)."
  fi
  block "host staging $1 belum kamu kunci. Ambil dulu: AGENT_LOCK_PID=\$PPID \"\$AGENT_WORKFLOW_DIR/bin/lock.sh\" acquire $1 <KODE>-<peran><n> (infra.md → Host staging)."
}

# --- ansible ---
# repo key for ansible-inventories.json = folder name of the primary checkout (same for all worktrees)
repo_key() {
  local c
  c=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  c=${c%/}
  case $c in */.git) c=${c%/.git};; *) c=${c%.git};; esac
  echo "${c##*/}"
}

# classify inventories against ${STATE}/ansible-inventories.json; one line per inventory:
# local | production | staging<TAB><entry> | unknown | unset (repo has no list yet)
classify_inv() { # wd invs...
  local d=$1 top key; shift
  top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || echo "$d")
  key=$(repo_key "$d" || echo "")
  "$PY" - "$d" "$top" "$key" "$STATE/ansible-inventories.json" "$PROD_RE" "$@" <<'PY'
import json, os, re, sys
wd, top, key, cfgf, prod_re = sys.argv[1:6]
invs = sys.argv[6:]
try:
    cfg = json.load(open(cfgf)).get(key) if key else None
except Exception:
    cfg = None
top = os.path.realpath(top)
def norm(e): return os.path.normpath(e).strip("/")
def under(rel, e): return rel == e or rel.startswith(e + "/")
for inv in invs:
    if "," in inv:  # inline host list
        hosts = [h.strip() for h in inv.split(",") if h.strip()]
        print("local" if hosts and all(h in ("localhost", "127.0.0.1") for h in hosts) else "unknown"); continue
    p = inv if inv.startswith("/") else os.path.join(wd, inv)
    r = os.path.realpath(p)
    rel = os.path.relpath(r, top) if (r + "/").startswith(top + "/") else None
    if re.search(prod_re, r if rel is None else rel, re.I):
        print("production"); continue
    if rel is None:
        print("unknown"); continue
    if cfg is None:
        print("unset"); continue
    if any(under(rel, norm(e)) for e in cfg.get("production", [])):
        print("production"); continue
    hit = [norm(e) for e in cfg.get("staging", []) if under(rel, norm(e))]
    print("staging\t" + hit[0] if hit else "unknown")
PY
}

# ansible-vault ids/password files/files: a production-looking one is blocked
prod_vault_ref() { # value
  local v=$1 lab src
  case $v in *@*) lab=${v%%@*}; src=${v#*@};; *) lab=''; src=$v;; esac
  printf '%s\n' "$lab" "$src" | grep -Eqi "$PROD_RE"
}

# -e ansible_host=... redirects a staging inventory to any machine: never allowed
host_override() {
  case $1 in *ansible_host*|*ansible_ssh_host*)
    block "extra-vars yang mengganti ansible_host dilarang: host hanya dari inventory staging yang terdaftar.";; esac
}

check_vault() { # args after ansible-vault
  local sub='' files=() a skip=''
  [ -n "$AUDIT" ] && audit_block "ansible-vault"
  for a; do
    if [ -n "$skip" ]; then
      [ "$skip" = v ] && prod_vault_ref "$a" && block "ansible-vault dengan vault production ('$a') dilarang: Vault production hanya dibuka manusia."
      skip=''; continue
    fi
    case $a in
      --vault-id|--vault-password-file|--vault-pass-file|--new-vault-id|--new-vault-password-file|--encrypt-vault-id) skip=v;;
      --vault-id=*|--vault-password-file=*|--vault-pass-file=*|--new-vault-id=*|--new-vault-password-file=*|--encrypt-vault-id=*)
        prod_vault_ref "${a#*=}" && block "ansible-vault dengan vault production ('${a#*=}') dilarang: Vault production hanya dibuka manusia.";;
      --output|-n|--name|--stdin-name) skip=1;;
      -h|--help|--version) return 0;;
      -*) ;;
      *) if [ -z "$sub" ]; then sub=$a; else files+=("$a"); fi;;
    esac
  done
  [ "$sub" = decrypt ] && block "ansible-vault decrypt dilarang: menulis rahasia polos ke disk. Pakai 'ansible-vault view' (staging saja) dan jangan salin nilainya."
  for a in ${files[@]+"${files[@]}"}; do
    case $(classify_inv "$wd" "$a" | head -1) in
      production) block "ansible-vault $sub '$a' dilarang: file vault production hanya dibuka manusia.";;
    esac
  done
  return 0
}

# ansible / ansible-playbook / ansible-inventory / ansible-vault / ansible-pull / ansible-console
# $1 = tool basename, $2 = ANSIBLE_INVENTORY= seen earlier in the segment, rest = args
check_ansible() {
  local tool=$1 envinv=$2 a skip='' synt='' list='' mod=command invs=() line cls ent v
  shift 2
  case $tool in
    ansible-pull|ansible-console) block "$tool dilarang: menjalankan perubahan di luar alur (pakai ansible-playbook ke inventory staging).";;
    ansible-vault) check_vault "$@"; return 0;;
  esac
  for a; do case $a in --version|-h|--help) return 0;; esac; done
  for v in ${envvault[@]+"${envvault[@]}"}; do
    prod_vault_ref "$v" && block "vault production ('$v') dilarang: Vault production hanya dibuka manusia."
  done
  if [ -n "$envinv" ]; then IFS=, read -ra invs <<< "$envinv"; fi
  for a; do
    if [ -n "$skip" ]; then
      case $skip in
        i) invs+=("$a");;
        v) prod_vault_ref "$a" && block "$tool dengan vault production ('$a') dilarang: Vault production hanya dibuka manusia.";;
        m) mod=${a##*.};;
        e) host_override "$a";;
      esac
      skip=''; continue
    fi
    case $a in
      -i|--inventory|--inventory-file) skip=i;;
      --inventory=*|--inventory-file=*) invs+=("${a#*=}");;
      -i?*) invs+=("${a#-i}");;
      --vault-id|--vault-password-file|--vault-pass-file) skip=v;;
      --vault-id=*|--vault-password-file=*|--vault-pass-file=*)
        prod_vault_ref "${a#*=}" && block "$tool dengan vault production ('${a#*=}') dilarang: Vault production hanya dibuka manusia.";;
      -m|--module-name) skip=m;;
      --module-name=*) mod=${a#*=}; mod=${mod##*.};;
      --syntax-check) synt=1;;
      --list-hosts|--list-tasks|--list-tags) list=1;;
      -e|--extra-vars) skip=e;;
      --extra-vars=*) host_override "${a#*=}";;
      -l|--limit|-t|--tags|--skip-tags|-u|--user|-f|--forks|-M|--module-path|--start-at-task|-c|--connection|-T|--timeout|--private-key|--key-file|--ssh-common-args|--ssh-extra-args|--scp-extra-args|--sftp-extra-args|--become-method|--become-user|-B|--background|-P|--poll|-a|--args|--task-timeout|--playbook-dir) skip=1;;
      --*) ;;
      -*i) skip=i;;  # clustered short flags ending in -i: next arg is the inventory
      *) ;;
    esac
  done

  # ansible-inventory only reads inventory + vars (needed by /inventory-check): any inventory is fine
  [ "$tool" = ansible-inventory ] && return 0
  local read=''
  [ "$tool" = ansible ] && [[ $READ_MODULES == *" $mod "* ]] && read=1
  if [ -n "$AUDIT" ]; then
    [ "$tool" = ansible-playbook ] && [ -z "$synt$list" ] && audit_block "ansible-playbook tanpa --syntax-check/--list-*"
    [ "$tool" = ansible ] && [ -z "$read" ] && audit_block "ansible -m $mod (modul baca saja:$READ_MODULES)"
  fi
  if [ ${#invs[@]} -eq 0 ]; then
    [ -n "$synt" ] && return 0
    block "$tool tanpa inventory eksplisit dilarang (default ansible.cfg bisa menunjuk production). Tulis -i <inventory staging>."
  fi
  while IFS=$'\t' read -r cls ent; do
    case $cls in
      local) ;;
      production)
        [ -n "$read" ] && continue  # read-only facts from production: /verify-live, /read-logs
        block "$tool ke inventory production dilarang: agen tidak pernah menerapkan ke production. Siapkan runbook + PR rilis; penerapan dijalankan manusia atau pipeline.";;
      unset) block "repo ini belum punya daftar inventory staging/production ($STATE/ansible-inventories.json). Minta user: jalankan 'Setup inventory' (infra.md).";;
      staging)
        [ -n "$synt$list$read$AUDIT" ] && continue
        require_own_lock "staging:$(repo_key "$wd")/$ent";;
      *) block "inventory '${invs[*]}' bukan inventory staging yang terdaftar di $STATE/ansible-inventories.json. Pakai inventory staging, atau minta user memperbarui daftar (infra.md → Setup inventory).";;
    esac
  done < <(classify_inv "$wd" "${invs[@]}")
  return 0
}

check_Bash() {
  local segs w i c t prev gsub envinv envvault=() rest
  [ -n "$PY" ] || block "python3 tidak ditemukan, guard tidak bisa memeriksa perintah Bash."
  segs=$(printf '%s' "$input" | "$PY" -c "$TOKENIZER" 2>/dev/null) || block "perintah Bash tidak bisa diurai oleh guard."
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
  wd=$cwd   # follows cd/pushd inside the chained command
  while IFS=$'\x1f' read -ra w; do
    gsub=-1; prev=''; envinv=''; envvault=()
    # any git/rm/ansible token starts a command, wherever it sits (sudo -u x, timeout 60, VAR=..., uv run ...)
    for ((i = 0; i < ${#w[@]}; i++)); do
      c=${w[$i]##*/}
      case ${w[$i]} in [A-Za-z_]*=*) c=${w[$i]};; esac  # VAR=value keeps its slashes
      case $c in
        cd|pushd)  # only in command position, so `echo cd x` doesn't move wd
          case $prev in ''|'!'|'{'|then|do|else|if|while|until|command|builtin)
            t=$(expand_home "${w[$((i+1))]:-~}")
            case $t in *'$'*|-*) wd=/;; *) wd=$(join_path "$t" "$wd");; esac;;
          esac;;
        git) GSUB_OFF=-1; check_git "${w[@]:$((i+1))}"; gsub=$((i + 1 + GSUB_OFF));;
        orca) check_orca "${w[@]:$((i+1))}";;
        gh) check_deploy gh "${w[@]:$((i+1))}";;
        glab) check_deploy glab "${w[@]:$((i+1))}"; [ -n "$AUDIT" ] && check_forge "${w[@]:$((i+1))}";;
        rm) [ $i -eq $gsub ] || check_rm "${w[@]:$((i+1))}";;
        ANSIBLE_INVENTORY=*) envinv=${w[$i]#*=};;
        ANSIBLE_VAULT_PASSWORD_FILE=*|ANSIBLE_VAULT_IDENTITY_LIST=*) envvault+=("${w[$i]#*=}");;
        ansible-playbook|ansible-vault|ansible-pull|ansible-console|ansible-inventory)
          check_ansible "$c" "$envinv" "${w[@]:$((i+1))}";;
        ansible)  # the word `ansible` (ls ansible) is not the CLI: command position, or options follow
          rest=" ${w[*]:$((i+1))}"
          case $prev in
            ''|'!'|'{'|then|do|else|sudo|env|command|exec|nohup|time|xargs|run|--|*=*) check_ansible ansible "$envinv" "${w[@]:$((i+1))}";;
            *) [[ $rest == *' -'* ]] && check_ansible ansible "$envinv" "${w[@]:$((i+1))}";;
          esac;;
        molecule) [ -n "$AUDIT" ] && audit_block "molecule (membuat container uji)";;
      esac
      prev=${w[$i]}
    done
  done <<< "$segs"
  return 0
}

# Edit/Write/MultiEdit: the primary (main) worktree is read-only once the repo has a linked worktree
# (Orca pattern); a plain checkout without linked worktrees is editable.
check_edit() {
  local f d pd gd cd_
  f=$(printf '%s' "$input" | "$JQ" -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
  [ -n "$f" ] || return 0
  [ -n "$PY" ] || block "python3 tidak ditemukan, guard tidak bisa memeriksa path."
  f=$(join_path "$(expand_home "$f")" "$cwd")
  if [ -n "$AUDIT" ]; then
    in_audit_dir "$f" || audit_block "edit file di luar folder kerja audit ${TMPDIR:-/tmp}/audit/ ($f)"
    return 0
  fi
  d=$("$PY" -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "$f") || return 0
  while [ ! -d "$d" ] && [ "$d" != / ]; do d=$(dirname "$d"); done  # new file: nearest existing parent
  pd=$(git -C "$d" rev-parse --absolute-git-dir 2>/dev/null) || return 0  # not in a git repo
  cd_=$(git -C "$d" rev-parse --git-common-dir 2>/dev/null)
  case $cd_ in /*) ;; *) cd_="$d/$cd_";; esac
  gd=$(cd -P "$cd_" 2>/dev/null && pwd -P) || return 0
  pd=$(cd -P "$pd" 2>/dev/null && pwd -P) || return 0
  [ "$pd" = "$gd" ] || return 0
  [ "$(git -C "$d" worktree list --porcelain 2>/dev/null | grep -c '^worktree ')" -gt 1 ] && block "edit file di worktree utama dilarang: $f. Kerjakan di checkout workspace domain atau worktree tiket (rules.md, Workspace & worktree)."
  return 0
}

# transitionJiraIssue: only transition ids allowed for the project in ${STATE}/jira-transitions.json
check_jira() {
  local cfg=$STATE/jira-transitions.json key id proj
  key=$(printf '%s' "$input" | "$JQ" -r '.tool_input.issueIdOrKey // empty' 2>/dev/null)
  id=$(printf '%s' "$input" | "$JQ" -r '.tool_input.transition.id // empty' 2>/dev/null)
  proj=$(printf '%s' "$key" | sed -E 's/-[0-9]+$//')
  "$JQ" -e type "$cfg" >/dev/null 2>&1 || block "config transisi Jira tidak ada/rusak ($cfg). Minta user: jalankan setup transisi."
  "$JQ" -e --arg p "$proj" 'has($p)' "$cfg" >/dev/null 2>&1 || block "project '$proj' belum punya daftar transisi. Minta user: jalankan setup transisi."
  "$JQ" -e --arg p "$proj" --arg i "$id" '.[$p].allow // [] | map(tostring) | index($i) != null' "$cfg" >/dev/null 2>&1 ||
    block "transisi id '$id' untuk $proj tidak diizinkan. Done hanya dipindah kolega; pindahkan hanya ke status yang ada di daftar allow."
}

input=$(cat)
tool=$(printf '%s' "$input" | "$JQ" -r '.tool_name // empty' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$input" | "$JQ" -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD

# read-only audit mode (/audit-issue): env AGENT_AUDIT=1, or bin/audit-mode.sh marked one of our
# ancestor pids, i.e. the Claude session running this hook (SPV). The SPV's guard records
# session-<session_id> -> pid so its teammates (agent teams, not our descendants; their Claude runs
# with --parent-session-id) are audit too while that pid marker exists.
# shortcut: shell writes (sed -i, > file) and direct ssh are not caught; skills forbid them in audit mode
AUDIT=''
if [ "${AGENT_AUDIT:-}" = 1 ]; then
  AUDIT=1
else
  mk=$STATE/audit p=$$
  if [ -d "$mk" ]; then
    for _ in 1 2 3 4 5 6 7 8; do
      if [ -f "$mk/$p" ]; then
        AUDIT=1
        sid=$(printf '%s' "$input" | "$JQ" -r '.session_id // empty' 2>/dev/null)
        [ -n "$sid" ] && echo "$p" > "$mk/session-$sid"
        break
      fi
      read -r pp cmd < <(ps -o ppid=,command= -p "$p" 2>/dev/null)
      case $cmd in *' --parent-session-id '*)
        sid=${cmd#* --parent-session-id }; sid=${sid%% *}
        lead=$(cat "$mk/session-$sid" 2>/dev/null)
        [ -n "$lead" ] && [ -f "$mk/$lead" ] && { AUDIT=1; break; } ;;
      esac
      p=$pp
      [ -n "$p" ] && [ "$p" -gt 1 ] || break
    done
  fi
fi

case $tool in
  Bash) check_Bash;;
  Edit|Write|MultiEdit|NotebookEdit) check_edit;;
  mcp__claude_ai_Atlassian__*)
    if [ -n "$AUDIT" ]; then
      case $tool in *__create*|*__edit*|*__add*|*__update*|*__transition*) audit_block "$tool";; esac
    elif [ "$tool" = mcp__claude_ai_Atlassian__transitionJiraIssue ]; then
      check_jira
    fi;;
esac
exit 0
