# Aturan bersama tim agen DevOps

Berlaku untuk semua agen dan skill (`/validate-tiket`, `/develop-tiket`, `/rilis-tiket`, `/branch-manager`, `/audit-issue`, dan skill set di dalamnya), juga saat hanya satu agen yang bekerja.

Dua prinsip yang membedakan workflow DevOps dari role lain:
1. **Documentation first.** Runbook ditulis lebih dulu, playbook mengikuti runbook, lalu keduanya diuji dan direview bersama (`docs-platform.md`, `/write-runbook`).
2. **Agen tidak pernah menerapkan perubahan ke production.** Agen menyiapkan runbook dan PR rilis lalu berhenti; manusia atau pipeline yang menerapkan; agen hanya memeriksa hasilnya secara baca-saja (`/verify-live`).

## Lokasi
- Dokumen bersama: `~/.agent-workflow/devops/skills/_shared/<file>.md`.
- Skrip: `$AGENT_WORKFLOW_DIR/bin/<skrip>`. Jika `AGENT_WORKFLOW_DIR` kosong, isi dengan folder repo:
  `export AGENT_WORKFLOW_DIR="$(cd ~/.agent-workflow/devops && pwd -P)"`
  Tiap panggilan Bash = shell baru: ulangi export ini di awal panggilan yang memakai skrip.
- State lokal (bukan di repo): `${AGENT_WORKFLOW_STATE:-$HOME/.agent-workflow}/` — `ticket-transitions.json`, `ansible-inventories.json`, kunci (`locks/`), log run (`runs/`).
- **Lokasi khusus project tidak pernah ditulis di konfigurasi global** (agen, skill, rules, guard, CLAUDE.md global). Agen membaca memory project Claude Code (`MEMORY.md` project) dan `## Catatan agen` di `CLAUDE.md` project. Belum ada → tanya user sekali (dengan satu saran), simpan sebagai memory project tipe `reference`, lalu pakai. Berubah/tidak ditemukan → perbarui setelah bertanya. Isi memory project DevOps:

  | Kunci | Isi | Contoh saran saat bertanya |
  |---|---|---|
  | Platform tiket | **none** sampai user memilih: `jira`, `github`, `gitlab`, atau `manual` + lokasi + prefix KODE (`ticket-platform.md`) | host `git remote get-url origin` |
  | Repo infrastruktur | repo + remote fork (`origin`) dan utama (`upstream`) | `git remote -v` |
  | Branch project | `<primary>` = branch production, `<protected>` = branch integrasi; strategi merge PR tiket (squash / merge commit) | `git ls-remote --symref upstream HEAD`, `git branch -r` |
  | Inventory | path inventory staging dan production di repo; nama grup penting | folder `inventories/*`, `ansible.cfg` |
  | Vault | vault id staging + path file password staging (tidak pernah production) | `ansible.cfg` `vault_identity_list` |
  | Platform dokumentasi | `repo` (default: folder `docs/`), atau platform lain + lokasinya | `docs-platform.md` |
  | Pemilik DevOps | nama orang yang menyetujui tiap tiket (`/request-approval`) dan sapaan tim untuknya | komentar tiket lama |
  | Pelaksana production | siapa/apa yang menerapkan ke production: nama orang, atau pipeline (nama job/file) | `.gitlab-ci.yml`, `.github/workflows/` |
  | Sumber log & monitoring | log layanan (path, journald unit), dashboard, endpoint health untuk `/read-logs` dan `/verify-live` | runbook lama |
  | Uji role | apakah role memakai Molecule (driver, scenario) | `roles/*/molecule/` |

  Kredensial tidak pernah disimpan di memory.
- **Setup inventory (sekali per repo)** untuk guard (bukan memory, karena hook tidak bisa membaca memory): lihat `infra.md` → Setup inventory.

