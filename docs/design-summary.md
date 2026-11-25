# Rancangan (ringkasan)

Sumber: dokumen "Draft: Agent Workflow Delivery DevOps" (Claude Docs). Repo ini mengimplementasikannya di atas kerangka workflow Mobile (`mobiledev-agent-workflow`).

## Yang sama dengan Mobile
Alur kanban, tim agen dan modelnya, mode kerja dan pagar, worktree Orca bertingkat (primary, domain, tiket, coder), gerbang validasi dan Acuan tiket di awal `/develop-tiket`, `/audit-issue` beserta mode hanya-baca.

## Yang berbeda
| Bagian | Mobile | DevOps (di repo ini) |
| --- | --- | --- |
| Urutan kerja | rencana, lalu kode | runbook, lalu playbook (`/write-runbook`, `runbook-check.py`) |
| Tempat uji | device fisik, emulator, simulator | host staging dan container uji (`lock.sh`, Molecule) |
| Alat uji | Maestro, Schemathesis, Pact | `ansible-lint`, syntax check, check mode dengan diff, Molecule |
| Bukti di laporan | screenshot bertanda | keluaran check mode, diff, ringkasan per host (`recap-check.sh`, `redact.sh`) |
| Uji khas | — | idempotensi: run kedua `changed=0` (`/verify-idempotent`) |
| Hasil build | Firebase/TestFlight | tidak ada build; playbook yang lolos di staging |
| Rahasia | akun uji di `local.properties` | Ansible Vault staging; production tidak pernah dibuka agen |
| Sumber daya bersama | device, dikunci | host staging, dikunci (`staging:<repo>/<inventory>`) |
| Berhenti dan bertanya | upload build prod | hapus data, restart layanan, firewall/akses (`risky-scan.sh`) |
| Selalu diblokir, tambahan | — | playbook ke production, Vault production, memicu pipeline (guard) |
| Persetujuan manusia | saat merge | setiap tiket, sebelum PR/MR siap (`/request-approval`) |
| Flag `--uat` | kamu menguji build di HP fisik | pemilik DevOps memeriksa hasil di staging |
| Pembersihan berkala | DerivedData, Gradle, APK/IPA | container uji, cache koleksi, log run lama |

## Keputusan implementasi (di luar draft)
- **Validasi menerbitkan ke repo** lewat branch tiket di fork, supaya komentar tiket punya link; branch yang hanya berisi `docs/tickets/<KODE>/` tidak dihitung sebagai jejak pengerjaan.
- **Laporan rilis masuk repo setelah tag**, karena isi `<protected>` tidak boleh berubah setelah `<sha-rilis>` dicatat; selama proses isinya ada di PR rilis.
- **Cek staging di `<sha-rilis>`** menggantikan "regresi penuh di beta": check mode tiap playbook rilis, harapannya `changed=0`.
- **Ad-hoc modul baca ke production diizinkan** untuk `/verify-live` dan `/read-logs`; selain itu production tertutup.
- **Tag setelah `/verify-live` lulus**, mengikuti urutan skill set di draft (verify-live sebelum tag-release).
- **Satu komputer = satu workflow role**: nama perintah sama dengan Mobile, installer mendeteksi bentrok.

- **Platform tiket tidak punya default.** Draft tidak menunjuk Jira; memory project mulai dari **none**, agen bertanya di awal, dan menyarankan GitHub Projects / GitLab issue board bila user ragu. Semua skill memakai operasi generik (`ticket-platform.md`), guard menjaga Done untuk semua platform.

- **Tidak terikat Claude Code.** `install.sh` memasang ke Claude Code, Codex CLI, Gemini CLI, Cursor, GitHub Copilot, atau OpenCode, dengan scope global atau project. Skill dan peran merujuk lokasi netral `~/.agent-workflow/devops`; guard memakai adaptor per tool; tool tanpa subagen berjalan dalam mode solo.

## Yang masih terbuka (dari draft)
- [ ] Apakah tim DevOps memang memakai Ansible, atau alat lain? (padanan Terraform: [alat](alat.md))
- [ ] Bagaimana inventory dipisah antara staging dan production? (diisi lewat Setup inventory)
- [ ] Apakah rahasia sudah dikelola dengan Ansible Vault atau pengelola rahasia lain?
- [ ] Siapa atau apa yang menjalankan playbook ke production: orang, atau pipeline?
- [ ] Apakah staging cukup mirip production untuk uji idempotensi yang bermakna?
- [ ] Siapa pemilik DevOps yang menyetujui setiap tiket?

---
[← kembali ke README](../README.md)
