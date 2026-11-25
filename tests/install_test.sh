#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
H=$(mktemp -d); trap 'rm -rf "$H"' EXIT
I="$REPO/install.sh"
yes_() { [ "$1" ] && echo yes || echo no; }
mkdir -p "$H/g/.claude"
echo '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"rtk hook claude"}]}]}}' > "$H/g/.claude/settings.json"
printf '# Catatanku\nisi lama\n' > "$H/g/.claude/CLAUDE.md"

# --- default (no flags, not a terminal) = Claude Code, global: same as before ---
assert_exit 0 "default install" -- bash "$I" --home "$H/g"
assert_exit 0 "default install again (idempotent)" -- bash "$I" --home "$H/g"
C="$H/g/.claude"
assert_eq "$REPO" "$(readlink "$H/g/.agent-workflow/devops")" "neutral path -> repo"
assert_eq "$REPO/skills/develop-tiket" "$(readlink "$C/skills/develop-tiket")" "claude: flow skill"
assert_eq yes "$(yes_ "$([ -L "$C/skills/write-runbook" ] && echo 1)")" "claude: skill set"
assert_eq no "$(yes_ "$([ -e "$C/skills/_shared" ] || [ -e "$C/skills/_devops-workflow-shared" ] && echo 1)")" "claude: _shared not installed as a skill"
assert_eq "$REPO/agents/spv.md" "$(readlink "$C/agents/spv.md")" "claude: role link"
S="$C/settings.json"
assert_eq 1 "$(jq '[.hooks.PreToolUse[]|select(.hooks[0].command|test("guard.sh"))]|length' "$S")" "claude: guard hook once"
assert_eq 1 "$(jq '[.hooks.PreToolUse[]|select(.hooks[0].command=="rtk hook claude")]|length' "$S")" "claude: other hook kept"
assert_eq 'Bash|Edit|Write|MultiEdit|NotebookEdit|mcp__claude_ai_Atlassian__.*' "$(jq -r '.hooks.PreToolUse[]|select(.hooks[0].command|test("guard.sh"))|.matcher' "$S")" "claude: matcher"
assert_eq 0 "$(jq '[.hooks.PreToolUse[]|select(.hooks[0].command|test("guard.sh"))]|length' "$S.bak-devops-workflow")" "claude: original settings backed up"
assert_eq 1 "$(grep -c 'devops-agent-workflow:start' "$C/CLAUDE.md")" "claude: instructions block once"
assert_eq yes "$(yes_ "$(grep -q 'isi lama' "$C/CLAUDE.md" && echo 1)")" "claude: existing instructions kept"
assert_eq no "$(yes_ "$([ -e "$H/g/.agents" ] && echo 1)")" "claude only: no .agents"

# --- every other agent, global ---
assert_exit 0 "all agents global" -- bash "$I" --home "$H/g" --agent all --yes
assert_exit 0 "all agents global again" -- bash "$I" --home "$H/g" --agent codex,gemini,cursor,copilot,opencode --yes
assert_eq "$REPO/skills/verify-live" "$(readlink "$H/g/.agents/skills/verify-live")" "shared .agents/skills"
assert_eq 16 "$(ls "$H/g/.agents/skills" | wc -l | tr -d ' ')" "16 skills, no duplicates"
assert_eq spv "$(python3 -c 'import sys,tomllib;print(tomllib.load(open(sys.argv[1],"rb"))["name"])' "$H/g/.codex/agents/spv.toml" 2>/dev/null || grep -oE '^name = "[a-z]+"' "$H/g/.codex/agents/spv.toml" | cut -d'"' -f2)" "codex: TOML role"
assert_eq yes "$(yes_ "$(grep -q '^developer_instructions' "$H/g/.codex/agents/qa.toml" && echo 1)")" "codex: developer_instructions"
for f in .gemini/agents/coder.md .cursor/agents/coder.md .copilot/agents/coder.agent.md .config/opencode/agents/coder.md; do
  assert_eq yes "$(yes_ "$(python3 -c 'import sys,yaml;d=yaml.safe_load(open(sys.argv[1]).read().split("---")[1]);assert d["description"]' "$H/g/$f" 2>/dev/null && echo 1)")" "role $f: valid frontmatter"
  assert_eq no "$(yes_ "$(grep -qE '^model: (opus|sonnet|haiku)' "$H/g/$f" && echo 1)")" "role $f: no Claude model names"
