#!/bin/bash
# Usage: adapter.sh <gemini|cursor|copilot>   (stdin = the tool's hook JSON)
# Translates another coding agent's pre-tool hook payload into the Claude Code shape that guard.sh
# reads ({tool_name, tool_input.command, cwd, session_id}), runs guard.sh, and answers in the
# tool's own blocking format. Claude Code and Codex send the Claude shape already and call guard.sh
# directly. Allowed -> exit 0, no output. Blocked -> reason on stderr, exit 2 (+ JSON where the tool
# expects it).
#   gemini : BeforeTool, tool_name run_shell_command, tool_input.command, tool_input.dir_path, cwd
#   cursor : beforeShellExecution, {command, cwd, workspace_roots}; deny = {"permission":"deny",...}
#   copilot: preToolUse (camelCase), {toolName: bash, toolArgs: <object or JSON string>, cwd};
#            deny = {"permissionDecision":"deny","permissionDecisionReason":...}
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
G="$(cd "$(dirname "$0")" && pwd -P)/guard.sh"
tool=${1:-}
JQ=$(command -v jq) || { echo "DIBLOKIR oleh guard: jq tidak ditemukan." >&2; exit 2; }
in=$(cat)
case $tool in
  gemini) f='{tool_name: (if .tool_name == "run_shell_command" then "Bash" else .tool_name end),
              tool_input: (.tool_input // {}),
              cwd: (if (.tool_input.dir_path // "") | startswith("/") then .tool_input.dir_path else .cwd end),
              session_id}';;
  cursor) f='{tool_name: "Bash", tool_input: {command: (.command // .tool_input.command // "")},
              cwd: (.cwd // .workspace_roots[0] // null), session_id: .conversation_id}';;
  copilot) f='((.toolArgs // .tool_input // {}) | if type == "string" then (fromjson? // {command: .}) else . end) as $a
              | {tool_name: (((.toolName // .tool_name // "") | ascii_downcase) as $t
                             | if $t == "bash" or $t == "powershell" then "Bash" else (.toolName // .tool_name) end),
                 tool_input: $a, cwd, session_id: (.sessionId // .session_id)}';;
  *) echo "usage: $0 <gemini|cursor|copilot>" >&2; exit 2;;
esac
norm=$(printf '%s' "$in" | "$JQ" -c "$f" 2>/dev/null) || { echo "DIBLOKIR oleh guard: payload hook $tool tidak bisa dibaca." >&2; exit 2; }
msg=$(printf '%s' "$norm" | "$G" 2>&1 >/dev/null); rc=$?
[ $rc -eq 2 ] || exit 0
case $tool in
  cursor) "$JQ" -cn --arg m "$msg" '{permission: "deny", user_message: $m, agent_message: $m}';;
  copilot) "$JQ" -cn --arg m "$msg" '{permissionDecision: "deny", permissionDecisionReason: $m}';;
esac
echo "$msg" >&2
exit 2
