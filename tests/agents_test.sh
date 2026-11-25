#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"

# fm FILE KEY -> value of KEY in the leading --- frontmatter block (empty if absent)
fm() { awk -v k="$2" 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1&&index($0,k": ")==1{print substr($0,length(k)+3)}' "$1"; }

for pair in spv:opus planner:claude-fable-5-2 validator:opus reviewer:opus release:haiku coder:sonnet qa:sonnet auditor:opus analis:opus hoe:opus pjm:sonnet eskalasi:claude-fable-5-2; do
  n=${pair%%:*} m=${pair#*:} f="$REPO/agents/$n.md"
  assert_eq yes "$([ -f "$f" ] && echo yes || echo no)" "agents/$n.md exists"
  [ -f "$f" ] || continue
  assert_eq "$n" "$(fm "$f" name)" "$n: name"
  assert_eq "$m" "$(fm "$f" model)" "$n: model"
  assert_eq yes "$([ -n "$(fm "$f" description)" ] && echo yes || echo no)" "$n: description"
  tools=$(fm "$f" tools)
  case $n in
    coder|qa)
      assert_eq yes "$([ -n "$tools" ] && echo yes || echo no)" "$n: explicit tools"
      assert_eq no "$(printf '%s' "$tools" | grep -qE 'mcp__|Atlassian|Claude_Docs' && echo yes || echo no)" "$n: no MCP tools" ;;
    *) assert_eq "" "$tools" "$n: inherits all tools" ;;
  esac
done
assert_eq 12 "$(ls "$REPO"/agents/*.md | wc -l | tr -d ' ')" "no unexpected agent files"

# every skill: frontmatter name = folder, description present
for d in "$REPO"/skills/*/; do
  n=$(basename "$d"); [ "$n" = _shared ] && continue
  f="$d/SKILL.md"
  assert_eq "$n" "$(fm "$f" name)" "skill $n: name"
  assert_eq yes "$([ -n "$(fm "$f" description)" ] && echo yes || echo no)" "skill $n: description"
done
# the design: 4 flows (5 commands) + 11 DevOps-only skill set skills
for n in validate-tiket develop-tiket rilis-tiket branch-manager audit-issue inventory-check write-runbook write-playbook lint-playbook playbook-check apply-staging verify-idempotent request-approval finalize-runbook verify-live read-logs; do
  assert_eq yes "$([ -f "$REPO/skills/$n/SKILL.md" ] && echo yes || echo no)" "skills/$n exists"
done

# every shared-doc / script / skill reference must resolve inside the repo
files=$(ls "$REPO"/agents/*.md "$REPO"/skills/*/*.md 2>/dev/null)
for r in $(cat $files | grep -oE '_devops-workflow-shared/[A-Za-z0-9_-]+\.md' | sort -u); do
  assert_eq yes "$([ -f "$REPO/skills/_shared/${r#*/}" ] && echo yes || echo no)" "ref $r exists"
done
for r in $(cat $files | grep -oE 'AGENT_WORKFLOW_DIR/(bin|templates)/[A-Za-z0-9_.-]+' | sort -u); do
  assert_eq yes "$([ -f "$REPO/${r#AGENT_WORKFLOW_DIR/}" ] && echo yes || echo no)" "ref $r exists"
done
for r in $(cat $files | grep -oE '~/\.claude/skills/[a-z-]+/SKILL\.md' | sort -u); do
  n=${r#\~/.claude/skills/}; n=${n%/SKILL.md}
  assert_eq yes "$([ -f "$REPO/skills/$n/SKILL.md" ] && echo yes || echo no)" "ref $r exists"
done
for r in $(cat $files | grep -oE '~/\.claude/agents/[a-z-]+\.md' | sort -u); do
  assert_eq yes "$([ -f "$REPO/agents/${r##*/}" ] && echo yes || echo no)" "ref $r exists"
done
# brace refs: ~/.claude/skills/{a,b}/SKILL.md and ~/.claude/agents/{a,b}.md
for n in $(cat $files | grep -oE '~/\.claude/skills/\{[a-z,-]+\}' | sed 's/.*{//; s/}//' | tr , '\n' | sort -u); do
  assert_eq yes "$([ -f "$REPO/skills/$n/SKILL.md" ] && echo yes || echo no)" "brace ref skills/$n exists"
done
for n in $(cat $files | grep -oE '~/\.claude/agents/\{[a-z,-]+\}' | sed 's/.*{//; s/}//' | tr , '\n' | sort -u); do
  assert_eq yes "$([ -f "$REPO/agents/$n.md" ] && echo yes || echo no)" "brace ref agents/$n exists"
done
for d in rules infra credentials docs-platform release report-format; do
  assert_eq yes "$([ -f "$REPO/skills/_shared/$d.md" ] && echo yes || echo no)" "_shared/$d.md exists"
done
assert_eq "" "$(grep -l '_agent-workflow-shared' $files)" "no references to the mobile shared folder"
# public repo: no user paths or private words (extra words: gitignored .private-denylist, one per line)
assert_eq "" "$(grep -lE '/Users/|@gmail' $files "$REPO"/templates/* 2>/dev/null)" "no private identifiers"
if [ -f "$REPO/.private-denylist" ]; then
  assert_eq "" "$(git -C "$REPO" grep -lwFf <(grep -v '^[[:space:]]*$' "$REPO/.private-denylist") -- . ':!.private-denylist' 2>/dev/null)" "no words from .private-denylist in tracked files"
fi
exit $((FAILS>0))