done
assert_eq "subagent" "$(grep -oE '^mode: [a-z]+' "$H/g/.config/opencode/agents/qa.md" | cut -d' ' -f2)" "opencode: mode subagent"
assert_eq 1 "$(jq '[.hooks.PreToolUse[]|select(.matcher=="Bash")]|length' "$H/g/.codex/hooks.json")" "codex: PreToolUse Bash once"
assert_eq 1 "$(jq '[.hooks.BeforeTool[]|select(.matcher=="run_shell_command")]|length' "$H/g/.gemini/settings.json")" "gemini: BeforeTool once"
assert_eq "1 1" "$(jq -r '"\(.version) \(.hooks.beforeShellExecution|length)"' "$H/g/.cursor/hooks.json")" "cursor: hooks.json v1, once"
assert_eq preToolUse "$(jq -r '.hooks|keys[0]' "$H/g/.copilot/hooks/devops-guard.json")" "copilot: hook file"
for f in .codex/AGENTS.md .gemini/GEMINI.md .copilot/copilot-instructions.md .config/opencode/AGENTS.md; do
  assert_eq 1 "$(grep -c 'devops-agent-workflow:start' "$H/g/$f")" "instructions $f once"
done
assert_eq no "$(yes_ "$([ -e "$H/g/.config/opencode/opencode.json" ] && echo 1)")" "opencode: config untouched (no hook)"
out=$(bash "$I" --home "$H/g" --agent opencode,cursor --yes)
assert_eq yes "$(yes_ "$(echo "$out" | grep -q 'opencode: TIDAK punya hook' && echo 1)")" "opencode: warns guard not enforced"
assert_eq yes "$(yes_ "$(echo "$out" | grep -q 'cursor: aturan global' && echo 1)")" "cursor: warns about UI rules"
# installed hook commands actually run the guard
c=$(jq -r '.hooks.beforeShellExecution[0].command' "$H/g/.cursor/hooks.json")
assert_eq 2 "$(echo '{"command":"git push upstream main","cwd":"/tmp"}' | sh -c "$c" >/dev/null 2>&1; echo $?)" "cursor hook command blocks"
c=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$H/g/.codex/hooks.json")
assert_eq 0 "$(echo '{"tool_name":"Bash","tool_input":{"command":"ls"},"cwd":"/tmp"}' | sh -c "$c" >/dev/null 2>&1; echo $?)" "codex hook command allows"

# --- project scope ---
P="$H/proj"; git init -q "$P"; echo '# Repo infra' > "$P/AGENTS.md"
assert_exit 0 "project scope, several agents" -- bash "$I" --home "$H/p" --scope project --project "$P" --agent claude,codex,copilot,gemini,cursor,opencode --yes
assert_exit 0 "project scope again" -- bash "$I" --home "$H/p" --scope project --project "$P" --agent all --yes
assert_eq "$REPO/skills/develop-tiket" "$(readlink "$P/.claude/skills/develop-tiket")" "project: .claude/skills"
assert_eq "$REPO/skills/develop-tiket" "$(readlink "$P/.agents/skills/develop-tiket")" "project: .agents/skills"
assert_eq yes "$(yes_ "$([ -f "$P/.github/agents/spv.agent.md" ] && [ -f "$P/.opencode/agents/spv.md" ] && [ -f "$P/.codex/agents/spv.toml" ] && echo 1)")" "project: role files"
assert_eq 1 "$(grep -c 'devops-agent-workflow:start' "$P/AGENTS.md")" "project: AGENTS.md block once (shared by codex/cursor/copilot/opencode)"
assert_eq yes "$(yes_ "$(grep -q '# Repo infra' "$P/AGENTS.md" && echo 1)")" "project: AGENTS.md content kept"
assert_eq 1 "$(grep -c 'devops-agent-workflow:start' "$P/CLAUDE.md")" "project: CLAUDE.md"
assert_eq 1 "$(grep -c 'devops-agent-workflow:start' "$P/GEMINI.md")" "project: GEMINI.md"
assert_eq yes "$(yes_ "$([ -f "$P/.claude/settings.json" ] && [ -f "$P/.codex/hooks.json" ] && [ -f "$P/.github/hooks/devops-guard.json" ] && [ -f "$P/.cursor/hooks.json" ] && echo 1)")" "project: hook files"
assert_eq no "$(yes_ "$([ -e "$H/p/.claude" ] || [ -e "$H/p/.agents" ] && echo 1)")" "project: nothing tool-specific in home"
assert_eq "$REPO" "$(readlink "$H/p/.agent-workflow/devops")" "project: neutral path still in home"
# instructions block is replaced, not duplicated, when the template changes
sed -i.bak 's/<!-- devops-agent-workflow:start -->/&\nBARIS LAMA/' "$P/AGENTS.md"
bash "$I" --home "$H/p" --scope project --project "$P" --agent codex --yes >/dev/null
assert_eq no "$(yes_ "$(grep -q 'BARIS LAMA' "$P/AGENTS.md" && echo 1)")" "project: old block replaced on reinstall"

