---
name: write-runbook
description: Skill set DevOps (Coder) - tulis atau perbarui runbook di docs/runbooks sebelum playbook (documentation first), dengan lima bagian wajib dan langkah bernomor yang menyebut nama task. Dipakai /develop-tiket langkah 5. Use when asked to write a runbook before writing a playbook; kata kunci - tulis runbook, documentation first.
argument-hint: KODE-TIKET <nama-runbook>
---
Tulis runbook untuk tiket (`$ARGUMENTS`) **sebelum** playbook apa pun ditulis atau diubah.

Baca dulu: `~/.claude/skills/_devops-workflow-shared/docs-platform.md` (→ Runbook), kerangka `$AGENT_WORKFLOW_DIR/templates/runbook.md`.

## Langkah
1. Runbook sudah ada untuk layanan/perubahan ini (`docs/runbooks/`)? → perbarui yang itu; jangan buat duplikat. Belum → `docs/runbooks/<nama>.md` (nama huruf kecil, `-`, sesuai layanan/perubahan) dari template.
2. Isi lima bagian dari rencana, AC, dan Peta host:
   - **Tujuan**: apa yang berubah dan kenapa, rujuk KODE dan ADR.
   - **Host terdampak**: grup, host staging, jumlah host production, layanan yang tersentuh, apakah ada restart/downtime.
   - **Langkah**: daftar bernomor, urutan sama dengan playbook. Tiap langkah otomatis menyebut **nama task** yang akan ditulis, dalam backtick (``1. `Install nginx` ``); langkah tanpa task diberi `(manual)`. Nama task: kalimat perintah singkat, unik dalam playbook.
   - **Verifikasi**: perintah/cek yang bisa dijalankan QA di staging dan `/verify-live` di production (HTTP status, `service_facts`, isi file lewat `stat`/checksum, port).
   - **Rollback**: langkah kembali, termasuk yang tidak bisa dikembalikan (data terhapus) — ditulis jujur.
3. Bagian **Production** biarkan kosong dengan catatan "diisi `/finalize-runbook` saat rilis".
4. Rahasia: sebut nama variabel saja (`vault_db_password`), tidak pernah nilainya.
5. Commit `docs: <KODE> runbook <nama>` dan push ke `origin <branch tiket>`. Kirim ringkasan ke SPV (langkah + host + rollback) dan tunggu "cocok" sebelum `/write-playbook`.

## Tidak boleh
- Menulis playbook sebelum runbook di-commit dan dicocokkan SPV.
- Menyalin keluaran mentah ansible atau nilai rahasia ke runbook.
