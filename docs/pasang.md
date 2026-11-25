# Pasang

1. Prasyarat (macOS: `brew`; Linux: paket distro / `pipx`):
   ```bash
   brew install jq gh glab                       # atau apt install jq + gh/glab
   pipx install --include-deps ansible           # ansible-playbook, ansible-vault, ansible-inventory (+ PyYAML)
   pipx install ansible-lint
   pipx install molecule && pipx inject molecule molecule-plugins[docker]   # opsional, untuk role
   ```
   Plus: Claude Code; Orca (opsional, untuk panel per agen); Docker (opsional, untuk Molecule). Mode tim: `/config` → Teammate mode → `auto`.
2. Konektor claude.ai: **Atlassian** (Jira). **Claude Docs** hanya bila tim memilihnya untuk laporan.
3. Login CLI: `gh auth login` / `glab auth login`. Akses SSH ke host **staging** (kunci di `~/.ssh`, agent SSH). Akses production tidak dibutuhkan agen.
4. Pasang dan cek:
   ```bash
   git clone https://github.com/roiskhoiron/DevOps-Agent-Workflow ~/devops-agent-workflow
   bash ~/devops-agent-workflow/install.sh && bash ~/devops-agent-workflow/tests/run.sh   # harus "ALL PASS"
   ```
   Installer membuat symlink skill & agen ke `~/.claude`, memasang hook guard (backup `settings.json.bak-devops-workflow`), job housekeeping (macOS launchd; Linux mencetak baris cron), dan bagian CLAUDE.md global. Perubahan di repo langsung berlaku karena symlink.

**Workflow Mobile sudah terpasang di komputer yang sama?** Nama perintah dan agen sama (`/develop-tiket`, `spv`, …), jadi installer berhenti dengan daftar bentrok (exit 3). Satu komputer = satu workflow role; `install.sh --force` menggantinya dengan workflow DevOps.

Tidak ikut repo (per komputer), dibuat saat pertama dipakai:
- `~/.agent-workflow/jira-transitions.json`: id transisi Todo / In Progress / Ready To Review per project Jira.
- `~/.agent-workflow/ansible-inventories.json`: inventory staging dan production per repo, dibaca guard ([alat](alat.md), `skills/_shared/infra.md` → Setup inventory).
- File password Vault **staging** (di luar repo, `chmod 600`); path-nya disimpan di memory project.

---
[← kembali ke README](../README.md)