# --- conflicts: another workflow, or a user's own file with the same name ---
H2="$H/h2"; M="$H/mobile"; mkdir -p "$H2/.claude/skills" "$M/skills/develop-tiket" "$M/hooks"
ln -s "$M/skills/develop-tiket" "$H2/.claude/skills/develop-tiket"
jq -n --arg c "\"$M/hooks/guard.sh\"" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[{type:"command",command:$c}]}]}}' > "$H2/.claude/settings.json"
assert_exit 3 "conflict with another workflow" -- bash "$I" --home "$H2"
assert_eq "$M/skills/develop-tiket" "$(readlink "$H2/.claude/skills/develop-tiket")" "conflict: nothing replaced"
assert_exit 0 "--force replaces" -- bash "$I" --home "$H2" --force
assert_eq "$REPO/skills/develop-tiket" "$(readlink "$H2/.claude/skills/develop-tiket")" "--force: link to this repo"
assert_eq "\"$REPO/hooks/guard.sh\"" "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$H2/.claude/settings.json")" "--force: guard replaced"
H3="$H/h3"; mkdir -p "$H3/.copilot/agents"; echo '---\nname: spv\n---\nmilikku' > "$H3/.copilot/agents/spv.agent.md"
assert_exit 3 "user's own role file = conflict" -- bash "$I" --home "$H3" --agent copilot --yes
assert_eq yes "$(yes_ "$(grep -q milikku "$H3/.copilot/agents/spv.agent.md" && echo 1)")" "user's role file untouched"

# --- bad usage ---
assert_exit 2 "unknown agent" -- bash "$I" --home "$H/x" --agent vim --yes
assert_exit 2 "bad scope" -- bash "$I" --home "$H/x" --scope team --yes
assert_exit 2 "project dir missing" -- bash "$I" --home "$H/x" --scope project --project "$H/none" --yes
assert_exit 2 "unknown option" -- bash "$I" --nope

# --- repo path with a space ---
R="$H/my repo"; mkdir -p "$R"; cp -R "$REPO/install.sh" "$REPO/hooks" "$REPO/skills" "$REPO/agents" "$REPO/templates" "$REPO/launchd" "$R/"
assert_exit 0 "install from path with space" -- bash "$R/install.sh" --home "$H/h4" --agent claude,cursor --yes
c=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$H/h4/.claude/settings.json")
assert_eq 0 "$(echo '{"tool_name":"Read"}' | sh -c "$c" >/dev/null 2>&1; echo $?)" "space path: claude hook runs via shell"
c=$(jq -r '.hooks.beforeShellExecution[0].command' "$H/h4/.cursor/hooks.json")
assert_eq 0 "$(echo '{"command":"ls","cwd":"/tmp"}' | sh -c "$c" >/dev/null 2>&1; echo $?)" "space path: cursor hook runs via shell"
exit $((FAILS>0))
