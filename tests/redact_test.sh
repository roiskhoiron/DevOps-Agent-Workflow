#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
R="$REPO/bin/redact.sh"
in='TASK [Template db config] ****
--- before: /etc/app/db.conf
+++ after: /etc/app/db.conf
-db_password = lama123
+db_password = baru456
+DB_HOST = db-stg-1
  "api_key": "abc",
  token: xyz
vault_db_root: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          6638643965376366
          3437346562373266
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAA
-----END OPENSSH PRIVATE KEY-----
ok: [web-stg-1] => (item=None) => {"censored": "the output has been hidden due to the fact that no_log: true was specified"}
changed: [web-stg-1]'
out=$(printf '%s\n' "$in" | "$R" 2>"$(mktemp)")
for s in lama123 baru456 abc xyz 6638643965376366 b3BlbnNzaC1rZXk 'item=None'; do
  assert_eq no "$(printf '%s' "$out" | grep -qF -- "$s" && echo yes || echo no)" "secret '$s' removed"
done
for s in 'TASK [Template db config]' '+DB_HOST = db-stg-1' 'changed: [web-stg-1]' '--- before: /etc/app/db.conf'; do
  assert_eq yes "$(printf '%s' "$out" | grep -qF -- "$s" && echo yes || echo no)" "kept: $s"
done
assert_eq yes "$(printf '%s' "$out" | grep -qF '[disensor oleh redact.sh]' && echo yes || echo no)" "placeholder"
assert_eq "12 baris disensor" "$(printf '%s\n' "$in" | "$R" 2>&1 >/dev/null)" "count on stderr"
assert_exit 2 "usage" -- "$R" file.txt
exit $((FAILS>0))
