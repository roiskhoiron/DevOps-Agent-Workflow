#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
S="$REPO/bin/risky-scan.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$T" || exit 1
git init -q . && git config user.email t@t && git config user.name t
mkdir -p roles/web/tasks
printf -- '- name: Install nginx\n  ansible.builtin.apt: {name: nginx}\n' > roles/web/tasks/main.yml
git add -A && git commit -q -m base && git tag base
printf -- '- name: Add motd\n  ansible.builtin.copy: {dest: /etc/motd, content: hi}\n' >> roles/web/tasks/main.yml
git commit -qam safe && git tag safe
cat >> roles/web/tasks/main.yml <<'Y'
- name: Remove old site
  ansible.builtin.file:
    path: /var/www/old
    state: absent
- name: Restart nginx
  ansible.builtin.service: {name: nginx, state: restarted}
- name: Open port
  community.general.ufw: {rule: allow, port: "443"}
- name: Deploy key
  ansible.posix.authorized_key: {user: deploy, key: "{{ k }}"}
Y
echo 'echo hi' > notes.txt
git add -A && git commit -qm risky

assert_exit 0 "safe change" -- "$S" base safe
out=$("$S" safe HEAD); rc=$?
assert_eq 1 "$rc" "risky change exit 1"
assert_eq yes "$(echo "$out" | grep -q $'^roles/web/tasks/main.yml:[0-9]*\thapus-data\t' && echo yes || echo no)" "state absent = hapus-data"
assert_eq yes "$(echo "$out" | grep -q $'\trestart\t.*restarted' && echo yes || echo no)" "restarted = restart"
assert_eq 2 "$(echo "$out" | grep -c $'\takses\t')" "ufw + authorized_key = akses"
line=$(echo "$out" | grep hapus-data | cut -f1 | cut -d: -f2)
assert_eq "absent" "$(sed -n "${line}p" roles/web/tasks/main.yml | grep -o absent)" "line number points at the change"
assert_eq no "$(echo "$out" | grep -q notes.txt && echo yes || echo no)" "non-YAML ignored by default"
assert_exit 2 "bad ref" -- "$S" nope HEAD
assert_exit 2 "usage" -- "$S" base
exit $((FAILS>0))
