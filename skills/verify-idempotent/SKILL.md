---
name: verify-idempotent
description: Skill set DevOps (QA) - jalankan playbook kedua kali ke staging dan pastikan tidak ada perubahan (changed=0 di semua host). Dipakai /develop-tiket setelah /apply-staging. Use when asked to verify idempotency of an Ansible playbook; kata kunci - idempoten, run kedua, changed=0.
argument-hint: KODE-TIKET <playbook>
---
Run kedua (`$ARGUMENTS`) dengan kunci staging yang masih dipegang dari `/apply-staging`.

## Langkah
1. Pastikan kunci staging masih milikmu (`lock.sh who staging:<repo>/<inv>` = owner-mu); bukan → ambil lagi dan ulang `/apply-staging` (staging mungkin sudah diubah agen lain).
2. `ANSIBLE_FORCE_COLOR=0 ansible-playbook -i <inventory staging> --vault-id <id staging>@<file> <playbook> 2>&1 | tee "${TMPDIR:-/tmp}/qa/<KODE>/apply-2.log"`
3. `"$AGENT_WORKFLOW_DIR/bin/recap-check.sh" --idempotent "${TMPDIR:-/tmp}/qa/<KODE>/apply-2.log"`:
   - exit 0 → TC idempotensi **Lulus**.
   - exit 1 → **Gagal**: daftar task yang `changed` di run 2 (cari `changed:` di log) — temuan wajib untuk Coder (biasanya `command`/`shell` tanpa `creates`/`changed_when`, template dengan nilai berubah tiap run, atau restart langsung).
4. Lepas kunci (kecuali SPV meminta `--uat`: SPV yang mengambil slot `human-<KODE>` setelah kamu lepas).
5. Tambahkan hasil ke `report.md`, lapor ke SPV: path laporan + ringkasan run 1/run 2/verifikasi.
