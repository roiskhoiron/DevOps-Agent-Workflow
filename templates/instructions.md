# DevOps agent workflow
- Perintah (skill): `/validate-tiket`, `/develop-tiket`, `/rilis-tiket`, `/branch-manager`, `/audit-issue`. Tool tanpa perintah `/` → user menyebut nama skill-nya (mis. "jalankan skill develop-tiket untuk OPS-12"); isi skill juga ada di `~/.agent-workflow/devops/skills/<nama>/SKILL.md`. Aturan bersama: `~/.agent-workflow/devops/skills/_shared/rules.md`. Peran agen: `~/.agent-workflow/devops/agents/<peran>.md`.
- Platform tiket tidak punya default: memory project **none** → tanya user dulu (Jira / GitHub Projects / GitLab board / manual). Operasi per platform: `~/.agent-workflow/devops/skills/_shared/ticket-platform.md`.
- Documentation first: runbook di `docs/runbooks/` ditulis sebelum playbook; tiap task punya langkah runbook dan sebaliknya.
- Agen tidak pernah menerapkan ke production, membuka Vault production, atau memicu pipeline: agen menyiapkan runbook + PR rilis, manusia/pipeline yang menerapkan, agen memverifikasi baca-saja.
- Host staging dipakai satu agen pada satu waktu (`bin/lock.sh`, kunci `staging:<repo>/<inventory>`); panggil `ansible-playbook` langsung dengan `-i` eksplisit, bukan lewat wrapper.
- Memory project: fitur memory tool bila ada, selain itu `~/.agent-workflow/projects/<repo>/memory.md`. Keputusan per project tidak ditulis agen ke file instruksi project: agen memberi blok `## Catatan agen` untuk di-commit user.
