---
name: read-logs
description: Skill set DevOps - baca log layanan dan log hasil run sebelumnya (run ansible lama, job pipeline) di sekitar waktu kejadian, baca saja, keluaran disaring rahasianya. Dipakai /audit-issue, /validate-tiket (bug), dan /verify-live. Use when asked to read service logs, previous ansible run logs, or pipeline logs; kata kunci - baca log, log layanan, log run.
argument-hint: <layanan|KODE> [sejak] [sampai]
---
Baca log untuk (`$ARGUMENTS`). **Baca saja**; tidak me-restart, tidak mengubah level log, tidak menghapus log.

Baca dulu: `~/.claude/skills/_devops-workflow-shared/infra.md`, memory project → Sumber log & monitoring.

## Sumber, berurutan
1. **Log run agen sebelumnya:** `${AGENT_WORKFLOW_STATE:-$HOME/.agent-workflow}/runs/<KODE>-*/` dan `${TMPDIR:-/tmp}/qa/<KODE>/` (`recap-check.sh` untuk ringkasan per host).
2. **Log job pipeline** (bila penerapan lewat pipeline): `gh run list` / `gh run view <id> --log`, `glab ci list` / `glab ci view` — baca saja; tidak pernah `rerun`/`retry` (guard).
3. **Monitoring/log terpusat** (Grafana/Loki, ELK, CloudWatch, dll.) lewat alat/konektor yang tersedia di sesi dan lokasi dari memory project.
4. **Host staging** (hanya saat memegang kunci staging, atau slot audit tanpa perubahan): `ansible <host> -i <inventory staging> -m stat` untuk file log; isi log lewat `ssh <host> 'journalctl -u <unit> --since ... --no-pager | tail -n 500'` hanya untuk host staging.
5. **Host production:** tidak `ssh`. Hanya sumber 2–3. Tidak tersedia → "tidak bisa diperiksa" + alasan.

## Keluaran
Potongan log relevan (waktu, host, baris) disaring `redact.sh`, ke file kerja pemanggil (`${TMPDIR:-/tmp}/audit/<slug>/` atau `${TMPDIR:-/tmp}/validate/<KODE>/`), plus ringkasan: pola error, waktu pertama/terakhir, host terdampak, keterkaitan dengan run/rilis terakhir.
