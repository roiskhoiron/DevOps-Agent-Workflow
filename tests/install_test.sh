#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
H=$(mktemp -d); trap 'rm -rf "$H"' EXIT
mkdir -p "$H/.claude"
echo '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"rtk hook claude"}]}]}}' > "$H/.claude/settings.json"

assert_exit 0 "install run 1" -- bash "$REPO/install.sh" --home "$H"
assert_exit 0 "install run 2 (idempotent)" -- bash "$REPO/install.sh" --home "$H"
S="$H/.claude/settings.json"
assert_eq yes "$([ -L "$H/.claude/skills/develop-tiket" ] && echo yes || echo no)" "flow skill symlink"
assert_eq yes "$([ -L "$H/.claude/skills/write-runbook" ] && echo yes || echo no)" "skill set symlink"
assert_eq yes "$([ -L "$H/.claude/skills/_devops-workflow-shared" ] && echo yes || echo no)" "shared symlink"
assert_eq "$REPO/skills/_shared" "$(readlink "$H/.claude/skills/_devops-workflow-shared")" "shared -> repo"
assert_eq no "$([ -e "$H/.claude/skills/_shared" ] && echo yes || echo no)" "_shared not linked by own name"
assert_eq yes "$([ -L "$H/.claude/agents/spv.md" ] && echo yes || echo no)" "agent symlink"
assert_eq 1 "$(jq '[.hooks.PreToolUse[]|select(.hooks[0].command|test("guard.sh"))]|length' "$S")" "guard hook once"
assert_eq 1 "$(jq '[.hooks.PreToolUse[]|select(.hooks[0].command=="rtk hook claude")]|length' "$S")" "other hook preserved"
assert_eq "\"$REPO/hooks/guard.sh\"" "$(jq -r '.hooks.PreToolUse[]|select(.hooks[0].command|test("guard.sh"))|.hooks[0].command' "$S")" "guard path quoted, from repo"
assert_eq 'Bash|Edit|Write|MultiEdit|NotebookEdit|mcp__claude_ai_Atlassian__.*' "$(jq -r '.hooks.PreToolUse[]|select(.hooks[0].command|test("guard.sh"))|.matcher' "$S")" "guard matcher"
assert_eq yes "$([ -f "$S.bak-devops-workflow" ] && echo yes || echo no)" "backup made"
assert_eq 0 "$(jq '[.hooks.PreToolUse[]|select(.hooks[0].command|test("guard.sh"))]|length' "$S.bak-devops-workflow")" "second install keeps the original backup"
assert_eq 1 "$(grep -c '^# DevOps agent workflow' "$H/.claude/CLAUDE.md")" "global CLAUDE.md section appended once"
assert_eq yes "$([ -d "$H/.agent-workflow/logs" ] && echo yes || echo no)" "logs dir created"

# another role workflow (mobile) already installed: same command names -> conflict unless --force
H2="$H/h2"; M="$H/mobile"; mkdir -p "$H2/.claude/skills" "$M/skills/develop-tiket" "$M/hooks"
ln -s "$M/skills/develop-tiket" "$H2/.claude/skills/develop-tiket"
jq -n --arg c "\"$M/hooks/guard.sh\"" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[{type:"command",command:$c}]}]}}' > "$H2/.claude/settings.json"
assert_exit 3 "conflict with another workflow" -- bash "$REPO/install.sh" --home "$H2"
assert_eq "$M/skills/develop-tiket" "$(readlink "$H2/.claude/skills/develop-tiket")" "conflict: nothing replaced"
assert_exit 0 "--force replaces" -- bash "$REPO/install.sh" --home "$H2" --force
assert_eq "$REPO/skills/develop-tiket" "$(readlink "$H2/.claude/skills/develop-tiket")" "--force: link points to this repo"
assert_eq 1 "$(jq '[.hooks.PreToolUse[]|select(.hooks[0].command|test("guard.sh"))]|length' "$H2/.claude/settings.json")" "--force: one guard hook"
assert_eq "\"$REPO/hooks/guard.sh\"" "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$H2/.claude/settings.json")" "--force: guard replaced by this repo's"
assert_exit 2 "unknown option" -- bash "$REPO/install.sh" --nope

# repo path with a space: hook command runs through a shell
R="$H/my repo"; mkdir -p "$R"; cp -R "$REPO/install.sh" "$REPO/hooks" "$REPO/skills" "$REPO/agents" "$REPO/templates" "$REPO/launchd" "$R/"
H3="$H/h3"; mkdir -p "$H3"
assert_exit 0 "install from path with space" -- bash "$R/install.sh" --home "$H3"
c=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$H3/.claude/settings.json")
assert_eq 0 "$(echo '{"tool_name":"Read"}' | sh -c "$c" >/dev/null 2>&1; echo $?)" "space path: hook command runs via shell"
exit $((FAILS>0))