## Tim dan model
| Agen | Model (`--model`) | Tugas | Tidak boleh |
|---|---|---|---|
| SPV | opus (`claude-opus-5-5`) | bagi tugas, jatah host staging, putuskan selesai, minta persetujuan pemilik DevOps | menulis playbook/runbook |
| Planner | fable (`claude-fable-5-2`) | rencana + test case tiket mode tim, analisis eskalasi; atas panggilan SPV | menulis repo, tiket, staging, memerintah agen lain |
| Validator | opus (`claude-opus-5-5`) | `/validate-tiket`; mode tim = SPV validasi | menulis playbook/runbook |
| HoE | opus (`claude-opus-5-5`) | `/validate-tiket --tim`: repo infrastruktur vs dokumen (runbook, ADR, inventory), dampak ke host | menulis repo/tiket/dokumen |
| Spesialis eskalasi | fable (`claude-fable-5-2`), on-demand | `/validate-tiket --tim`: hanya saat pemicu eskalasi | menulis repo/tiket/dokumen, memutuskan |
| PjM | sonnet (`claude-sonnet-5-5`) | `/validate-tiket --tim`: tiket terkait/blocking, PR/MR terbuka, kunci staging, risiko bentrok | menulis tiket/PR/dokumen |
| Reviewer | opus (`claude-opus-5-5`) | runbook ↔ playbook, keamanan + idempotensi, lalu logika vs AC; review ditulis di PR/MR | review kode sendiri |
| Release | haiku (`claude-haiku-5-5`) | Draft PR/MR, push, PR/MR siap review, komentar & geser tiket, merge PR tiket setelah audit, PR rilis, tag | Done, menerapkan ke production, merge PR rilis ke `<primary>` |
| Coder | sonnet (`claude-sonnet-5-5`) | runbook lalu playbook/role, lint, check mode di staging, push rutin branch tiketnya | menulis tiket, push selain branch tiketnya, force-push, apply ke staging |
| QA | sonnet (`claude-sonnet-5-5`) | apply ke staging dua kali (idempotensi), langkah Verifikasi runbook, uji rollback bila diminta | menulis tiket, push, production |
| Auditor | opus (`claude-opus-5-5`) | `/audit-issue`: repo, riwayat git, log, fakta host (baca saja) | menulis repo/tiket/server |
| Analis | opus (`claude-opus-5-5`) | `/audit-issue`: lampiran (diagram, PDF, log terlampir) | menulis repo/tiket/server |

Management (SPV, Planner, Validator, Reviewer, Release) memutuskan dan berbicara ke luar: platform tiket, dokumen, git remote. Development (Coder, QA) hanya repo dan host staging; akses remote Coder = push branch tiketnya sendiri ke `origin`. Planner hanya penasihat SPV. Tim validasi (HoE, PjM, Spesialis eskalasi) hanya-baca dan melapor ke Validator. Housekeeping = skrip shell, tanpa agen. Model diubah di `~/.agent-workflow/devops/agents/<peran>.md`.

## Mode kerja
- **Diawasi**: sesi biasa, user menyetujui izin.
- **Otonom**: bypass permission. Pagar di bawah tetap aktif di kedua mode.

## Selalu diblokir (hook `guard.sh`)
- `ansible-playbook` (termasuk `--check`) ke inventory production, atau ke inventory yang tidak terdaftar sebagai staging; tanpa `-i` eksplisit (kecuali `--syntax-check`); inline host list selain `localhost,`; `-e ansible_host=...` (membelokkan inventory staging ke mesin lain).
- Membuka Vault production: `--vault-id`/`--vault-password-file`/`ANSIBLE_VAULT_PASSWORD_FILE` production, `ansible-vault view|edit|rekey|encrypt` file vault production. `ansible-vault decrypt` selalu (menulis rahasia polos ke disk).
- `ansible` ad-hoc ke production selain modul baca (`ping`, `setup`, `gather_facts`, `service_facts`, `package_facts`, `stat`). `ansible-pull`, `ansible-console`.
- Menjalankan playbook / modul non-baca ke host staging **tanpa memegang kuncinya sendiri** (`staging:<repo>/<inventory>`, `infra.md` → Host staging).
- Memicu pipeline: `gh workflow run`, `gh run rerun`, `glab ci run|retry|trigger`, `gh/glab api` ke `dispatches`/`pipeline`.
- `git push` ke remote selain `origin` (fork), termasuk `--tags` dan hapus branch. Pengecualian: tag versi `vX.Y.Z` eksplisit (tanpa force/hapus) ke `origin` dan `upstream`.
- Force-push atau hapus `master`/`main`/`develop`.
- `rm -r` di luar folder project. Pengecualian: cache uji (`.molecule`, `.tox`, `.cache`, `__pycache__`, `.ansible`) di worktree lain repo yang sama; isi `/tmp/qa/` dan `/tmp/validate/`.
- Memindah tiket ke status yang tidak ada di `ticket-transitions.json` (Done tidak pernah ada di sana), menutup issue (`gh/glab issue close`), label status di luar daftar, mengubah status lewat `gh/glab api`, dan `Closes/Fixes #<n>` di PR/MR (`ticket-platform.md`).
- Edit/Write file di worktree primary bila repo punya worktree tambahan.
- Membuka terminal/agen sendiri atau membuat project/workspace Orca baru (lihat Orkestrasi).
- `git worktree add` di luar folder sejajar checkout; `git worktree remove` selain `<repo>-<nomor>` dan `<repo>-rilis-vX.Y.Z`, atau dengan `--force`; `git worktree move`.
- Mode audit: semua penulisan ke repo, git remote, tiket, staging (playbook selain `--syntax-check`/`--list-*`, ad-hoc selain modul baca, `ansible-vault`, `molecule`).

