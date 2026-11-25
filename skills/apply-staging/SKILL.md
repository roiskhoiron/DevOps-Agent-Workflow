---
name: apply-staging
description: Skill set DevOps (QA) - terapkan playbook ke inventory staging dengan kunci staging (run pertama), cek PLAY RECAP, lalu jalankan langkah Verifikasi dari runbook. Tidak pernah ke production. Dipakai /develop-tiket langkah 10 dan /rilis-tiket. Use when asked to apply/run a playbook on staging and verify it; kata kunci - apply staging, jalankan playbook staging.
argument-hint: KODE-TIKET <playbook>
---
Terapkan (`$ARGUMENTS`) ke **staging**. Hanya setelah review bersih dan area berisiko dijawab user (`/develop-tiket` langkah 7–8).

Baca dulu: `~/.agent-workflow/devops/skills/_shared/infra.md`, `credentials.md`, runbook tiket.

## Langkah
1. Kunci staging (owner `<KODE>-qa<n>`), satu kunci untuk seluruh rangkaian apply 1 → Verifikasi → `/verify-idempotent`.
2. Run 1 (panggilan terpisah):
   `ANSIBLE_FORCE_COLOR=0 ansible-playbook -i <inventory staging> --vault-id <id staging>@<file> <playbook> 2>&1 | tee "${TMPDIR:-/tmp}/qa/<KODE>/apply-1.log"`
   `--batch`: dari checkout domain (branch batch); `--separate`: dari worktree tiket.
3. `"$AGENT_WORKFLOW_DIR/bin/recap-check.sh" "${TMPDIR:-/tmp}/qa/<KODE>/apply-1.log"`: exit 1 → TC Gagal, catat host + task gagal (dari log), lanjut ke langkah 6 tanpa run 2; exit 2 (run terhenti) → catat, tanya SPV.
4. **Verifikasi:** jalankan tiap langkah bagian Verifikasi runbook ke host staging (modul baca, `curl`, `dig`, `ssh` baca saja ke host staging yang dikunci). Simpan ke `verify.log`. Tiap langkah → Lulus/Gagal + bukti.
5. **Rollback** (hanya bila ada TC rollback di rencana): jalankan langkah Rollback runbook di staging, cek keadaan kembali, lalu apply ulang supaya staging sesuai branch. Dicatat terpisah.
6. Tetap pegang kunci untuk `/verify-idempotent` bila run 1 lulus; selain itu lepas kunci.
7. Laporan `${TMPDIR:-/tmp}/qa/<KODE>/report.md` (bagian Staging + Verifikasi dari `report-format.md` → Laporan uji), keluaran disaring `redact.sh`. Data uji berawalan KODE dicatat.
