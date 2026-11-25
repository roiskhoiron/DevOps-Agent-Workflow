# Platform tiket

Workflow ini **tidak menganggap platform tiket tertentu sebagai default**. Papan kanbannya sama (Todo → In Progress → Ready To Review → Done), tetapi tempat tiket disimpan dipilih user per project dan dicatat di memory project.

## Cek pertama (wajib, sebelum perintah apa pun membaca tiket)
Baca memory project → **Platform tiket**. Nilai awalnya **none** (belum pernah didefinisikan).

| Memory | Tindakan |
|---|---|
| Ada (`jira`, `github`, `gitlab`, `manual`) | Pakai. Lanjut ke "Setup status" bila belum ada entri di `ticket-transitions.json` |
| **none** / tidak ada | **Berhenti dan tanya user** sebelum langkah lain (pertanyaan di bawah). Jangan menebak dari alat yang kebetulan terpasang |
| Ada tapi tidak terjangkau (konektor/CLI belum login) | Lapor + cara memperbaikinya; jangan pindah platform diam-diam |

**Pertanyaan ke user** (satu kali, dengan satu saran):
> Tiket untuk project ini dikelola di mana?
> 1. **Jira** (butuh konektor Atlassian di claude.ai)
> 2. **GitHub Issues + GitHub Projects** (papan kanban)
> 3. **GitLab Issues + issue board**
> 4. **Tanpa platform (manual)**: isi tiket kamu tempel di chat atau taruh di file
> 5. Belum tahu

Jawaban **"belum tahu"** atau ragu → sarankan papan yang paling dekat dengan repo infrastruktur: host `git remote get-url origin` = GitHub → **GitHub Projects**; GitLab → **GitLab issue board**; lainnya → **manual**. Tunggu user memilih; saran bukan keputusan.

Simpan jawabannya sebagai memory project tipe `reference`:

