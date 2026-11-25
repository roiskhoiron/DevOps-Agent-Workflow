# Pasang

1. Prasyarat (macOS: `brew`; Linux: paket distro / `pipx`):
   ```bash
   brew install jq gh glab                       # atau apt install jq + gh/glab
   pipx install --include-deps ansible           # ansible-playbook, ansible-vault, ansible-inventory (+ PyYAML)
   pipx install ansible-lint
   pipx install molecule && pipx inject molecule molecule-plugins[docker]   # opsional, untuk role
   ```
   Plus: minimal satu AI coding agent (Claude Code, Codex CLI, Gemini CLI, Cursor, GitHub Copilot, atau OpenCode); Orca (opsional, panel per agen); Docker (opsional, untuk Molecule). Mode tim Claude Code: `/config` → Teammate mode → `auto`.
2. Platform tiket: **tidak ada default**. Saat perintah pertama dijalankan, agen menanyakan tiket dikelola di mana, lalu mengingatnya per project:
   | Pilihan | Yang perlu disiapkan |
   | --- | --- |
   | Jira | konektor **Atlassian** di claude.ai (Claude Code), atau server MCP Atlassian di tool lain |
   | GitHub Issues + GitHub Projects | `gh auth login` (dengan scope `project`: `gh auth refresh -s project`) |
   | GitLab Issues + issue board | `glab auth login` |
   | Manual (tanpa platform) | tidak ada; isi tiket ditempel di chat atau ditaruh di `docs/tickets/<KODE>/tiket.md` |
   Belum tahu → agen menyarankan GitHub Projects (repo di GitHub) atau GitLab issue board (repo di GitLab). **Claude Docs** hanya bila tim memilihnya untuk laporan.
3. Login CLI: `gh auth login` / `glab auth login`. Akses SSH ke host **staging** (kunci di `~/.ssh`, agent SSH). Akses production tidak dibutuhkan agen.
4. Pasang dan cek:
   ```bash
   git clone https://github.com/roiskhoiron/DevOps-Agent-Workflow ~/devops-agent-workflow
   bash ~/devops-agent-workflow/install.sh && bash ~/devops-agent-workflow/tests/run.sh   # harus "ALL PASS"
   ```
   Di terminal, installer bertanya **tool** dan **scope**. Tanpa terminal (atau dengan `--yes`) dipakai flag; default `--agent claude --scope global`.

   | Opsi | Arti |
   | --- | --- |
   | `--agent claude,codex,gemini,cursor,copilot,opencode` / `all` | tool yang dipasang (boleh beberapa) |
   | `--scope global` | folder home tool: berlaku untuk semua project |
   | `--scope project --project <repo>` | hanya di repo itu |
   | `--force` | ganti skill/agen bernama sama dari workflow lain |
   | `--yes` | jangan bertanya |

   Installer aman dijalankan ulang. Perubahan di repo langsung berlaku karena symlink; jalankan ulang hanya bila ada skill/agen/hook baru.

## Yang dipasang per tool
Selalu: `~/.agent-workflow/devops` → repo ini (lokasi netral yang dirujuk semua skill dan peran), folder log, dan job housekeeping. Di tabel, `~` = home (scope global) dan `<repo>` = folder project (scope project).

