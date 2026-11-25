---
name: inventory-check
description: Skill set DevOps - bandingkan inventory dan variabel Ansible dengan dokumen infrastruktur (runbook, ADR) dan permintaan tiket, plus fakta host baca saja; menghasilkan tabel cocok/tidak. Dipakai /validate-tiket dan /audit-issue, bisa dipanggil sendiri `/inventory-check KODE|"teks"`. Use when asked to compare inventory with docs, check whether hosts/groups exist, or detect drift; kata kunci - cek inventory, drift, host ada.
argument-hint: KODE-TIKET | "teks permintaan"
---
Bandingkan apa yang diminta (`$ARGUMENTS`) dengan keadaan repo dan host. **Hanya baca**: tidak mengubah file, tidak menjalankan playbook.

Baca dulu: `~/.agent-workflow/devops/skills/_shared/rules.md`, `infra.md`.

## Langkah
1. Daftar yang disebut permintaan: grup/host, layanan, variabel, port, versi, lingkungan.
2. Inventory (staging dan production dari `ansible-inventories.json` / memory project), dari ref yang sudah disinkron:
   `ansible-inventory -i <inventory> --graph` dan `ansible-inventory -i <inventory> --host <host>` (variabel efektif; vault production tidak dibuka, variabel terenkripsi ditulis "terenkripsi").
3. Dokumen: runbook dan ADR yang menyebut grup/layanan itu (`git grep -n <nama> <ref> -- docs/`).
4. Fakta host bila perlu membuktikan keadaan nyata (modul baca saja, tanpa kunci): `ansible <grup> -i <inventory> -m setup -a 'filter=ansible_distribution*'`, `-m service_facts`, `-m package_facts`, `-m stat -a path=<file>`. Host tidak terjangkau → catat, jangan diulang-ulang.
5. Tulis tabel:
   | Yang diminta | Inventory/variabel | Dokumen | Host nyata | Cocok? |
   |---|---|---|---|---|
   Plus: grup tanpa host di staging, beda staging vs production (OS, versi paket, jumlah host), drift (repo ≠ host).
6. Hasil ke pemanggil (file `${TMPDIR:-/tmp}/validate/<KODE>/inventory-check.md` atau `${TMPDIR:-/tmp}/audit/<slug>/inventory-check.md`), keluaran disaring `redact.sh`.

## Tidak boleh
- `ansible-playbook` selain `--syntax-check`, ad-hoc selain modul baca, `ansible-vault`, mengubah file.
