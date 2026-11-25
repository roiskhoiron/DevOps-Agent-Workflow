# Documentation first

Setiap perubahan infrastruktur dimulai dari dokumen, bukan dari playbook. Urutannya tetap: **runbook ditulis, playbook mengikuti runbook, lalu keduanya diuji dan direview bersama.**

## Tiga aturan
1. **Tidak ada playbook tanpa runbook.** Reviewer menolak perubahan playbook yang tidak punya runbook di PR/MR yang sama.
2. **Setiap task punya padanan di runbook.** Task yang tidak tertulis di runbook, atau langkah runbook tanpa task, adalah temuan review.
3. **Runbook memuat lima hal:** tujuan, host yang terdampak, langkah, cara verifikasi, dan cara rollback.

Aturan 2 dan 3 diperiksa mesin oleh `bin/runbook-check.py`:
```bash
python3 bin/runbook-check.py docs/runbooks/nginx.md playbooks/web.yml roles/web
# exit 0 = cocok; exit 1 = temuan (MISSING_SECTION / TASK_NO_STEP / STEP_NO_TASK / TASK_NO_NAME)
```

## Cara menghubungkan langkah dan task
Di bagian **Langkah**, tiap langkah menyebut nama task persis dalam backtick; langkah yang dikerjakan orang ditandai `(manual)`:
```markdown
## Langkah
1. `Install nginx`
2. `Template site config` lalu handler `Reload nginx`
3. Cek dashboard tidak merah sebelum batch berikutnya (manual)
```
```yaml
- name: Install nginx
  ansible.builtin.apt: {name: nginx, state: present}
- name: Template site config
  ansible.builtin.template: {src: site.j2, dest: /etc/nginx/sites-enabled/site}
  notify: Reload nginx
```

## Di mana dokumen disimpan
Folder `docs/` di repo infrastruktur, Markdown, kecuali memory project mencatat platform lain. Runbook **selalu** di repo: harus bisa dibaca saat sistem dokumentasi lain tidak bisa diakses.

| Dokumen | Lokasi | Ditulis kapan |
| --- | --- | --- |
| Runbook | `docs/runbooks/<nama>.md` | Sebelum playbook |
| Catatan keputusan | `docs/adr/` | Saat ada keputusan arsitektur baru |
| Laporan validasi | `docs/tickets/<KODE>/validasi.md` | Di `/validate-tiket` |
| Hasil check mode dan staging | `docs/tickets/<KODE>/uji.md` | Di `/develop-tiket` |
| Laporan audit | `docs/audit/` | Di `/audit-issue` (bila kamu setuju) |
| Perubahan rilis | `docs/rilis/vX.Y.Z.md` | Di `/branch-manager --rilis` |

Kerangka: [templates/runbook.md](../templates/runbook.md), [templates/adr.md](../templates/adr.md). Keluaran check mode disaring `bin/redact.sh` sebelum ditulis ke dokumen: baris yang memuat nilai rahasia dibuang, karena dokumen di repo bisa dibaca semua anggota tim. Detail: [skills/_shared/docs-platform.md](../skills/_shared/docs-platform.md).

---
[← kembali ke README](../README.md)
