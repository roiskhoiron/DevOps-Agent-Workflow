---
name: playbook-check
description: Skill set DevOps - jalankan check mode dengan diff ke inventory staging (dengan kunci staging) untuk melihat perubahan yang akan terjadi tanpa menerapkannya, lalu saring rahasianya. Dipakai /develop-tiket (Coder) dan /branch-manager (cek staging di sha-rilis). Use when asked for a dry run, check mode, or diff of an Ansible playbook on staging; kata kunci - check mode, dry run, diff playbook.
argument-hint: KODE-TIKET <playbook>
---
Check mode untuk (`$ARGUMENTS`) ke **staging saja**. Production diblokir guard.

Baca dulu: `~/.agent-workflow/devops/skills/_shared/infra.md` (Host staging, Log run), `credentials.md`.

## Langkah
1. Kunci staging (owner `<KODE>-<peran><n>`; rilis: `rilis-vX.Y.Z-qa1`):
   `AGENT_LOCK_PID=$PPID "$AGENT_WORKFLOW_DIR/bin/lock.sh" acquire staging:<repo>/<inventory staging> <owner>` — exit 1 → antre (tanya SPV bila lama).
2. Panggilan terpisah:
   `ANSIBLE_FORCE_COLOR=0 ansible-playbook -i <inventory staging> --vault-id <id staging>@<file> --check --diff <playbook> 2>&1 | tee "${TMPDIR:-/tmp}/qa/<KODE>/check.log"`
3. `"$AGENT_WORKFLOW_DIR/bin/recap-check.sh" "${TMPDIR:-/tmp}/qa/<KODE>/check.log"` — failed/unreachable → perbaiki atau lapor (task yang bergantung pada task sebelumnya bisa gagal di check mode: tandai `check_mode`-aware di playbook atau jelaskan di laporan).
4. `"$AGENT_WORKFLOW_DIR/bin/redact.sh" < check.log > check.safe.log`. Hanya versi `.safe` yang dikutip ke PR/MR/laporan.
5. Lepas kunci (panggilan terpisah, `release`).
6. Ringkas: per host `changed`/`ok`, file/layanan yang akan berubah, apakah cocok dengan langkah runbook. Cek rilis: `changed` harus 0; selisih = drift.
