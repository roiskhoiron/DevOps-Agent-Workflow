# Alat (tools)

## Skrip di `bin/`
Agen memanggilnya sebagai `$AGENT_WORKFLOW_DIR/bin/<skrip>`. Kamu juga boleh menjalankannya manual.

| Skrip | Gunanya | Contoh |
| --- | --- | --- |
| `lock.sh` | Kunci host staging / checkout supaya satu benda dipakai satu agen; kunci proses yang mati otomatis bebas | `AGENT_LOCK_PID=$PPID bin/lock.sh acquire staging:infra/inventories/staging OPS-12-qa1` |
| `runbook-check.py` | Cek runbook punya lima bagian dan tiap task ↔ langkah runbook cocok | `python3 bin/runbook-check.py docs/runbooks/web.md site.yml roles/web` |
| `recap-check.sh` | Ringkas PLAY RECAP per host; `--idempotent` mewajibkan `changed=0` | `bin/recap-check.sh --idempotent /tmp/qa/OPS-12/apply-2.log` |
| `redact.sh` | Saring keluaran ansible (password, token, `$ANSIBLE_VAULT`, kunci privat, `no_log`) sebelum masuk dokumen | `bin/redact.sh < check.log > check.safe.log` |
| `risky-scan.sh` | Tandai baris yang menghapus data, me-restart layanan, atau mengubah firewall/akses di diff | `bin/risky-scan.sh upstream/develop HEAD` |
| `release-trace.sh` | Lacak tiap commit `primary..protected` ke PR dan tiket Jira (TSV); exit 3 = hotfix belum di-back-merge | `bin/release-trace.sh upstream/main upstream/develop OPS` |
| `audit-mode.sh` | Nyalakan/matikan mode hanya-baca `/audit-issue` | `AGENT_LOCK_PID=$PPID bin/audit-mode.sh status` |
| `housekeeping.sh` | Bersihkan sisa uji tiap jam: folder kerja agen lama, `~/.ansible/tmp`, log run lama, container Molecule, cache | otomatis (launchd / cron) |

## Alat Ansible yang dipakai
| Kebutuhan | Perintah | Butuh kunci staging |
| --- | --- | --- |
| Gaya dan praktik buruk | `ansible-lint` | tidak |
| Sintaks | `ansible-playbook --syntax-check` | tidak |
| Role terisolasi | `molecule test` | tidak |
| Perubahan yang akan terjadi | `ansible-playbook -i <staging> --check --diff` | ya |
| Terapkan ke staging | `ansible-playbook -i <staging>` (dua kali) | ya |
| Inventory | `ansible-inventory --list` / `--graph` | tidak |
| Fakta host (juga production, baca saja) | `ansible -m setup` / `service_facts` / `package_facts` / `stat` / `ping` | tidak |

**Alat lain selain Ansible?** Kerangka (skill flow, tim, guard, kunci, dokumen) tetap; yang diganti padanannya: `/write-playbook`, `/lint-playbook`, `/playbook-check`, `/apply-staging`, `/verify-idempotent`, bagian ansible di `hooks/guard.sh`, dan `recap-check.sh`. Contoh Terraform: `terraform validate`/`tflint` ↔ lint, `terraform plan` ↔ check mode, `apply` ke workspace staging ↔ apply staging, `plan` kedua tanpa perubahan ↔ idempotensi.

## MCP dan konektor
| Konektor | Dipakai untuk |
| --- | --- |
| **Atlassian** (Jira) | baca tiket, komentar, transisi (guard membatasi transisi) |
| **Claude Docs** (opsional) | hanya bila memory project memilih Claude Docs sebagai platform laporan; runbook tetap di repo |

## Pembersihan otomatis
`housekeeping.sh` jalan tiap jam (macOS: launchd `com.agentworkflow.devops.housekeeping`; Linux: cron yang disarankan installer). Harian setelah 03:00: folder kerja `/tmp/{qa,validate,audit}` > 7 hari, `~/.ansible/tmp` > 2 hari, `~/.agent-workflow/runs` > 30 hari. Mingguan (Minggu): container Molecule > 24 jam, image docker menggantung, cache Molecule/ansible-compat/galaxy > 14 hari. Container tidak dibersihkan saat ada kunci staging aktif atau Molecule/playbook sedang jalan. Log: `~/.agent-workflow/logs/housekeeping.log`.

---
[← kembali ke README](../README.md)
