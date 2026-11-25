# Masalah umum

| Gejala | Artinya / yang dilakukan |
| --- | --- |
| "DIBLOKIR oleh guard: …" | Perintah melanggar pagar. Agen melaporkan pesannya, tidak mencari jalan memutar; pesannya biasanya menyebut cara yang benar |
| "… ke inventory production dilarang" | Memang tidak boleh. Agen menyiapkan runbook + PR rilis; penerapan oleh manusia/pipeline |
| "belum punya daftar inventory staging/production" | Repo baru: agen menunjukkan daftar inventory, kamu pilih mana staging dan production (`infra.md` → Setup inventory) |
| "bukan inventory staging yang terdaftar" | Inventory belum ada di `ansible-inventories.json`, atau path salah. Perbarui daftarnya bila memang staging |
| "host staging … belum kamu kunci" / "sedang dikunci …" | Ambil kunci dengan `lock.sh acquire` di panggilan yang sama (`AGENT_LOCK_PID=$PPID`), atau antre |
| "tanpa inventory eksplisit" | Tulis `-i <inventory staging>`; default `ansible.cfg` bisa menunjuk production |
| "agen tidak memicu pipeline" | Pipeline deploy dijalankan manusia; agen hanya membaca log-nya |
| `recap-check.sh --idempotent` exit 1 | Run kedua masih mengubah sesuatu: task `command`/`shell` tanpa `creates`/`changed_when`, template berubah tiap run, atau restart langsung |
| `runbook-check.py` exit 1 | Runbook dan playbook belum cocok: bagian hilang, task tanpa langkah, atau langkah tanpa task |
| Installer exit 3 "Bentrok" | Workflow role lain (Mobile) terpasang dengan nama yang sama; pakai `--force` bila komputer ini untuk DevOps |
| "belum punya daftar transisi" | Project Jira baru: pilih id Todo, In Progress, Ready To Review |
| PR/MR tetap Draft | Persetujuan pemilik DevOps belum ada; balas ringkasan `/request-approval` dengan "setuju" atau "tolak" |

---
[← kembali ke README](../README.md)