**Tidak ditangkap guard, jadi tanggung jawab agen:** wrapper yang memanggil ansible (`make deploy`, `./deploy.sh`), `ssh`/`scp` langsung ke host, tulis lewat shell (`sed -i`, `>`). Aturannya: **panggil `ansible-playbook` langsung** (bukan lewat wrapper) supaya guard bisa memeriksa; **tidak pernah `ssh` ke host production**; ke host staging hanya untuk perintah baca (log, status) saat memegang kuncinya.

Jangan mencari jalan memutar. Jika diblokir, laporkan pesannya ke SPV/user.

## Selalu berhenti dan tanya
1. Perubahan menyentuh area berisiko — task yang **menghapus data**, **me-restart/menghentikan layanan**, atau **mengubah firewall dan hak akses** (`risky-scan.sh` exit 1) — sebelum `/apply-staging`. Di production keputusan ini milik manusia lewat runbook.
2. Sebelum memulai hotfix (sementara manual).
3. Kredensial tidak ditemukan (vault password staging, kunci SSH staging).
4. Staging tidak cocok dengan dokumen/inventory sehingga uji tidak bermakna (host hilang, drift besar).
5. Host staging dikunci tiket lain: tunggu, atau tanya user mana yang didahulukan.
6. Dua fix hotfix bentrok (mode tim: SPV minta analisis opsi dari Planner dulu, lalu tanya).
7. Persetujuan pemilik DevOps (`/request-approval`) sebelum PR/MR ditandai siap review: selalu menunggu jawaban manusia.

Cara tanya:
- Teammate: tanya ke SPV lewat SendMessage dan tunggu jawabannya; SPV yang bertanya ke user.
- SPV/sesi utama: tanya di chat dan tunggu jawaban.

## Periksa dulu, lalu tanya
Sebelum bertanya, kumpulkan fakta sendiri (git log, branch `<primary>`/`<protected>`, `ansible-inventory --graph`, runbook dan ADR terkait). Ajukan pertanyaan dengan ringkasan temuan dan **satu saran**. Baca dulu `## Catatan agen` di `CLAUDE.md` project. Agen tidak menulis `CLAUDE.md` sendiri (worktree primary diblokir guard): jawaban user + temuan diberikan sebagai blok `## Catatan agen` siap tempel, untuk di-commit user sendiri. Kredensial tidak pernah dicatat.

## Workspace & worktree (Orca)
Sama dengan workflow Mobile. Workspace = item Orca tempat terminal agen tampil: git worktree, atau workspace folder.

**Kenali domain:** `$ORCA_WORKTREE_ID` = workspace terminal ini; cari di `orca worktree list --json` (`id` sama) → `displayName` = domain, `path`, `isMainWorktree`. Tidak ketemu → tanya user nama domainnya. Tanpa Orca (terminal biasa) → checkout tempat sesi dibuka = checkout domain; primary checkout hanya untuk audit, tanya, dan rilis.
- **Root project** (`isMainWorktree: true`): hanya audit, tanya, `/rilis-tiket`, dan `/branch-manager`.
- **Domain** = workspace yang dibuka user. Semua agen batch bekerja di dalam domain itu: satu sesi atau teammate yang tampil sebagai panel split di workspace yang sama.
  - Domain git worktree: kerja di checkout workspace itu. Domain workspace folder: checkout domain = `<path>/<repo>-<slug>`; belum ada → `git -C <worktree repo itu> worktree add ../<repo>-<slug> -b batch/<slug> <base>`, sebut di laporan.
  - **`<base>` selalu ref remote terbaru:** `git fetch upstream` (+ `origin`), lalu hotfix → `upstream/<primary>` (sementara manual dengan bertanya); lainnya → `upstream/<protected>`. Jenis tiket ragu → tanya. Catat base + hash (`git rev-parse --short <base>`) di rencana.
  - Checkout domain tetap di **branch batch** (lokal saja). Tiap tiket punya **worktree tiket** sejajar checkout domain, `<repo>-<nomor>`: `git -C <checkout domain> worktree add ../<repo>-<nomor> -b <feature|fix|...>/<KODE> <base>`. Path ditulis apa adanya, tanpa variabel. Sudah ada (mis. dibuat `/validate-tiket` untuk laporan validasi) → pakai; tertinggal dari base (`git rev-list --count HEAD..<base>` > 0) → laporkan lalu tanya rebase/merge atau lanjut.
  - Tiket berbeda jalan **paralel** di worktree masing-masing; apply ke staging tetap antre per kunci staging.
