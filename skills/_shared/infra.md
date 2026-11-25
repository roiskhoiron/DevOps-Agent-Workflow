# Infrastruktur, staging, dan alat uji

Padanan `devices.md` di workflow Mobile. Aturan utama: **satu host staging, satu agen, satu waktu**, dan **production hanya dibaca**.

## Setup inventory (sekali per repo)
Guard membaca `${AGENT_WORKFLOW_STATE:-$HOME/.agent-workflow}/ansible-inventories.json` untuk tahu inventory mana yang staging dan mana yang production. Kunci = nama folder checkout utama repo (sama untuk semua worktree-nya). Jika ditolak "belum punya daftar inventory":
1. Kumpulkan saran: `ls inventories/`, `ansible.cfg` (`inventory =`), memory project → Inventory.
2. Tunjukkan ke user: daftar path inventory, mana yang kamu sarankan staging dan mana production.
3. User memilih. Tulis lewat Bash (bukan Edit/Write), gabungkan dengan isi lama; path relatif dari root repo:
```bash
S=${AGENT_WORKFLOW_STATE:-$HOME/.agent-workflow}; F="$S/ansible-inventories.json"
mkdir -p "$S" && { [ -s "$F" ] || echo '{}' > "$F"; } &&
jq '. + {"infra":{"staging":["inventories/staging"],"production":["inventories/production"]}}' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
```
Path atau nama yang mengandung `prod`, `production`, `prd`, atau `live` selalu dianggap production oleh guard, walau belum terdaftar.

## Host staging
Kunci = `staging:<repo>/<inventory staging>`, mis. `staging:infra/inventories/staging`. Guard menolak `ansible-playbook` (juga `--check`) dan ad-hoc non-baca ke staging bila kunci itu tidak dipegang proses kita sendiri.

**Wajib:** setiap panggilan `lock.sh` diawali `AGENT_LOCK_PID=$PPID` di panggilan Bash yang sama (tiap panggilan Bash = shell baru; `$PPID` = proses Claude Code yang hidup selama agen hidup).
```bash
# ambil (satu panggilan Bash)
if AGENT_LOCK_PID=$PPID "$AGENT_WORKFLOW_DIR/bin/lock.sh" acquire staging:infra/inventories/staging OPS-12-qa1; then
  echo "staging milikku"
else
  echo "antre: staging dipakai"   # owner pemegang tercetak di atas
fi
# lepas setelah selesai (panggilan lain)
AGENT_LOCK_PID=$PPID "$AGENT_WORKFLOW_DIR/bin/lock.sh" release staging:infra/inventories/staging OPS-12-qa1
```
- `lock.sh who <resource>`: lihat pemilik. Kunci milik proses yang sudah mati otomatis dianggap bebas.
- Owner = `<KODE>-<peran><n>`; slot pemeriksaan manusia (`--uat`) = `human-<KODE>`.
- Dipegang tiket lain → tunggu (cek lagi tiap beberapa menit) atau tanya user mana yang didahulukan. Jangan pakai inventory lain sebagai jalan memutar.
- Satu kunci dipakai untuk satu rangkaian: check mode, atau apply 1 + Verifikasi + apply 2. Lepas di antara rangkaian supaya agen lain bisa jalan.

## Alat uji: pilih yang mana?
| Kebutuhan | Alat | Butuh kunci staging? |
|---|---|---|
| Gaya, praktik buruk, FQCN, `no_log` | `ansible-lint` (profil dari `.ansible-lint` project; tidak ada → `production`) | tidak |
| Sintaks playbook | `ansible-playbook --syntax-check <playbook>` | tidak |
| Role terisolasi di container | `molecule test` (bila role punya `molecule/`, memory project → Uji role) | tidak |
| Perubahan yang akan terjadi | `ansible-playbook -i <staging> --check --diff <playbook>` | ya |
| Terapkan ke staging | `ansible-playbook -i <staging> <playbook>` | ya |
| Idempotensi | apply kedua, `recap-check.sh --idempotent` | ya |
| Fakta host (baca saja, juga production) | `ansible <grup> -i <inventory> -m <modul baca>` (`setup`, `service_facts`, `package_facts`, `stat`, `ping`) | tidak |
| Inventory dan variabel | `ansible-inventory -i <inventory> --graph` / `--list` | tidak |

Aturan perintah:
- Panggil `ansible-playbook` langsung dengan `-i` eksplisit. Jangan lewat `make`/skrip wrapper.
- Vault staging: `--vault-id <id staging>@<file password staging>` dari memory project (`credentials.md`). Tidak ada → berhenti dan tanya.
- Batasi host dengan `--limit` hanya bila rencana menyebutnya; default seluruh grup di inventory staging.
- Molecule tidak tersedia / gagal karena lingkungan (Docker mati) → catat **Tertahan** + alasan, lanjut ke uji staging.

## Log run
Semua keluaran disimpan di `${TMPDIR:-/tmp}/qa/<KODE>/` (bukan di repo): `lint.log`, `check.log`, `apply-1.log`, `apply-2.log`, `verify.log`. Simpan dengan `| tee <file>` dan `ANSIBLE_FORCE_COLOR=0`. Salinan untuk tim ke `${AGENT_WORKFLOW_STATE:-$HOME/.agent-workflow}/runs/<KODE>-<yyyymmdd-hhmm>/` (dibersihkan housekeeping setelah 30 hari).

Sebelum keluaran apa pun masuk ke dokumen, tiket, atau PR/MR: `"$AGENT_WORKFLOW_DIR/bin/redact.sh" < check.log > check.safe.log`. Yang ditulis ke dokumen hanya versi `.safe`.

## Membaca hasil run
- `recap-check.sh <log>`: exit 0 = semua host `failed=0 unreachable=0`. Exit 1 = ada host gagal (namanya di stderr). Exit 2 = log tanpa PLAY RECAP (run terhenti) → ulangi atau lapor.
- `recap-check.sh --idempotent apply-2.log`: wajib exit 0. `changed>0` di run kedua = playbook tidak idempoten → temuan wajib, kembali ke Coder.
- `risky-scan.sh <base> HEAD`: daftar baris berisiko (`hapus-data`, `restart`, `akses`). Exit 1 → SPV berhenti dan bertanya sebelum `/apply-staging`.
- `runbook-check.py <runbook> <playbook|role>...`: exit 0 = runbook dan playbook cocok. Exit 1 = temuan review (`docs-platform.md` → Runbook).

## Production: hanya baca
- Tidak ada playbook, `--check`, Vault, atau ad-hoc non-baca ke production (guard).
- Boleh: modul baca ad-hoc (`ping`, `setup`, `service_facts`, `package_facts`, `stat`), cek HTTP/DNS/TLS (`curl -sS -o /dev/null -w '%{http_code}'`, `dig`, `openssl s_client`), dashboard/monitoring yang tersedia di sesi. Dipakai `/verify-live` dan `/read-logs`.
- Tidak `ssh` ke host production. Log production dibaca lewat sumber log/monitoring dari memory project; tidak tersedia → catat "tidak bisa diperiksa".

## Data uji di staging
- Data yang dibuat uji diawali kode tiket (mis. user `ops1234-test`, file `/tmp/OPS-1234-*`). Catat di laporan; hapus di akhir bila runbook tidak memintanya tetap ada.
- Staging terlihat jauh berbeda dari production (host hilang, versi OS beda) → catat di laporan sebagai risiko; uji tidak bermakna → berhenti dan tanya.
