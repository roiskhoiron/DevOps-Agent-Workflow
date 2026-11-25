# Format laporan

Laporan diterbitkan oleh agen management sesuai `docs-platform.md` (default: Markdown di `docs/` repo infrastruktur). QA tidak menerbitkan: QA menulis `${TMPDIR:-/tmp}/qa/<KODE>/report.md` + log run lalu menyerahkan path-nya ke SPV.

Gaya: Bahasa Indonesia, singkat padat, ramah pemula. Tabel dan diagram mermaid lebih dulu daripada paragraf. Tanpa kredensial; keluaran ansible hanya versi yang sudah lewat `redact.sh`, dipotong ke bagian yang relevan (blok kode `diff`).

## Laporan validasi (`docs/tickets/<KODE>/validasi.md`)
1. **Judul** `Validasi OPS-1234 — judul singkat`, tanggal, nama user.
2. **Ringkasan**: tabel AC → status (Lulus / Tertahan / Perlu klarifikasi).
3. **Keputusan**: kalimat tebal **Layak**, **Layak dengan catatan**, atau **Tidak layak**, diagram mermaid, alasan singkat.
4. **Permintaan vs keadaan sekarang** (`/inventory-check`): tabel `Yang diminta | Inventory/variabel sekarang | Dokumen (runbook/ADR) | Cocok?`; host/grup yang disebut tiket ada atau tidak di staging dan production.
5. **Dampak**: host terdampak (staging/production, jumlah), layanan, area berisiko (hapus data, restart, firewall/akses), perkiraan ukuran (kecil/sedang/besar).
6. **Ketergantungan** (`/find-related`): tiket/PR terkait → status → dampak; kunci staging yang sedang dipegang.
7. **Temuan**: ref dokumen yang dibaca (hasil sinkron), fakta host yang dikumpulkan (modul baca), checklist tindak lanjut.
Mode tim: bagian **Teknis** (HoE, + Spesialis eskalasi bila dipanggil) dan **Ketergantungan** (PjM) menyebut agen sumbernya dan tingkat keyakinan (**pasti** / **kuat** / **dugaan**).
Validasi ulang: bagian **Delta** di atas (apa yang berubah dibanding validasi sebelumnya) + **Yang ditolak** (tiap poin: sumber komentar, golongan, saran tugas/TC).

## Laporan uji (`docs/tickets/<KODE>/uji.md`)
1. **Judul** `Uji OPS-1234 — judul singkat`, tanggal, nama user.
2. **Ringkasan**: tabel TC → AC → Lulus/Gagal/Tertahan + jenis uji (lint / syntax / molecule / check mode / apply / idempotensi / verifikasi / rollback).
3. **Keputusan**: kalimat tebal **Siap review** atau **Belum siap** + alasan.
4. **Runbook**: link `docs/runbooks/<nama>.md`, hasil `runbook-check.py` (cocok / temuan).
5. **Peta host**: grup → host staging yang diuji → jumlah host production yang akan terkena.
6. **Check mode**: ringkasan per host (`changed`/`ok`), potongan diff yang disaring.
7. **Staging**: tabel run → host → ok/changed/unreachable/failed (`recap-check.sh`); run kedua harus `changed=0` (idempotensi).
8. **Verifikasi**: tiap langkah Verifikasi runbook → hasil + bukti (keluaran disaring).
9. **Area berisiko**: temuan `risky-scan.sh` + jawaban user.
10. **Persetujuan**: pemilik DevOps, waktu, catatan (diisi setelah `/request-approval`).
11. **Temuan**: branch + commit, inventory staging + kunci yang dipakai, data uji, checklist tindak lanjut.

## Ringkasan persetujuan (`/request-approval`)
Satu komentar PR/MR + pesan chat, maksimal satu layar:
| Bagian | Isi |
|---|---|
| Apa yang berubah | 2–3 kalimat + link runbook |
| Host | Peta host (staging diuji, production nanti) |
| Bukti staging | check mode (ringkas), apply 1, apply 2 `changed=0`, verifikasi |
| Risiko | temuan `risky-scan.sh`, rollback singkat |
| Yang diminta | "Setuju" / "Tolak + alasan" dari pemilik DevOps |

