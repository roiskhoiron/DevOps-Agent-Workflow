#!/usr/bin/env bash
# guard.sh: ticket platforms (GitHub Projects, GitLab board, labels). Done / closing is for humans only.
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
G="$REPO/hooks/guard.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export AGENT_WORKFLOW_STATE="$T/st"; mkdir -p "$T/st"
W="$T/infra"; git init -q "$W"
run() { printf '%s' "$1" | "$G" 2>"$T/err" >/dev/null; echo $?; }
check() { assert_eq "$1" "$(run "$(jq -cn --arg c "$2" --arg d "$W" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')")" "[$1] $2"; }
acheck() { assert_eq "$1" "$(AGENT_AUDIT=1 run "$(jq -cn --arg c "$2" --arg d "$W" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')")" "[$1] audit: $2"; }
msg() { grep -q -- "$1" "$T/err"; assert_eq 0 $? "  pesan: $1"; }

# before setup: status changes are refused, everything else works
check 2 'gh project item-edit --id I1 --project-id PVT_a --field-id F1 --single-select-option-id o2'; msg 'Setup status'
check 2 'glab issue update 12 -R g/infra --label status::in-progress'; msg 'Setup status'
check 0 'gh issue view 12 -R org/infra --comments'
check 0 'gh issue comment 12 -R org/infra --body-file /tmp/k.md'
check 0 'glab issue note 12 -R g/infra -m halo'
check 0 'glab issue update 12 -R g/infra --label bug'

cat > "$T/st/ticket-transitions.json" <<'J'
{"github:PVT_a":{"field":"F1","allow":["o1","o2","o3"],"names":{"o1":"Todo","o2":"In Progress","o3":"Ready To Review"}},
 "gitlab:g/infra":{"label_prefix":"status::","allow":["status::todo","status::in-progress","status::ready-to-review"]},
 "github-labels:org/app":{"label_prefix":"status:","allow":["status:todo","status:in-progress","status:ready-to-review"]}}
J
# GitHub Projects
check 0 'gh project item-edit --id I1 --project-id PVT_a --field-id F1 --single-select-option-id o3'
check 2 'gh project item-edit --id I1 --project-id PVT_a --field-id F1 --single-select-option-id o4'; msg 'hanya oleh manusia'
check 2 'gh project item-edit --id I1 --project-id=PVT_b --field-id F1 --single-select-option-id o1'; msg 'Setup status'
check 2 'gh project item-edit --id I1 --project-id PVT_a --field-id F1 --clear'
check 0 'gh project item-edit --id I1 --project-id PVT_a --field-id F9 --text "catatan"'
check 0 'gh project item-add 7 --owner org --url https://github.com/org/infra/issues/12'
check 0 'gh project item-list 7 --owner org --format json'
check 2 'gh project item-archive 7 --owner org --id I1'
check 2 'gh issue close 12 -R org/infra'
check 2 'gh issue delete 12 -R org/infra --yes'
check 2 "gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: {}) { clientMutationId } }'"
check 2 "gh api graphql -f query='mutation { closeIssue(input:{issueId:\"x\"}) { clientMutationId } }'"
check 2 'gh api -X PATCH repos/org/infra/issues/12 -f state=closed'
check 0 'gh api repos/org/infra/issues/12/comments'
# GitLab board / label mode
check 0 'glab issue update 12 -R g/infra --label status::ready-to-review --unlabel status::in-progress'
check 2 'glab issue update 12 -R g/infra --label status::done'; msg 'hanya oleh manusia'
check 2 'glab issue update 12 -R g/infra --label bug,status::done'
check 2 'glab issue close 12 -R g/infra'
check 2 'glab api -X PUT projects/1/issues/12 -f state_event=close'
check 0 'gh issue edit 3 -R org/app --add-label status:in-progress --remove-label status:todo'
check 2 'gh issue edit 3 -R org/app --add-label=status:done'
check 0 'gh issue edit 3 -R org/app --add-label infra'
# auto-closing keywords in PR/MR
check 2 'gh pr create --draft --title "INFRA-12 nginx" --body "Closes #12"'; msg 'Refs #<n>'
check 2 'glab mr create --title x --description "fixes org/infra#12"'
check 0 'gh pr create --draft --title "INFRA-12 nginx" --body "Refs #12"'
printf 'Ringkasan\n\nResolves #12\n' > "$W/body.md"; printf 'Ringkasan\n\nRefs #12\n' > "$W/ok.md"
check 2 'gh pr edit 5 --body-file body.md'
check 0 'gh pr edit 5 --body-file ok.md'
check 0 'gh pr ready 5'
# audit: tickets are read only
acheck 0 'gh issue view 12 -R org/infra'
acheck 0 'gh project item-list 7 --owner org'
acheck 2 'gh issue comment 12 -R org/infra --body x'
acheck 2 'gh issue create -R org/infra --title x'
acheck 2 'gh project item-edit --id I1 --project-id PVT_a --field-id F1 --single-select-option-id o2'
acheck 2 'glab issue note 12 -m x'
acheck 0 'glab issue list -R g/infra'
exit $((FAILS>0))
