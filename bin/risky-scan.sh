#!/usr/bin/env bash
# Usage: risky-scan.sh <base> <head> [pathspec...]
# Lists added lines in YAML/Jinja/shell changes of <base>...<head> that touch a "stop and ask" area
# (rules.md → Selalu berhenti dan tanya). TSV: file:line <TAB> kategori <TAB> line
#   hapus-data  : state absent, rm -r, DROP/TRUNCATE, *_db/volume removal
#   restart     : state restarted/reloaded/stopped, systemctl/service restart|stop|reload, reboot, shutdown
#   akses       : firewall (ufw, iptables, firewalld, nftables, security groups), users/groups/keys, sudoers, sshd, permissions 0777
# Exit 0 nothing found, 1 findings (SPV asks the user before /apply-staging), 2 usage or bad ref.
[ $# -ge 2 ] || { echo "usage: $0 <base> <head> [pathspec...]" >&2; exit 2; }
base=$1 head=$2; shift 2
for r in "$base" "$head"; do git rev-parse --verify -q "$r^{commit}" >/dev/null || { echo "ref tidak ada: $r" >&2; exit 2; }; done
[ $# -gt 0 ] || set -- '*.yml' '*.yaml' '*.j2' '*.sh' '*.cfg' '*.conf'
git diff -U0 --no-color "$base...$head" -- "$@" | awk '
  /^\+\+\+ / { f = substr($0, 7); next }
  /^@@/ { split($3, a, ","); ln = substr(a[1], 2) + 0; next }
  /^\+/ {
    l = substr($0, 2); t = tolower(l); k = ""
    if (t ~ /state:[[:space:]]*["'\'']?absent|state=absent|rm -r|rm -fr|drop (table|database|schema)|truncate |(mysql_db|postgresql_db|mongodb_user|docker_volume|lvol|filesystem):/) k = "hapus-data"
    else if (t ~ /state:[[:space:]]*["'\'']?(restarted|reloaded|stopped)|state=(restarted|reloaded|stopped)|systemctl (restart|stop|reload)|service [^ ]+ (restart|stop)|(^|[^a-z_])reboot:|shutdown /) k = "restart"
    else if (t ~ /(^|[^a-z_])(ufw|iptables|firewalld|nftables|ec2_security_group|security_group|authorized_key|user|group|seboolean|selinux|pamd):|sudoers|sshd_config|mode:[[:space:]]*["'\'']?0?777/) k = "akses"
    if (k != "") { printf "%s:%d\t%s\t%s\n", f, ln, k, l; found = 1 }
    ln++
  }
  END { exit found ? 1 : 0 }
'
