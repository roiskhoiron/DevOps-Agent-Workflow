# Pagar keamanan

Perbedaan DevOps paling besar di antara semua role, karena yang diuji adalah server sungguhan dan kesalahannya berdampak ke semua aplikasi.

**Selalu diblokir oleh guard** (`hooks/guard.sh`, juga di mode otonom):
- `ansible-playbook` (termasuk `--check`) ke inventory **production**, ke inventory yang tidak terdaftar sebagai staging, tanpa `-i` eksplisit (kecuali `--syntax-check`), atau ke daftar host inline (selain `localhost,`), atau dengan `-e ansible_host=…` yang membelokkan host. Path/nama yang mengandung `prod`, `production`, `prd`, `live` selalu dianggap production.
- Membuka **Vault production** (`--vault-id prod@…`, file password production, `ANSIBLE_VAULT_PASSWORD_FILE`), `ansible-vault view/edit/rekey` file vault production, dan `ansible-vault decrypt` di mana pun.
- `ansible` ad-hoc ke production selain modul baca (`ping`, `setup`, `gather_facts`, `service_facts`, `package_facts`, `stat`); `ansible-pull`, `ansible-console`.
- Apply/check ke host staging **tanpa memegang kuncinya** (`staging:<repo>/<inventory>`), atau saat dikunci agen lain.
- Memicu pipeline: `gh workflow run`, `gh run rerun`, `glab ci run/retry/trigger`, API `dispatches`/`pipeline`.
- Push ke selain `origin`; force-push/hapus `main`/`master`/`develop` (tag `vX.Y.Z` eksplisit boleh ke `origin` dan `upstream`).
- `rm -r` di luar folder project (kecuali cache uji di worktree repo yang sama, isi `/tmp/qa` dan `/tmp/validate`).
- Tiket ke status di luar `ticket-transitions.json` (Done tidak pernah ada di sana), menutup issue GitHub/GitLab, label `status::done`, ubah status lewat `gh/glab api`, dan `Closes/Fixes #<n>` di PR/MR. Berlaku untuk Jira, GitHub Projects, dan GitLab board.
- Edit file di worktree primary; tab/workspace/project Orca baru; worktree di luar folder sejajar.
- Mode audit: semua penulisan ke repo, git remote, tiket, staging, Vault, Molecule.

**Tidak ditangkap guard (dijaga aturan skill):** wrapper (`make deploy`, `./deploy.sh`), `ssh` langsung, tulis lewat shell. Karena itu agen wajib memanggil `ansible-playbook` langsung dan tidak pernah `ssh` ke host production.

**Dijaga aturan skill:**
- Persetujuan pemilik DevOps setiap tiket, sebelum PR/MR ditandai siap review.
- Merge PR rilis ke `<primary>`: hanya manusia. Penerapan ke production: manusia atau pipeline.
- Tag rilis hanya setelah `/verify-live` lulus.
- Keluaran ansible disaring `redact.sh` sebelum masuk dokumen, tiket, atau PR/MR.

**Agen selalu berhenti dan bertanya** bila: perubahan menghapus data, me-restart layanan, atau mengubah firewall dan hak akses (`risky-scan.sh`); hotfix; vault password staging tidak ditemukan; staging tidak mewakili production; host staging dipakai tiket lain; dua fix hotfix bentrok.

| | Mobile | DevOps |
| --- | --- | --- |
| Berhenti dan bertanya | upload build prod | task yang menghapus data, me-restart layanan, atau mengubah firewall dan hak akses |
| Selalu diblokir, tambahan | — | playbook ke inventory production, membuka Vault production, memicu pipeline |
| Persetujuan manusia | saat merge | setiap tiket, sebelum PR/MR ditandai siap review |
| Sumber daya bersama | device, dikunci satu agen | host staging, dikunci satu agen |

---
[← kembali ke README](../README.md)
