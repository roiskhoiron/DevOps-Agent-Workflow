#!/usr/bin/env bash
# Usage: redact.sh < check-output > safe-output
# Filters ansible output (check mode, diff, run logs) before it is written to docs/, a ticket or a PR/MR.
# Dropped: lines with a secret-looking key (password, passwd, secret, token, api_key, private_key,
# access_key, credential, vault_*) with a value, $ANSIBLE_VAULT blocks, PEM private keys, and
# content hidden by no_log. Each dropped line becomes "[disensor oleh redact.sh]"; the count goes to stderr.
# Exit 0 always (it is a filter); 2 on usage (arguments given).
[ $# -eq 0 ] || { echo "usage: $0 < input > output" >&2; exit 2; }
awk '
  BEGIN { n = 0; IGNORECASE = 1 }
  function drop() { print "[disensor oleh redact.sh]"; n++ }
  # PEM private key block
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/ { pem = 1; drop(); next }
  pem { if ($0 ~ /-----END [A-Z ]*PRIVATE KEY-----/) pem = 0; n++; next }
  # inline vault: the header line and the hex lines that follow it
  /\$ANSIBLE_VAULT;/ { vault = 1; drop(); next }
  vault { if ($0 ~ /^[[:space:]]*[0-9a-fA-F]+[[:space:]]*$/) { n++; next } vault = 0 }
  tolower($0) ~ /(password|passwd|secret|token|api[_-]?key|private[_-]?key|access[_-]?key|credential|vault_[a-z0-9_]+)["'\'']?[[:space:]]*[:=]/ { drop(); next }
  tolower($0) ~ /censored|no_log: true/ { drop(); next }
  { print }
  END { print n " baris disensor" > "/dev/stderr" }
'