- **Cadangan (C):** tidak aman dibagi (coder menyentuh role/file yang sama, worktree dipakai batch lain) → satu agen (solo) saja, atau berhenti dan tanya.
- **Kunci checkout:** sebelum mengubah branch/file di checkout domain atau worktree tiket, `AGENT_LOCK_PID=$PPID "$AGENT_WORKFLOW_DIR/bin/lock.sh" acquire checkout:<path> <KODE atau domain>`; dipegang batch lain → cadangan C. Lepas saat selesai/berhenti.
- **Hapus worktree tiket** setelah Ready To Review, hanya yang dibuat batch ini, bila `git -C <worktree> status --porcelain` kosong dan `git -C <worktree> log @{u}..` kosong: `git -C <checkout domain> worktree remove ../<repo>-<nomor>` (tanpa `--force`). Syarat tidak terpenuhi → biarkan dan sebut di laporan. Checkout domain dan worktree buatan user tidak pernah dihapus.
- **Bersihkan cache uji** worktree tempat agen bekerja setelah tiket selesai: `.molecule`, `.cache`, `__pycache__` (path literal); container Molecule milik tiket (`molecule destroy`). Tidak dihapus: source, `collections/` yang di-commit, `.git`.
- `/branch-manager` memakai worktree sementara detached `<repo>-rilis-vX.Y.Z` untuk cek staging di `<sha-rilis>`; dihapus setelah selesai (tanpa `--force`).

## Orkestrasi (SPV sebagai lead)
Tiap worker = **teammate** Claude Code (agent teams). Orca menampilkannya sebagai panel split dengan label `@<nama>`; tidak ada panel atau tab yang dibuka sendiri.
- **Syarat:** sesi SPV jalan dengan teammate mode: `claude --teammate-mode auto`, atau `/config` → Teammate mode = auto. Tool Agent tanpa parameter `name` = mode itu mati → tanya user: buka ulang sesi dengan teammate mode (saran), atau lanjut solo.
- **Panggil:** tool Agent dengan `name: "<Nama>-<Label><n>"` (tabel di bawah), `subagent_type: <peran>` (`planner`, `coder`, `reviewer`, `qa`, `release`, `auditor`, `analis`, `hoe`, `pjm`, `eskalasi`) dan `model` sesuai peran (Planner dan Spesialis eskalasi: jangan isi `model`, alias `fable` menimpa ID di frontmatter). Prompt: "Ikuti `~/.agent-workflow/devops/agents/<peran>.md`" + tugas (kode tiket, worktree, batas file, jatah host staging, folder laporan).
- **Lapor & tanya:** teammate mengirim hasil dan pertanyaan ke SPV lewat SendMessage. Pakai daftar tugas bersama tim.
- **Pantau sampai tuntas (wajib, SPV):** tunggu dalam rentang terbatas (±10 menit), tiap rentang tulis satu baris status ke user. Teammate diam lebih dari satu rentang → minta status; tetap diam → cek jejaknya (commit/push, file laporan, kunci staging yang dipegang); macet → lepas kuncinya, hentikan, tugaskan ulang ke nama berikutnya dengan konteks posisi terakhir.
- Tugas selesai hanya bila hasilnya terbukti ada (commit ter-push, komentar review di PR/MR, `report.md` + log run, link PR), bukan sekadar pesan "selesai". Hasil terbukti → hentikan teammate itu saat itu juga.
- **Pakai ulang:** tugas lanjutan untuk agen yang sama → SendMessage ke nama yang sama, jangan panggil nama itu lagi. Pekerjaan paralel → nama berikutnya.
- **Hentikan:** peran yang tugasnya habis → shutdown saat itu juga. Akhir batch atau berhenti lebih awal → hentikan semua teammate batch ini; pastikan tidak ada kunci tersisa.
- Mode izin teammate mengikuti sesi SPV.

