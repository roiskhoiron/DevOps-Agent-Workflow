---
name: finalize-runbook
description: Skill set DevOps (Release) - lengkapi bagian Production runbook untuk rilis - jendela perubahan, urutan host/batch, pelaksana, titik henti, rollback production, rahasia yang diisi manusia. Dipakai /branch-manager langkah 6. Use when preparing runbooks for a production release; kata kunci - finalisasi runbook, runbook production, jendela perubahan.
argument-hint: vX.Y.Z <runbook>...
---
Lengkapi bagian **Production** tiap runbook yang tersentuh rilis (`$ARGUMENTS`). Agen menulis rencana penerapan; **manusia atau pipeline yang menjalankannya**.

Baca dulu: `~/.claude/skills/_devops-workflow-shared/docs-platform.md` (→ Runbook), `release.md` (Rilis), memory project → Pelaksana production, Pemilik DevOps.

## Isi bagian Production
| Butir | Isi |
|---|---|
| Jendela perubahan | kapan boleh diterapkan (tanya user bila belum ada kebijakan di memory) dan perkiraan durasi |
| Pelaksana | nama orang atau pipeline (job/file) dari memory project |
| Urutan host/batch | grup → batch (mis. `serial: 1` atau 25%), host kanary dulu bila ada; jumlah host dari inventory production |
| Perintah | perintah yang akan dijalankan **pelaksana** (mis. `ansible-playbook -i inventories/production --vault-id prod@prompt site.yml --limit web --diff`), ditulis sebagai teks untuk manusia — agen tidak menjalankannya |
| Titik henti | cek setelah batch pertama (dari bagian Verifikasi) yang harus lulus sebelum lanjut |
| Rollback production | langkah rollback disesuaikan production (urutan, data, waktu) |
| Rahasia | variabel Vault production yang harus diisi/diperbarui manusia sebelum penerapan (nama saja) |
| Dampak | downtime/restart yang terlihat pengguna; siapa yang perlu diberi tahu |

## Langkah
1. Runbook belum punya bagian Production → tambahkan; sudah ada → perbarui untuk versi ini.
2. Perubahan runbook = commit di branch `docs/<KODE>-runbook-production` dari `upstream/<protected>`, push ke `origin`, PR ke `<protected>`; merge setelah "ya" user (`/branch-manager` lalu mengulang tracing).
3. Ringkas urutan penerapan semua runbook rilis (tabel langkah → runbook → jendela → pelaksana → titik henti → rollback) untuk laporan dan PR rilis.

## Tidak boleh
- Menjalankan perintah production yang ditulis di runbook; membuka Vault production.
