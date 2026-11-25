---
name: write-playbook
description: Skill set DevOps (Coder) - tulis playbook dan role Ansible yang mengikuti runbook langkah demi langkah, idempoten, aman untuk rahasia. Dipakai /develop-tiket langkah 6 setelah runbook dicocokkan. Use when asked to write or change an Ansible playbook or role for a ticket; kata kunci - tulis playbook, buat role.
argument-hint: KODE-TIKET
---
Tulis playbook/role untuk tiket (`$ARGUMENTS`) mengikuti runbook yang sudah di-commit.

Baca dulu: `~/.claude/skills/_devops-workflow-shared/rules.md`, `infra.md`, `credentials.md`, runbook tiket.

## Aturan
- **Satu langkah runbook = satu task (atau block) bernama persis sama.** Task baru yang belum ada di runbook → perbarui runbook dulu (commit terpisah), baru task-nya.
- Ikuti struktur project (role vs playbook, `group_vars`, penamaan); modul FQCN (`ansible.builtin.copy`).
- **Idempoten:** utamakan modul deklaratif. `command`/`shell` hanya bila tidak ada modul, wajib `creates`/`removes` atau `changed_when`/`failed_when` yang jujur. Restart layanan lewat handler (`notify`), bukan task `state: restarted` langsung, kecuali runbook memintanya.
- **Rahasia:** variabel dari Vault staging (`encrypt_string --vault-id staging@...`), task yang menyentuh rahasia `no_log: true`. Nilai production → placeholder + catatan di runbook (Production → rahasia yang diisi manusia).
- Hak akses file eksplisit (`mode`, `owner`, `group`); tidak `0777`.
- Perubahan inventory production (host baru, variabel) boleh di repo (lewat PR), tapi tidak pernah dijalankan.
- Role dengan `molecule/`: perbarui scenario bila perilaku berubah.
- Commit kecil menyebut KODE, push rutin `git push origin <branch tiket>`.

## Selesai bila
`python3 "$AGENT_WORKFLOW_DIR/bin/runbook-check.py" docs/runbooks/<nama>.md <playbook> <role>...` exit 0, lalu lanjut `/lint-playbook`.
