---
name: lint-playbook
description: Skill set DevOps (Coder) - periksa gaya dan sintaks playbook/role dengan ansible-lint, ansible-playbook --syntax-check, dan Molecule bila role punya scenario. Tidak butuh host. Dipakai /develop-tiket langkah 6. Use when asked to lint or syntax-check Ansible code; kata kunci - lint playbook, ansible-lint, syntax check, molecule.
argument-hint: KODE-TIKET [playbook...]
---
Lint perubahan tiket (`$ARGUMENTS`) di worktree tiket. Tidak menyentuh host mana pun.

Baca dulu: `~/.claude/skills/_devops-workflow-shared/infra.md` (Alat uji, Log run).

## Langkah
1. `mkdir -p "${TMPDIR:-/tmp}/qa/<KODE>"`.
2. `ansible-lint <playbook/role yang berubah> 2>&1 | tee "${TMPDIR:-/tmp}/qa/<KODE>/lint.log"` (profil dari `.ansible-lint`; tidak ada → `--profile production`). Temuan → perbaiki; aturan yang sengaja dilanggar → `# noqa <rule>` + alasan di baris itu, sebut di laporan.
3. `ansible-playbook --syntax-check <playbook>` untuk tiap playbook yang tersentuh (tanpa `-i`, atau `-i <inventory staging>`).
4. Role yang berubah dan punya `molecule/`: `molecule test -s <scenario>` (container lokal). Docker/driver tidak ada → **Tertahan** + alasan; bukan alasan berhenti.
5. `python3 "$AGENT_WORKFLOW_DIR/bin/runbook-check.py" <runbook> <playbook|role>...` harus exit 0.
6. Ringkas ke SPV: lint (jumlah temuan → 0), syntax ok, molecule Lulus/Gagal/Tertahan, runbook-check.