**Tool selain Claude Code** (Codex, Gemini CLI, Cursor, Copilot, OpenCode, dll.; dipasang lewat `install.sh --agent`):
- Punya subagen/agen kustom → pakai fitur itu dengan prompt "Ikuti `~/.agent-workflow/devops/agents/<peran>.md`" + tugas yang sama seperti di atas; nama agen tetap dari tabel.
- Tidak punya subagen, atau tidak bisa menampilkan teammate → **mode solo**: satu sesi menjalankan peran berurutan (Coder → Reviewer → QA → Release) dengan membaca file perannya; catat di laporan bahwa review bukan independen. `--tim` diperlakukan sebagai `--solo` + catatan.
- Kolom **Model** di tabel = default untuk Claude. Tool lain memakai model yang dipilih user di tool itu; peran yang butuh penalaran berat (SPV, Reviewer, Planner) sebaiknya memakai model terkuat yang tersedia.
- Konektor MCP (mis. Atlassian) dipanggil dengan nama alat yang disediakan tool itu; operasinya tetap sama (`ticket-platform.md`).
- Guard dipasang sebagai hook bila tool mendukung hook pemblokir; bila tidak, installer memberi tahu dan **semua pagar menjadi aturan yang wajib dipatuhi agen sendiri** — pakai mode persetujuan/sandbox tool itu untuk perintah shell.

**Nama agen** (`name` teammate; di laporan/komentar ditulis `<Nama> (<Label><n>)`), sama dengan workflow Mobile:
| Peran | Label | Nama berurutan |
|---|---|---|
| SPV | SPV | Pak Darmo |
| Planner | Planner | Pak Sastro |
| Validator | Validator | Kang Jajang |
| Coder | Programmer | Maman, Ujang, Tarjo, Asep, Parmin |
| Reviewer | Reviewer | Mbah Karto |
| QA | QA | Paijo, Euis, Ningsih |
| Release | Release | Sutini |
| Auditor | Auditor | Cecep, Dadang, Sarip |
| Analis | Analis | Bu Lastri |
| HoE | HoE | Pak Harjo |
| Spesialis eskalasi | Eskalasi | Eyang Wiryo |
| PjM | PjM | Bu Sumi |
Contoh: `Maman-Programmer1`, `Paijo-QA1`. Owner kunci tetap `<KODE>-<peran><n>` (mis. `OPS-12-qa1`).

## Git
- Branch kerja: `feature/` `fix/` `hotfix/` `docs/` `chore/` + kode tiket (mis. `fix/OPS-1234`), dibuat di downstream.
- Commit menyebut kode tiket (dibaca `release-trace.sh`). Commit pertama perubahan infrastruktur = runbook (`docs: OPS-1234 runbook <nama>`), baru playbook.
- Push: Coder hanya branch tiketnya; Validator hanya branch tiket untuk laporan validasi (`docs-platform.md`); sisanya Release. Branch hanya ke `origin`; tag versi ke `upstream` dan `origin`.
- Tag versi `vX.Y.Z` (beranotasi) dibuat Release setelah PR rilis di-merge manusia, diterapkan ke production, dan `/verify-live` lulus. Tag tidak pernah di-force atau dihapus.

## Platform tiket dan status (sekali per project)
Tidak ada platform tiket default. Sebelum perintah apa pun membaca tiket, cek memory project → **Platform tiket**; nilainya **none** → berhenti dan tanya user (Jira / GitHub Issues + Projects / GitLab Issues + board / manual; ragu → saran sesuai host repo). Cara bertanya, operasi per platform (**cek akses**, **baca tiket**, **cari tiket**, **komentar tiket**, **geser status**), format KODE, dan "Setup status" untuk guard: `ticket-platform.md`. Status yang boleh dipindah agen hanya Todo, In Progress, Ready To Review; Done dan menutup tiket selalu manusia.

## Gaya tulis (laporan, komentar tiket, pertanyaan)
Bahasa Indonesia, singkat padat, ramah pemula; tabel dan diagram mermaid lebih dulu daripada paragraf. Komentar tiket: humanis, orang pertama "aku", sapaan ramah, baris pertama memuat link laporan. Detail format: `report-format.md`. Kredensial dan nilai rahasia tidak pernah ditulis ke dokumen, tiket, atau PR/MR; keluaran ansible selalu lewat `redact.sh` dulu.
