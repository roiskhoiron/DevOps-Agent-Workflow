# DevOps-Agent-Workflow

Tim agen Claude Code (+ Orca) untuk mengerjakan tiket Jira infrastruktur dari **Todo sampai Ready To Review**: cek tiket, tulis runbook, tulis playbook Ansible yang mengikuti runbook, uji di staging (dua kali, untuk idempotensi), minta persetujuan pemilik DevOps, lalu PR/MR. Kerangkanya sama dengan workflow Mobile (`mobiledev-agent-workflow`); dua hal membedakannya:

1. **Documentation first** — runbook ditulis lebih dulu, playbook mengikuti runbook, keduanya diuji dan direview bersama.
2. **Agen tidak pernah menerapkan perubahan ke production** — agen menyiapkan runbook dan PR rilis lalu berhenti; manusia atau pipeline yang menerapkan; agen hanya memeriksa hasilnya secara baca-saja. Guard (`hooks/guard.sh`) memaksanya.

Status: **v1 (basis kode)**, siap uji coba di tiket nyata. Ansible dipakai sebagai contoh alat; alat lain cukup mengganti skill khas DevOps ([alat](docs/alat.md)).

## Daftar isi
1. [Mulai cepat](#mulai-cepat) dan [istilah penting](#istilah-penting) (di halaman ini)
2. [Alur kerja + papan kanban](docs/alur-kerja.md): empat skill flow dan skill set-nya
3. [Documentation first](docs/documentation-first.md): runbook ↔ playbook
4. [Tim agen](docs/tim-agen.md): peran, nama, model
5. [Pagar keamanan](docs/pagar-keamanan.md): yang diblokir guard, kapan agen berhenti dan bertanya
6. [Alat (tools) + MCP](docs/alat.md): skrip `bin/`, alat Ansible, konektor, pembersihan otomatis
7. [Pasang](docs/pasang.md) dan [masalah umum](docs/masalah-umum.md)
8. [Rancangan](docs/design-summary.md): ringkasan draft, beda dengan Mobile, keputusan implementasi, pertanyaan terbuka

## Mulai cepat

| Perintah | Gunanya | Jalankan dari |
| --- | --- | --- |
| `/validate-tiket KODE... [--solo\|--tim]` | Cek tiket layak dikerjakan: bandingkan permintaan dengan dokumen infrastruktur dan inventory. Hasil: `docs/tickets/<KODE>/validasi.md` + komentar Jira | mana saja |
| `/develop-tiket KODE... [--solo\|--tim] [--batch\|--separate] [--uat]` | Runbook, playbook, lint, check mode, review, uji di staging dua kali, persetujuan pemilik DevOps, PR/MR, tiket ke Ready To Review | workspace domain |
| `/rilis-tiket KODE...` | Tindak lanjut feedback per tiket: kembalikan ke Todo, uji ulang di staging, atau audit + merge PR tiket | root project atau domain |
| `/branch-manager --rilis KODE` | Rilis per versi: tracing, cek staging di commit rilis, finalisasi runbook production, PR rilis, **berhenti**; setelah manusia/pipeline menerapkan: verifikasi baca-saja dan tag | root project atau domain |
| `/audit-issue "teks" [--solo\|--tim] [lampiran...]` | Telusuri keluhan infrastruktur yang belum jadi tiket, **hanya-baca**. Hasil: laporan + saran tiket | mana saja |

Skill khas DevOps yang juga bisa dipanggil sendiri: `/inventory-check`, `/write-runbook`, `/write-playbook`, `/lint-playbook`, `/playbook-check`, `/apply-staging`, `/verify-idempotent`, `/request-approval`, `/finalize-runbook`, `/verify-live`, `/read-logs`.

```text
/validate-tiket OPS-1234
/develop-tiket OPS-1234 OPS-1240 --tim
/develop-tiket OPS-1300 --solo --separate --uat
/audit-issue "nginx 502 di web-2 sejak tadi pagi" --solo
/rilis-tiket OPS-1234
/branch-manager --rilis OPS-1400
```

## Istilah penting

| Istilah | Penjelasan sederhana |
| --- | --- |
| **Runbook** | Panduan langkah demi langkah sebuah perubahan (`docs/runbooks/`): tujuan, host terdampak, langkah, cara verifikasi, cara rollback. Ditulis **sebelum** playbook |
| **Playbook** | Skrip Ansible yang menjalankan langkah runbook; satu langkah = satu task bernama sama |
| **Inventory staging / production** | Daftar server per lingkungan. Agen hanya boleh menerapkan ke staging |
| **Check mode** | Menjalankan playbook tanpa mengubah apa pun, hanya menampilkan apa yang *akan* berubah (`--check --diff`) |
| **Idempoten** | Dijalankan dua kali hasilnya sama; run kedua harus `changed=0` |
| **Kunci staging** | Satu host staging dipakai satu agen pada satu waktu (`bin/lock.sh`) |
| **Peta host** | Grup → host staging yang diuji → jumlah host production yang nanti terkena |
| **Pemilik DevOps** | Orang yang menyetujui setiap tiket sebelum PR/MR ditandai siap review |
| **SPV** | Agen "mandor": membagi tugas, memutuskan tiket selesai |
| **Guard** | Hook yang memblokir perintah berbahaya sebelum dijalankan |
| **Downstream / upstream** | `origin` = fork kita (boleh push branch); `upstream` = repo utama (hanya lewat PR/MR) |

## Isi repo

| Folder | Isi |
| --- | --- |
| `skills/<perintah>/SKILL.md` | Lima skill flow + sebelas skill set khas DevOps |
| `skills/_shared/` | Aturan bersama: `rules.md` (tim, guard, git, worktree), `infra.md` (staging, alat uji, production baca-saja), `docs-platform.md`, `credentials.md`, `release.md`, `report-format.md` |
| `agents/` | Peran agen (model, tugas, larangan) |
| `bin/` | Skrip pembantu (tabel di [docs/alat.md](docs/alat.md)) |
| `hooks/guard.sh` | Pagar keamanan |
| `templates/` | Kerangka runbook, ADR, dan bagian CLAUDE.md global |
| `tests/` | Tes skrip & guard: `bash tests/run.sh` (juga jalan di GitHub Actions) |
| `docs/` | Panduan untuk pemula |

## Merawat dokumen ini

README + `docs/` adalah pintu masuk pemula. **Setiap perubahan workflow atau alat wajib memperbarui README atau halaman `docs/` yang sesuai di commit yang sama.** `tests/readme_test.sh` gagal bila ada perintah, skrip `bin/`, atau MCP yang belum disebut di README maupun `docs/*.md`; `tests/agents_test.sh` gagal bila ada rujukan ke dokumen, skrip, skill, atau agen yang tidak ada.
