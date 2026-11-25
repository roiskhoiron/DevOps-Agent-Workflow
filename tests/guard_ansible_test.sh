#!/usr/bin/env bash
# guard.sh: ansible, ansible-vault, pipelines. Production is never applied to; staging needs our own lock.
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
G="$REPO/hooks/guard.sh"; L="$REPO/bin/lock.sh"
T=$(mktemp -d); trap 'rm -rf "$T"; kill $SP 2>/dev/null' EXIT
export AGENT_WORKFLOW_STATE="$T/st"; mkdir -p "$T/st"
W="$T/infra"
git init -q "$W"
mkdir -p "$W/inventories/staging/group_vars/all" "$W/inventories/production/group_vars/all" "$W/inventories/other"
touch "$W/inventories/staging/hosts.yml" "$W/inventories/production/hosts.yml" "$W/site.yml"
git -C "$W" add -A && git -C "$W" -c user.name=t -c user.email=t@t commit -q -m init
git -C "$W" worktree add -q "$T/infra-12" -b feature/OPS-12

run() { printf '%s' "$1" | "$G" 2>"$T/err" >/dev/null; echo $?; }
check() { # expected command [cwd]
  assert_eq "$1" "$(run "$(jq -cn --arg c "$2" --arg d "${3:-$W}" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')")" "[$1] $2"
}
msg() { grep -q -- "$1" "$T/err"; assert_eq 0 $? "  pesan: $1"; }

# production is blocked even before the repo has an inventory list (name-based, fail-safe)
check 2 'ansible-playbook -i inventories/production/hosts.yml site.yml'; msg 'inventory production'
check 2 'ansible-playbook -i inventories/staging site.yml'; msg 'Setup inventory'
check 0 'ansible-playbook --syntax-check site.yml'

cat > "$T/st/ansible-inventories.json" <<'J'
{"infra":{"staging":["inventories/staging"],"production":["inventories/production"]}}
J
RES=staging:infra/inventories/staging

# staging: our own lock is required for any run that reaches hosts (check mode too)
check 2 'ansible-playbook -i inventories/staging site.yml'; msg 'belum kamu kunci'
check 2 'ansible-playbook -i inventories/staging/hosts.yml --check --diff site.yml'
AGENT_LOCK_PID=$$ "$L" acquire "$RES" OPS-12-qa1
check 0 'ansible-playbook -i inventories/staging site.yml'
check 0 'ansible-playbook -i inventories/staging/hosts.yml --check --diff site.yml'
check 0 'ansible-playbook --inventory=inventories/staging -l web site.yml'
check 0 'ansible-playbook -i inventories/staging site.yml' "$T/infra-12"   # worktree: same repo key
check 0 'cd inventories && ansible-playbook -i staging ../site.yml'
check 0 'ansible-playbook -vvi inventories/staging site.yml'
"$L" release "$RES" OPS-12-qa1
sleep 60 & SP=$!; disown "$SP"
AGENT_LOCK_PID=$SP "$L" acquire "$RES" OPS-99-qa1
check 2 'ansible-playbook -i inventories/staging site.yml'; msg 'sedang dikunci OPS-99-qa1'
check 0 'ansible-playbook -i inventories/staging --list-hosts site.yml'   # no connection, no lock
check 0 'ansible-playbook -i inventories/staging --syntax-check site.yml'
kill $SP; wait $SP 2>/dev/null
AGENT_LOCK_PID=$$ "$L" acquire "$RES" OPS-12-qa1

# production and anything unknown
check 2 'ansible-playbook -i inventories/production site.yml'
check 2 'ansible-playbook --inventory=inventories/production/hosts.yml site.yml'
check 2 'ansible-playbook --inventory-file inventories/production site.yml'
check 2 'ansible-playbook -i inventories/staging -i inventories/production site.yml'
check 2 'ansible-playbook -i inventories/production --check site.yml'
check 2 'ansible-playbook --syntax-check -i inventories/production site.yml'
check 2 'ansible-playbook -i /etc/ansible/hosts site.yml'; msg 'bukan inventory staging'
check 2 'ansible-playbook -i inventories/other site.yml'
check 2 'ansible-playbook -i web1.example.com,web2 site.yml'
check 0 'ansible-playbook -i localhost, -c local site.yml'
check 2 'ansible-playbook site.yml'; msg 'tanpa inventory eksplisit'
check 2 'ANSIBLE_INVENTORY=inventories/production ansible-playbook site.yml'
check 0 'ANSIBLE_INVENTORY=inventories/staging ansible-playbook site.yml'
check 0 'ansible-playbook --version'
check 2 'uv run ansible-playbook -i inventories/production site.yml'
check 2 'sudo -E ansible-playbook -i inventories/production site.yml'
check 2 'echo ok && ansible-playbook -i inventories/production site.yml'
check 2 'bash -c "ansible-playbook -i inventories/production site.yml"'
check 2 'timeout 600 /usr/local/bin/ansible-playbook -i inventories/production site.yml'
check 2 'ansible-playbook -i ../infra/inventories/production site.yml' "$T/infra-12"
check 2 'ansible-playbook -i inventories/staging -e ansible_host=10.0.0.5 site.yml'; msg 'ansible_host'
check 2 'ansible-playbook -i inventories/staging --extra-vars={"ansible_ssh_host":"db1"} site.yml'
check 0 'ansible-playbook -i inventories/staging -e app_version=1.2 site.yml'
check 2 'ansible-pull -U https://x/infra.git site.yml'
check 2 'ansible-console -i inventories/staging'

# vault: production ids/password files/files never
check 2 'ansible-playbook -i inventories/staging --vault-id prod@~/.vault_prod site.yml'; msg 'Vault production'
check 2 'ansible-playbook -i inventories/staging --vault-password-file ~/.vault_pass_production site.yml'
check 2 'ansible-playbook -i inventories/staging --vault-id=live@prompt site.yml'
check 2 'ANSIBLE_VAULT_PASSWORD_FILE=~/.vp_prod ansible-playbook -i inventories/staging site.yml'
check 0 'ansible-playbook -i inventories/staging --vault-id staging@~/.vault_staging site.yml'
check 2 'ansible-vault decrypt inventories/staging/group_vars/all/vault.yml'; msg 'ansible-vault view'
check 0 'ansible-vault view inventories/staging/group_vars/all/vault.yml'
check 2 'ansible-vault view inventories/production/group_vars/all/vault.yml'
check 2 'ansible-vault view group_vars/prod/vault.yml'
check 2 'ansible-vault edit --vault-id prod@prompt x.yml'
check 0 'ansible-vault encrypt_string --vault-id staging@~/.vs secret --name db_password'
check 2 'ansible-vault encrypt_string --vault-id production@~/.vp secret --name db_password'
check 0 'ansible-vault --help'

# ad-hoc: read-only modules may read production facts (/verify-live); anything else follows the rules
check 0 'ansible all -i inventories/production -m ping'
check 0 'ansible web -i inventories/production -m ansible.builtin.setup -a filter=ansible_distribution*'
check 0 'ansible web -i inventories/production -m service_facts'
check 2 'ansible web -i inventories/production -m shell -a uptime'
check 2 'ansible web -i inventories/production -a "systemctl restart nginx"'   # default module = command
check 0 'ansible web -i inventories/staging -m service -a "name=nginx state=started"'
"$L" release "$RES" OPS-12-qa1
check 2 'ansible web -i inventories/staging -m service -a "name=nginx state=started"'
check 0 'ansible web -i inventories/staging -m ping'
check 0 'ls ansible'
check 0 'cd ansible && ls'
check 0 'ansible --version'
check 0 'ansible-inventory -i inventories/production --list'
check 2 'ansible-inventory -i inventories/production --list --vault-id prod@~/.vp'
check 0 'ansible-galaxy collection install -r requirements.yml'
check 0 'molecule test'

# pipelines: never started by an agent
check 2 'gh workflow run deploy.yml -f env=production'; msg 'tidak memicu pipeline'
check 2 'gh run rerun 123'
check 2 'glab ci run --branch main'
check 2 'glab ci retry 77'
check 2 'gh api -X POST repos/o/r/actions/workflows/9/dispatches'
check 2 'glab api -X POST projects/1/pipeline'
check 0 'gh pr create --draft --title x'
check 0 'gh run list'
check 0 'glab ci status'

# audit mode: read only
acheck() { assert_eq "$1" "$(AGENT_AUDIT=1 run "$(jq -cn --arg c "$2" --arg d "$W" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')")" "[$1] audit: $2"; }
AGENT_LOCK_PID=$$ "$L" acquire "$RES" OPS-12-qa1
acheck 2 'ansible-playbook -i inventories/staging site.yml'
acheck 2 'ansible-playbook -i inventories/staging --check site.yml'
acheck 0 'ansible-playbook -i inventories/staging --syntax-check site.yml'
acheck 0 'ansible all -i inventories/production -m ping'
acheck 2 'ansible all -i inventories/staging -m shell -a uptime'
acheck 2 'ansible-vault view inventories/staging/group_vars/all/vault.yml'
acheck 0 'ansible-inventory -i inventories/staging --graph'
acheck 2 'molecule test'
"$L" release "$RES" OPS-12-qa1

exit $((FAILS>0))