| Tool | Skill | Peran agen (dibuat dari `agents/*.md`) | Instruksi (blok bertanda, diperbarui saat pasang ulang) | Guard |
| --- | --- | --- | --- | --- |
| Claude Code | `~/.claude/skills` · `<repo>/.claude/skills` | `.claude/agents/*.md` (symlink) | `~/.claude/CLAUDE.md` · `<repo>/CLAUDE.md` | `settings.json` → `PreToolUse` |
| Codex CLI | `~/.agents/skills` · `<repo>/.agents/skills` | `.codex/agents/*.toml` | `~/.codex/AGENTS.md` · `<repo>/AGENTS.md` | `.codex/hooks.json` → `PreToolUse` `Bash`; **setujui lewat `/hooks`** |
| Gemini CLI | `.agents/skills` | `.gemini/agents/*.md` | `~/.gemini/GEMINI.md` · `<repo>/GEMINI.md` | `.gemini/settings.json` → `BeforeTool` `run_shell_command` (lewat `hooks/adapter.sh`) |
| Cursor | `.agents/skills` | `.cursor/agents/*.md` | global: hanya lewat UI (Settings → Rules) · `<repo>/AGENTS.md` | `.cursor/hooks.json` → `beforeShellExecution` (lewat adapter) |
| GitHub Copilot | `.agents/skills` | `~/.copilot/agents` · `<repo>/.github/agents/*.agent.md` | `~/.copilot/copilot-instructions.md` · `<repo>/AGENTS.md` | `~/.copilot/hooks/devops-guard.json` · `<repo>/.github/hooks/devops-guard.json` → `preToolUse` (lewat adapter; preview) |
| OpenCode | `.agents/skills` | `~/.config/opencode/agents` · `<repo>/.opencode/agents/*.md` | `~/.config/opencode/AGENTS.md` · `<repo>/AGENTS.md` | ❌ tidak ada hook pemblokir |

Catatan:
- **`.agents/skills`** dibaca bersama oleh Codex, Gemini CLI, Cursor, Copilot, dan OpenCode, jadi skill tidak terpasang dobel. Claude Code hanya membaca `.claude/skills`.
- **`AGENTS.md` project** dipakai bersama Codex, Cursor, Copilot, dan OpenCode; installer hanya menulis satu blok `<!-- devops-agent-workflow:start/end -->`, isi lain file itu tidak disentuh.
- **Guard di luar Claude Code/Codex** memakai `hooks/adapter.sh`, yang menerjemahkan format hook tool itu ke format `guard.sh` lalu menjawab dengan format blokir tool itu. Pemeriksaan yang tercakup: perintah shell (git, ansible, pipeline, tiket). Pemeriksaan edit file di worktree primary dan transisi Jira lewat MCP hanya ada di Claude Code.
- **OpenCode tanpa guard:** semua pagar menjadi aturan yang wajib dipatuhi agen. Tambahkan pembatas di `opencode.json`, mis. `"permissions":[{"action":"shell","resource":"ansible-playbook *production*","effect":"deny"}]`, dan jangan simpan akses production di komputer itu.
- **Scope project** membuat symlink yang menunjuk ke lokasi repo workflow di komputer ini. Jangan di-commit: masukkan folder-folder itu ke `.gitignore` repo infrastruktur, dan minta tiap anggota tim menjalankan `install.sh` sendiri.
- **Memory project:** Claude Code memakai fitur memory-nya; tool lain memakai `~/.agent-workflow/projects/<repo>/memory.md`.
- Lokasi di atas diverifikasi terhadap dokumentasi resmi tiap tool (November 2026). Tool yang berubah lokasi → perbarui fungsi `skills_dir`, `roles_dir`, `instr_file`, `install_hook` di `install.sh`.

**Workflow Mobile sudah terpasang di tempat yang sama?** Nama perintah dan agen sama (`/develop-tiket`, `spv`, …), jadi installer berhenti dengan daftar bentrok (exit 3). File peran milikmu sendiri dengan nama yang sama juga dianggap bentrok. Satu tempat = satu workflow role; `install.sh --force` menggantinya dengan workflow DevOps. Tip: pasang tiap workflow dengan `--scope project` di repo masing-masing supaya tidak bentrok.

Tidak ikut repo (per komputer), dibuat saat pertama dipakai:
- `~/.agent-workflow/ticket-transitions.json`: status Todo / In Progress / Ready To Review yang boleh dipakai agen, per project (Jira, GitHub Project, atau label GitLab). Done tidak pernah ada di sana.
- `~/.agent-workflow/ansible-inventories.json`: inventory staging dan production per repo, dibaca guard ([alat](alat.md), `skills/_shared/infra.md` → Setup inventory).
- File password Vault **staging** (di luar repo, `chmod 600`); path-nya disimpan di memory project.

---
[← kembali ke README](../README.md)
