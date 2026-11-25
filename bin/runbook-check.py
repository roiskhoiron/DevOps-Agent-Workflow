#!/usr/bin/env python3
"""runbook-check.py <runbook.md> <playbook.yml | role-dir>...

Documentation first: checks that a runbook and its playbooks match (docs/documentation-first.md).
1. The runbook has the five required sections (## headings, case-insensitive, extra words allowed):
   Tujuan, Host terdampak, Langkah, Verifikasi, Rollback.
2. Every task (tasks, pre_tasks, post_tasks, handlers, block/rescue/always; role tasks/ and handlers/)
   has a name, and that name appears in backticks in a numbered item of the Langkah section.
3. Every numbered Langkah item names at least one existing task in backticks, or is marked (manual).

Output, one finding per line (TSV):
  MISSING_SECTION <section> | TASK_NO_NAME <file> | TASK_NO_STEP <task> | STEP_NO_TASK <n> <text>
Exit: 0 runbook and playbooks match, 1 findings, 2 usage or unreadable input.
Needs PyYAML (always installed with Ansible).
"""
import os
import re
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    print("runbook-check: PyYAML tidak ada (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)

SECTIONS = ["Tujuan", "Host terdampak", "Langkah", "Verifikasi", "Rollback"]
TASK_LISTS = ("tasks", "pre_tasks", "post_tasks", "handlers")
BLOCK_LISTS = ("block", "rescue", "always")


class Loader(yaml.SafeLoader):
    pass


# Ansible tags (!vault, !unsafe, ...): keep the value, ignore the tag
Loader.add_multi_constructor("!", lambda loader, suffix, node: loader.construct_scalar(node)
                             if isinstance(node, yaml.ScalarNode) else None)


def load(path):
    with open(path, encoding="utf-8") as f:
        return [d for d in yaml.load_all(f, Loader=Loader) if d is not None]


def walk_tasks(items, path, names, unnamed):
    for t in items or []:
        if not isinstance(t, dict):
            continue
        if any(k in t for k in BLOCK_LISTS):
            if t.get("name"):
                names.append(str(t["name"]))
            for k in BLOCK_LISTS:
                walk_tasks(t.get(k), path, names, unnamed)
            continue
        if t.get("name"):
            names.append(str(t["name"]))
        else:
            unnamed.append(path)


def collect(target, names, unnamed):
    if os.path.isdir(target):  # role dir
        for sub in ("tasks", "handlers"):
            d = os.path.join(target, sub)
            if not os.path.isdir(d):
                continue
            for fn in sorted(os.listdir(d)):
                if fn.endswith((".yml", ".yaml")):
                    p = os.path.join(d, fn)
                    for doc in load(p):
                        walk_tasks(doc if isinstance(doc, list) else [], p, names, unnamed)
        return
    for doc in load(target):
        if not isinstance(doc, list):
            continue
        if any(isinstance(x, dict) and ("hosts" in x or "import_playbook" in x) for x in doc):
            for play in doc:  # playbook: plays hold the task lists
                if isinstance(play, dict):
                    for k in TASK_LISTS:
                        walk_tasks(play.get(k), target, names, unnamed)
        else:  # bare task file
            walk_tasks(doc, target, names, unnamed)


def runbook_parts(text):
    heads, cur = {}, None
    for line in text.splitlines():
        m = re.match(r"^##\s+(.+?)\s*$", line)
        if m:
            cur = m.group(1).strip().lower()
            heads[cur] = []
            continue
        if cur is not None:
            heads[cur].append(line)
    return heads


def main(argv):
    if len(argv) < 3:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        return 2
    rb, targets = argv[1], argv[2:]
    try:
        text = open(rb, encoding="utf-8").read()
        names, unnamed = [], []
        for t in targets:
            collect(t, names, unnamed)
    except (OSError, yaml.YAMLError) as e:
        print(f"runbook-check: {e}", file=sys.stderr)
        return 2
    out = []
    heads = runbook_parts(text)

    def section(name):
        for h, body in heads.items():
            if h.startswith(name.lower()):
                return body
        return None

    for s in SECTIONS:
        if section(s) is None:
            out.append(f"MISSING_SECTION\t{s}")
    for p in unnamed:
        out.append(f"TASK_NO_NAME\t{p}")

    steps = []  # (n, text) of numbered items in Langkah, continuation lines joined
    for line in section("Langkah") or []:
        m = re.match(r"^\s*(\d+)[.)]\s+(.*)$", line)
        if m:
            steps.append([m.group(1), m.group(2)])
        elif steps and line.strip() and line.startswith((" ", "\t")):
            steps[-1][1] += " " + line.strip()
    known = set(names)
    mentioned = set()
    for n, s in steps:
        refs = re.findall(r"`([^`]+)`", s)
        mentioned.update(refs)
        if re.search(r"\(manual\)", s, re.I):
            continue
        if not any(r in known for r in refs):
            out.append(f"STEP_NO_TASK\t{n}\t{s}")
    for name in dict.fromkeys(names):
        if name not in mentioned:
            out.append(f"TASK_NO_STEP\t{name}")
    if out:
        print("\n".join(out))
    return 1 if out else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