| Kunci | Contoh |
|---|---|
| Platform tiket | `github` |
| Lokasi | Jira: site + project key (`OPS`); GitHub: repo issue (`org/infra`) + nomor/owner Project (`org` #7); GitLab: project (`group/infra`) |
| Prefix KODE | Jira: project key (`OPS`); GitHub/GitLab/manual: huruf besar pendek pilihan user (saran: nama repo, mis. `INFRA`) |
| Sapaan tim | cara tim menyapa reporter/reviewer (dari komentar lama) |

## KODE tiket
Semua skill memakai **KODE** = `<PREFIX>-<nomor>` (mis. `OPS-12`, `INFRA-12`): nama branch (`fix/INFRA-12`), worktree (`<repo>-12`), pesan commit, kunci (`INFRA-12-qa1`), dan `release-trace.sh`.
- Jira: KODE = issue key.
- GitHub/GitLab: user boleh mengetik `12`, `#12`, atau `INFRA-12`; agen menormalkan ke `INFRA-12` dan memakai `#12` saat memanggil CLI. Commit menyebut KODE di subjek dan `Refs #12` di badan (supaya issue tertaut).
- **Jangan pernah** menulis `Closes #12` / `Fixes #12` / `Resolves #12` di commit atau PR/MR: kata itu menutup issue otomatis saat merge, padahal Done = manusia.
- Manual: KODE dari user (atau `<PREFIX>-<nomor urut>`); isi tiket di `docs/tickets/<KODE>/tiket.md`.

## Operasi
Skill menyebut operasi ini dengan namanya (**cek akses**, **baca tiket**, **cari tiket**, **komentar tiket**, **geser status**); cara menjalankannya per platform:

| Operasi | Jira (konektor Atlassian) | GitHub Issues + Projects | GitLab Issues + board | Manual |
|---|---|---|---|---|
| Cek akses | `mcp__claude_ai_Atlassian__atlassianUserInfo` | `gh auth status`; `gh project view <no> --owner <owner>` | `glab auth status` | — |
| Baca tiket + komentar | `mcp__claude_ai_Atlassian__getJiraIssue` | `gh issue view <n> -R <repo> --comments` | `glab issue view <n> -R <repo> --comments` | `docs/tickets/<KODE>/tiket.md` atau teks dari user |
| Cari tiket terkait | `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` (`text ~ "<kata>"`) | `gh issue list -R <repo> --search "<kata>" --state open` | `glab issue list -R <repo> --search "<kata>"` | tanya user |
| Status sekarang | field status tiket | `gh project item-list <no> --owner <owner> --format json` (field Status item itu) | label `status::*` di issue | tanya user |
| Komentar tiket | `mcp__claude_ai_Atlassian__addCommentToJiraIssue` | `gh issue comment <n> -R <repo> --body-file <file>` | `glab issue note <n> -R <repo> -m "$(cat <file>)"` | tulis di laporan, tampilkan di chat untuk ditempel user |
| Geser status | `mcp__claude_ai_Atlassian__transitionJiraIssue` (id transisi) | `gh project item-edit --id <item id> --project-id <PVT_…> --field-id <field Status> --single-select-option-id <opsi>` | `glab issue update <n> -R <repo> --label status::<baru> --unlabel status::<lama>` | minta user memindahkan |

Komentar ditulis ke file dulu (`${TMPDIR:-/tmp}/<flow>/<KODE>/komentar.md`) lalu dikirim, supaya format terjaga di semua platform. Item id GitHub: cari di `gh project item-list` baris yang `content.number` = nomor issue; issue belum ada di Project → `gh project item-add <no> --owner <owner> --url <url issue>` dulu.

## Setup status (sekali per project)
Guard menolak perpindahan status sebelum project punya daftar status yang diizinkan di `${AGENT_WORKFLOW_STATE:-$HOME/.agent-workflow}/ticket-transitions.json`. Yang diizinkan selalu hanya **Todo**, **In Progress**, **Ready To Review** — **Done tidak pernah**.

1. Kumpulkan pilihan dari platform:
   - **Jira:** `mcp__claude_ai_Atlassian__getTransitionsForJiraIssue` pada satu tiket → tabel `id → nama`.
   - **GitHub:** `gh project field-list <no> --owner <owner> --format json` → field `Status` + opsi (`id → nama`) dan id Project (`gh project view <no> --owner <owner> --format json`, `.id` = `PVT_…`).
   - **GitLab:** `glab label list -R <repo>` → label `status::*`.
2. Tunjukkan ke user; user memilih tiga status itu.
3. **Belum ada papannya?** Tawarkan membuatnya, jalankan hanya setelah user bilang ya:
   - GitHub: `gh project create --owner <owner> --title "<repo> board"`, lalu `gh project link <no> --owner <owner> --repo <repo>`. Field Status bawaan hanya punya Todo / In Progress / Done → minta user menambah opsi **Ready To Review** lewat pengaturan Project di web (CLI tidak bisa menambah opsi ke field yang sudah ada), lalu ulangi langkah 1.
   - GitLab: `glab label create -R <repo> --name "status::todo"` (juga `status::in-progress`, `status::ready-to-review`, `status::done`); papan dibuat user di web dengan list per label.
4. Tulis lewat Bash (bukan Edit/Write), gabungkan dengan isi lama:
```bash
S=${AGENT_WORKFLOW_STATE:-$HOME/.agent-workflow}; F="$S/ticket-transitions.json"
mkdir -p "$S" && { [ -s "$F" ] || echo '{}' > "$F"; } &&
jq '. + {"github:PVT_kwDOAbc":{"field":"PVTSSF_xyz","allow":["f75ad846","47fc9ee4","98236657"],"names":{"f75ad846":"Todo","47fc9ee4":"In Progress","98236657":"Ready To Review"}}}' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
```
   Bentuk kunci per platform:

   | Platform | Kunci | Isi |
   |---|---|---|
   | Jira | `jira:<PROJECT KEY>` | `allow` = id transisi, `names` |
   | GitHub Projects | `github:<PVT_ id Project>` | `field` = id field Status, `allow` = id opsi, `names` |
   | GitLab board | `gitlab:<group/project>` | `label_prefix` = `status::`, `allow` = tiga label |
   | GitHub tanpa Projects (label saja) | `github-labels:<owner/repo>` | `label_prefix` = `status:`, `allow` = tiga label |

   Mesin yang masih punya `jira-transitions.json` format lama (workflow Mobile) tetap dibaca guard untuk Jira.
5. Manual: tidak ada entri; agen tidak pernah memindah status, hanya memberi tahu user.

## Yang dijaga guard (semua platform)
- Pindah status hanya ke yang ada di `allow`. Done, menutup issue (`gh issue close`, `glab issue close`), menghapus issue/item, dan mengosongkan Status (`--clear`) selalu diblokir.
- Label status (`status:`/`status::`) di luar `allow` diblokir; label status tanpa entri setup juga diblokir.
- Mengubah status lewat `gh api` / `glab api` (GraphQL `updateProjectV2ItemFieldValue`, `closeIssue`, `state_event=close`) diblokir: pakai perintah di tabel Operasi.
- Mode audit: semua penulisan tiket (komentar, label, status, membuat issue) diblokir.
