# Platform dokumentasi

Dokumen disimpan di folder `docs/` di repo infrastruktur, sebagai Markdown, **kecuali memory project mencatat platform lain** (mis. Claude Docs, Confluence). Di DevOps aturan ini lebih penting daripada di role lain: runbook harus tetap bisa dibaca saat sistem dokumentasi lain sedang tidak bisa diakses. Karena itu **runbook selalu di repo**, apa pun platformnya; platform lain hanya untuk laporan.

## Lokasi
| Dokumen | Lokasi default | Ditulis kapan | Oleh |
|---|---|---|---|
| Runbook | `docs/runbooks/<nama>.md` | Sebelum playbook (`/write-runbook`); bagian Production di `/finalize-runbook` | Coder; Release untuk finalisasi |
| Catatan keputusan (ADR) | `docs/adr/<nnnn>-<judul>.md` | Saat ada keputusan arsitektur baru | Coder (diusulkan di rencana) |
| Laporan validasi | `docs/tickets/<KODE>/validasi.md` | `/validate-tiket` | Validator |
| Hasil check mode dan staging | `docs/tickets/<KODE>/uji.md` | `/develop-tiket` | SPV menulis, Release push |
| Laporan audit | `docs/audit/<slug>.md` | `/audit-issue` (setelah mode audit mati, bila user setuju) | SPV audit |
| Perubahan rilis | `docs/rilis/vX.Y.Z.md` | `/branch-manager --rilis` | Release |

Folder belum ada → dibuat oleh commit pertama yang membutuhkannya (tanpa bertanya). `templates/runbook.md` dan `templates/adr.md` di repo workflow adalah kerangkanya.

## Menerbitkan laporan (platform `repo`)
Laporan butuh link untuk baris pertama komentar tiket. Di platform `repo`, link = URL file di branch fork (`origin`), mis. `https://github.com/<fork>/<repo>/blob/<branch>/docs/tickets/OPS-12/validasi.md` (GitLab: `/-/blob/`). Host dari `git remote get-url origin`.

| Laporan | Branch | Catatan |
|---|---|---|
| Validasi | branch tiket `<jenis>/<KODE>` di worktree tiket `<repo>-<nomor>` dari `<base>` (dibuat Validator bila belum ada) | Commit `docs: <KODE> laporan validasi`; push `git push -u origin <branch>`. Validasi ulang = perbarui file yang sama (delta di bagian atas). Branch yang hanya berisi `docs/tickets/<KODE>/` **bukan** jejak pengerjaan |
| Uji | branch tiket yang sama | Commit `docs: <KODE> laporan uji` sebelum PR/MR ditandai siap; ikut direview di PR/MR |
| Audit | `docs/audit-<slug>` dari `upstream/<protected>` | Hanya setelah `audit-mode.sh off` dan user bilang ya; Draft PR/MR ke `<protected>` |
| Rilis | selama proses: isi PR rilis + `${TMPDIR:-/tmp}/rilis/vX.Y.Z.md`; setelah tag: branch `docs/rilis-vX.Y.Z` dari `upstream/<protected>` + PR/MR | PR rilis tidak boleh berubah isi setelah `<sha-rilis>` dicatat, jadi dokumen rilis masuk repo sesudahnya |

Gambar/lampiran (screenshot dashboard) disimpan di folder yang sama dengan laporannya dan ditautkan relatif.

## Platform lain (dari memory project)
- **Claude Docs**: laporan dibuat dengan `mcp__claude_ai_Claude_Docs__batch` (judul sama dengan judul laporan), link dokumen di baris pertama komentar tiket. Runbook tetap di repo; dokumen Claude Docs menautkannya.
- **Lainnya** (Confluence, wiki internal): ikuti cara terbit yang dicatat di memory project; tidak ada caranya → tanya user sekali, simpan.

## Runbook
Kerangka: `$AGENT_WORKFLOW_DIR/templates/runbook.md`. Lima bagian wajib (dicek `runbook-check.py`):

| Bagian | Isi |
|---|---|
| Tujuan | apa yang berubah dan kenapa (rujuk KODE tiket, ADR bila ada) |
| Host terdampak | grup/host di staging dan production, jumlah host, layanan yang tersentuh |
| Langkah | daftar bernomor; tiap langkah menyebut nama task playbook dalam backtick, mis. ``1. `Install nginx` ``; langkah tanpa task diberi tanda `(manual)` |
| Verifikasi | perintah/cek yang membuktikan perubahan berhasil (dipakai QA di staging dan `/verify-live` di production) |
| Rollback | cara kembali ke keadaan sebelum perubahan, termasuk data yang tidak bisa dikembalikan |

Bagian **Production** (jendela perubahan, urutan host/batch, pelaksana, titik henti, rollback production) ditambahkan oleh `/finalize-runbook` saat rilis.

Tiga aturan yang menjaga urutan documentation first:
1. **Tidak ada playbook tanpa runbook.** Reviewer menolak perubahan playbook yang tidak punya runbook di PR/MR yang sama.
2. **Setiap task punya padanan di runbook.** Task yang tidak tertulis di runbook, atau langkah runbook tanpa task, adalah temuan review (`runbook-check.py`).
3. **Runbook memuat lima hal:** tujuan, host yang terdampak, langkah, cara verifikasi, dan cara rollback.

## Rahasia
Keluaran check mode dan log run disaring `redact.sh` sebelum ditulis ke dokumen: dokumen di repo bisa dibaca semua anggota tim. Nilai dari Vault, password, token, dan kunci privat tidak pernah ditulis; sebut nama variabelnya saja (mis. `vault_db_password`).
