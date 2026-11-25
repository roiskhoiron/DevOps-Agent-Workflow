# Tim agen

Tim dan nama sama dengan workflow Mobile; tugasnya disesuaikan untuk infrastruktur.

| Agen | Nama | Model | Tugas | Tidak boleh |
| --- | --- | --- | --- | --- |
| SPV | Pak Darmo | opus | bagi tugas dan kunci staging, cocokkan runbook dengan AC, minta persetujuan pemilik DevOps, putuskan selesai | menulis runbook/playbook |
| Planner | Pak Sastro | `claude-fable-5-2` | rencana + test case mode tim, analisis eskalasi | menulis repo, tiket, staging |
| Validator | Kang Jajang | opus | `/validate-tiket` | menulis runbook/playbook |
| HoE | Pak Harjo | opus | `/validate-tiket --tim`: repo vs dokumen vs inventory, dampak host | menulis apa pun |
| PjM | Bu Sumi | sonnet | `/validate-tiket --tim`: tiket/PR terkait, kunci staging, risiko bentrok | menulis apa pun |
| Spesialis eskalasi | Eyang Wiryo | `claude-fable-5-2`, on-demand | `/validate-tiket --tim` saat pemicu (ambigu, high-risk, konflik) | menulis, memutuskan |
| Coder | Maman, Ujang, Tarjo, Asep, Parmin | sonnet | runbook dulu, lalu playbook/role, lint, check mode | menulis tiket, apply staging, production |
| Reviewer | Mbah Karto | opus | runbook ↔ playbook, keamanan + idempotensi, logika vs AC; review di PR/MR | review pekerjaan sendiri |
| QA | Paijo, Euis, Ningsih | sonnet | apply staging, Verifikasi runbook, run kedua (idempotensi), rollback bila diminta | menulis tiket, push, production |
| Release | Sutini | haiku | Draft PR/MR, PR/MR siap, komentar + geser tiket, merge PR tiket, PR rilis, `/verify-live`, tag | Done, production, merge PR rilis |
| Auditor | Cecep, Dadang, Sarip | opus | `/audit-issue`: repo, log, fakta host | menulis apa pun |
| Analis | Bu Lastri | opus | `/audit-issue`: lampiran | menulis apa pun |

Di mode tim tiap agen adalah **teammate** Claude Code (*agent teams*), tampil sebagai panel split di workspace yang sama dengan label seperti `@Maman-Programmer1`. Model tiap peran diubah di `agents/<peran>.md`.

**Tool selain Claude Code:** installer membuat file peran dalam format tool itu (Codex `.toml`, Copilot `.agent.md`, dst.) dari `agents/*.md`. Kolom **Model** adalah default untuk Claude; tool lain memakai model yang kamu pilih di tool itu (pakai model terkuat untuk SPV, Reviewer, dan Planner). Tool yang tidak bisa menjalankan subagen bekerja dalam **mode solo**: satu sesi menjalankan peran bergantian, dan laporan mencatat bahwa review tidak independen.

> **Syarat mode tim:** jalankan `claude --teammate-mode auto`, atau sekali di `/config` → **Teammate mode** → `auto`.

**Satu-satunya pekerjaan yang selalu menunggu manusia:** persetujuan pemilik DevOps per tiket, merge PR rilis, dan penerapan ke production.

---
[← kembali ke README](../README.md)