## Laporan audit (`/audit-issue`)
Ditulis di `${TMPDIR:-/tmp}/audit/<slug>/laporan.md` selama audit (mode hanya-baca); masuk `docs/audit/<slug>.md` hanya bila user setuju setelah mode audit mati. Urutan:
1. **Ringkasan untuk awam** (3–5 kalimat).
2. **Permintaan asli** + daftar lampiran (terbaca / gagal + alasan).
3. **Temuan per pertanyaan**: tiap klaim dengan bukti (file:baris di ref, commit, potongan log disaring, fakta host).
4. **Perbandingan lampiran vs repo vs host** (bila ada lampiran): tabel `Lampiran | Repo | Host | Beda?`.
5. **Akar masalah** + keyakinan (**pasti** / **kuat** / **dugaan**), dampak, perkiraan ukuran perbaikan.
6. **Saran langkah berikutnya** dan **Saran tiket Jira** (tidak dibuat).
7. **Cara audit**: ref yang dibaca, host/inventory yang diperiksa, alat, hal yang tidak bisa diperiksa (termasuk: guard tidak menangkap `ssh` dan tulis lewat shell).

## Laporan rilis (`docs/rilis/vX.Y.Z.md`)
1. Diagram mermaid: branch tiket → `<protected>` → `<primary>` → production → tag.
2. Versi + ref (hash `<primary>`, `<protected>`, `<sha-rilis>`).
3. Tabel perubahan:

| KODE | Ringkasan | Runbook | PR/MR | Programmer | Status Jira |
|---|---|---|---|---|---|

4. Commit tak terlacak dan tiket belum Done: ditandai.
5. Cek staging di `<sha-rilis>`: playbook → host → changed (harus 0) → catatan drift.
6. Urutan penerapan production (dari runbook yang difinalisasi): langkah → runbook → jendela → pelaksana → titik henti → rollback.
7. Rekomendasi agen.
8. Hasil `/verify-live`, link PR rilis, tag (diisi setelah ada).

## Komentar Jira
Ditulis seperti rekan satu tim yang sopan, bisa dipahami pembaca awam (PM, QA, bisnis).
- Orang pertama **aku**, hangat dan to the point; paling banyak satu emoji.
- **Bahasa awam:** jelaskan dampaknya bagi pengguna/layanan, bukan detail teknis. Hindari istilah (playbook, inventory, idempoten, check mode); kalau terpaksa, beri arti singkat dalam kurung.
- **Sapaan:** pakai sapaan yang sudah dipakai tim untuk orang itu; belum ada contoh → **Kak <nama depan>**. Jangan menebak mas/mba dari nama.
- Baris pertama **selalu** memuat link laporan, dibungkus kalimat sapaan.
- Isi: apa yang aku cek, hasilnya, apa yang perlu dari mereka. Kabar kurang enak disampaikan jujur tapi lembut, dengan jalan keluar.

**Contoh — validasi layak dengan catatan**
```
Halo Kak Rina, aku sudah cek permintaan ini ya. Laporan lengkapnya di sini: <link validasi.md>
Permintaannya bisa mulai dikerjakan. Satu catatan: server web kedua di lingkungan uji belum ada, jadi pengujian nanti baru mencakup satu server dari dua.
Tiketnya aku pindah ke In Progress. Kalau server kedua bisa disiapkan, kabari aku ya. Terima kasih 🙏
```

**Contoh — Ready To Review**
```
Halo Mas Dimas, perubahan di tiket ini sudah siap dicek. Laporan ujinya ada di sini: <link uji.md>
Perubahannya sudah aku coba di lingkungan uji, dijalankan dua kali dan hasilnya stabil, dan sudah disetujui Kak Sari.
Langkah penerapan dan cara membatalkannya ada di panduan ini: <link runbook> · Perubahan: <link PR>
Penerapan ke server utama tetap dilakukan tim sesuai jadwal rilis. Terima kasih!
```

Kirim lewat `mcp__claude_ai_Atlassian__addCommentToJiraIssue`.
