#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
C="$REPO/bin/runbook-check.py"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/roles/web/tasks" "$T/roles/web/handlers"
cat > "$T/site.yml" <<'Y'
- name: Web servers
  hosts: web
  become: true
  vars:
    db_password: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      6162
  pre_tasks:
    - name: Update apt cache
      ansible.builtin.apt: {update_cache: true}
  roles: [web]
Y
cat > "$T/roles/web/tasks/main.yml" <<'Y'
- name: Install nginx
  ansible.builtin.apt: {name: nginx}
- name: Configure nginx
  block:
    - name: Template site config
      ansible.builtin.template: {src: site.j2, dest: /etc/nginx/sites-enabled/site}
  rescue:
    - name: Show config error
      ansible.builtin.debug: {msg: gagal}
Y
cat > "$T/roles/web/handlers/main.yml" <<'Y'
- name: Reload nginx
  ansible.builtin.service: {name: nginx, state: reloaded}
Y
cat > "$T/rb.md" <<'M'
# Runbook: nginx web
## Tujuan
Pasang nginx.
## Host terdampak
Grup `web` (staging: web-stg-1).
## Langkah
1. `Update apt cache`
2. `Install nginx` lalu
   `Configure nginx` dengan `Template site config`; bila gagal `Show config error`.
3. `Reload nginx` (handler)
4. Cek dashboard monitoring tidak merah (manual)
## Verifikasi
curl -I http://web-stg-1
## Rollback
apt remove nginx
M
out=$(python3 "$C" "$T/rb.md" "$T/site.yml" "$T/roles/web"); rc=$?
assert_eq 0 "$rc" "runbook matches playbook + role"
assert_eq "" "$out" "no findings"

sed -i.bak '/## Rollback/,$d; s/^3\. .*$/3. `Restart nginx`/' "$T/rb.md"
out=$(python3 "$C" "$T/rb.md" "$T/site.yml" "$T/roles/web"); rc=$?
assert_eq 1 "$rc" "findings exit 1"
assert_eq yes "$(echo "$out" | grep -qx $'MISSING_SECTION\tRollback' && echo yes || echo no)" "missing Rollback"
assert_eq yes "$(echo "$out" | grep -q $'^STEP_NO_TASK\t3\t' && echo yes || echo no)" "step 3 names no task"
assert_eq yes "$(echo "$out" | grep -qx $'TASK_NO_STEP\tReload nginx' && echo yes || echo no)" "handler without step"
printf -- '- ansible.builtin.ping:\n' > "$T/roles/web/tasks/extra.yml"
out=$(python3 "$C" "$T/rb.md" "$T/roles/web")
assert_eq yes "$(echo "$out" | grep -q '^TASK_NO_NAME' && echo yes || echo no)" "unnamed task"
assert_exit 2 "usage" -- python3 "$C" "$T/rb.md"
assert_exit 2 "missing file" -- python3 "$C" "$T/none.md" "$T/site.yml"
exit $((FAILS>0))
