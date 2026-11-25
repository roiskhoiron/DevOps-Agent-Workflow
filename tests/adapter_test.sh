#!/usr/bin/env bash
# hooks/adapter.sh: other agents' hook payloads -> guard.sh -> the agent's own block format
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
A="$REPO/hooks/adapter.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export AGENT_WORKFLOW_STATE="$T/st"; mkdir -p "$T/st"
W="$T/infra"; git init -q "$W"; mkdir -p "$W/inventories/production"; git -C "$W" remote add origin "$T/o.git"
run() { printf '%s' "$2" | "$A" "$1" >"$T/out" 2>"$T/err"; echo $?; }

# Gemini CLI: BeforeTool, run_shell_command
assert_eq 2 "$(run gemini "$(jq -cn --arg d "$W" '{hook_event_name:"BeforeTool",tool_name:"run_shell_command",tool_input:{command:"ansible-playbook -i inventories/production site.yml"},cwd:$d}')")" "gemini: production playbook blocked"
assert_eq yes "$(grep -q 'DIBLOKIR' "$T/err" && echo yes || echo no)" "gemini: reason on stderr"
assert_eq 0 "$(run gemini "$(jq -cn --arg d "$W" '{tool_name:"run_shell_command",tool_input:{command:"git status"},cwd:$d}')")" "gemini: allowed"
assert_eq 2 "$(run gemini "$(jq -cn --arg d "$W" '{tool_name:"run_shell_command",tool_input:{command:"git push upstream main",dir_path:$d},cwd:"/"}')")" "gemini: dir_path used as cwd"
assert_eq 0 "$(run gemini '{"tool_name":"read_file","tool_input":{"file_path":"x"}}')" "gemini: other tools pass"

# Cursor: beforeShellExecution
assert_eq 2 "$(run cursor "$(jq -cn --arg d "$W" '{hook_event_name:"beforeShellExecution",command:"gh workflow run deploy.yml",cwd:$d}')")" "cursor: pipeline trigger blocked"
assert_eq deny "$(jq -r .permission "$T/out")" "cursor: {permission: deny}"
assert_eq yes "$(jq -r .agent_message "$T/out" | grep -q 'memicu pipeline' && echo yes || echo no)" "cursor: agent_message has the reason"
assert_eq 0 "$(run cursor "$(jq -cn --arg d "$W" '{command:"ls -la",cwd:$d}')")" "cursor: allowed"
assert_eq "" "$(cat "$T/out")" "cursor: allowed = no output"
assert_eq 2 "$(run cursor "$(jq -cn --arg d "$W" '{command:"git push upstream main",workspace_roots:[$d]}')")" "cursor: workspace_roots as cwd"

# GitHub Copilot: preToolUse (camelCase), toolArgs as JSON string or object
assert_eq 2 "$(run copilot "$(jq -cn --arg d "$W" '{toolName:"bash",toolArgs:({command:"gh issue close 3"}|tojson),cwd:$d}')")" "copilot: close issue blocked (toolArgs string)"
assert_eq deny "$(jq -r .permissionDecision "$T/out")" "copilot: {permissionDecision: deny}"
assert_eq 2 "$(run copilot "$(jq -cn --arg d "$W" '{toolName:"bash",toolArgs:{command:"ansible-vault decrypt x.yml"},cwd:$d}')")" "copilot: vault decrypt blocked (toolArgs object)"
assert_eq 0 "$(run copilot "$(jq -cn --arg d "$W" '{toolName:"bash",toolArgs:{command:"ansible-lint site.yml"},cwd:$d}')")" "copilot: allowed"
assert_eq 2 "$(run copilot "$(jq -cn --arg d "$W" '{tool_name:"Bash",tool_input:{command:"git push upstream main"},cwd:$d}')")" "copilot: PascalCase payload too"
assert_eq 0 "$(run copilot '{"toolName":"view","toolArgs":{"path":"a"}}')" "copilot: other tools pass"

# bad input fails closed
assert_eq 2 "$(run cursor 'bukan json')" "unreadable payload blocked"
assert_eq 2 "$(run vim '{}')" "unknown tool = usage error"
exit $((FAILS>0))
