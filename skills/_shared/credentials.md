# Kredensial dan rahasia

Isi kredensial **tidak pernah** ditulis ke dokumen (`docs/`, Claude Docs), tiket, PR/MR, commit, laporan, atau `CLAUDE.md`. Di laporan cukup sebut nama kunci/variabel (mis. `vault_db_password`, vault id `staging`).

## Yang dipakai agen
| Rahasia | Sumber | Catatan |
|---|---|---|
| Password Vault **staging** | file lokal dari memory project → Vault (mis. `~/.ansible/vault-pass-staging`), dipakai lewat `--vault-id staging@<file>` | file di luar repo, atau di repo tapi di-gitignore |
| Kunci SSH ke host staging | `~/.ssh/` + `ansible_user` dari inventory staging; agent SSH | agen tidak membuat/menyalin kunci |
| Token forge (`gh`, `glab`) | login CLI | bukan urusan skill |
| Akses baca monitoring/log | sesi/konektor yang tersedia | tidak tersedia → "tidak bisa diperiksa" |

**Vault production dan kunci SSH production tidak pernah dipakai agen.** Guard memblokir vault id / file password yang terlihat production. Bila sebuah tugas tampak butuh rahasia production → berhenti dan tanya; biasanya itu tanda langkahnya milik manusia/pipeline.

## Urutan cari (password Vault staging)
1. Memory project → Vault (path file).
2. `ansible.cfg` project: `vault_identity_list` / `vault_password_file` yang menunjuk staging.
3. Variabel lingkungan sesi `ANSIBLE_VAULT_IDENTITY_LIST` yang menyebut id staging.

File di dalam repo dipakai hanya bila di-gitignore (`git check-ignore -q <file>`). Tidak di-ignore → jangan dipakai, jangan tampilkan isinya, berhenti dan tanya.

## Belum ada
Berhenti dan tanya (`rules.md`) dengan saran: user membuat file password staging di luar repo (`chmod 600`), lalu path-nya disimpan di memory project. Agen tidak pernah meminta user menempelkan password di chat.

## Pemakaian
- `ansible-vault view` hanya untuk file vault staging dan hanya bila perlu memeriksa nama variabel; nilainya tidak disalin ke mana pun. `ansible-vault decrypt` diblokir guard.
- Variabel rahasia baru ditambahkan dengan `ansible-vault encrypt_string --vault-id staging@<file> --name <var>`; untuk production, Coder hanya menulis placeholder + catatan di runbook (Production → rahasia yang harus diisi manusia), karena Vault production dibuka manusia.
- Task yang menangani rahasia memakai `no_log: true` (dicek Reviewer).
- Keluaran ansible selalu lewat `redact.sh` sebelum masuk dokumen.
