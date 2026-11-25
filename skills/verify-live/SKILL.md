---
name: verify-live
description: Skill set DevOps - pemeriksaan baca-saja di production setelah manusia atau pipeline menerapkan rilis - langkah Verifikasi runbook, fakta host dengan modul baca, cek HTTP/DNS/TLS, monitoring. Tidak mengubah apa pun. Dipakai /branch-manager sebelum tag. Use after a production deploy to verify it read-only; kata kunci - verifikasi production, verify live, cek setelah deploy.
argument-hint: vX.Y.Z
---
Verifikasi production untuk rilis (`$ARGUMENTS`) **setelah** user memastikan penerapan selesai. Semua baca saja.

Baca dulu: `~/.claude/skills/_devops-workflow-shared/infra.md` (Production: hanya baca), runbook-runbook rilis, memory project → Sumber log & monitoring.

## Langkah
1. Daftar cek dari bagian **Verifikasi** dan **Titik henti** tiap runbook rilis.
2. Jalankan yang aman dan baca saja:
   - Fakta host: `ansible <grup> -i <inventory production> -m service_facts|package_facts|stat|setup` (guard mengizinkan hanya modul baca).
   - Layanan dari luar: `curl -sS -o /dev/null -w '%{http_code} %{time_total}\n' <url>`, `dig +short <nama>`, `openssl s_client -connect <host>:443 -servername <nama> </dev/null 2>/dev/null | openssl x509 -noout -dates`.
   - Monitoring/log dari memory project (`/read-logs`) di jendela sejak penerapan.
   Cek yang butuh perintah tulis/restart atau `ssh` → **tidak dijalankan**; tulis "perlu dicek manusia".
3. Simpan ke `${TMPDIR:-/tmp}/rilis/vX.Y.Z-verify.log`, saring `redact.sh`.
4. Hasil: tabel cek → host/URL → Lulus/Gagal/Tidak bisa dicek + bukti. Semua wajib Lulus → `/tag-release`. Ada Gagal → **tidak ada tag**; lapor + langkah rollback dari runbook; keputusan rollback milik manusia.
