# Runbook: <nama perubahan/layanan>

Tiket: <KODE> · Pemilik DevOps: <nama> · Playbook: `<playbooks/xxx.yml>` · Role: `<roles/xxx>`

## Tujuan
<Apa yang berubah dan kenapa. Rujuk KODE tiket dan ADR bila ada.>

## Host terdampak
| Lingkungan | Grup | Host | Layanan | Restart/downtime |
|---|---|---|---|---|
| staging | `<grup>` | `<host-stg-1>` | `<layanan>` | <ya/tidak> |
| production | `<grup>` | <jumlah> host | `<layanan>` | <ya/tidak> |

## Langkah
<!-- Satu langkah = satu task playbook. Nama task ditulis persis dalam backtick. Langkah tanpa task: tandai (manual). -->
1. `<Nama task pertama>`
2. `<Nama task kedua>` — <catatan singkat>
3. <Cek dashboard sebelum lanjut> (manual)

## Verifikasi
<!-- Dijalankan QA di staging dan /verify-live di production. Hanya perintah baca. -->
1. `curl -sS -o /dev/null -w '%{http_code}' https://<host>/health` → `200`
2. `ansible <grup> -i <inventory> -m service_facts` → `<layanan>` running

## Rollback
<!-- Langkah kembali ke keadaan sebelum perubahan. Tulis jujur bagian yang tidak bisa dikembalikan. -->
1. <langkah>

## Production
<!-- Diisi /finalize-runbook saat rilis: jendela perubahan, pelaksana, urutan host/batch, perintah untuk pelaksana, titik henti, rollback production, rahasia yang diisi manusia, dampak. -->
(diisi `/finalize-runbook` saat rilis)
