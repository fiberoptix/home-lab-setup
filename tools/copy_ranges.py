#!/usr/bin/env python3
"""Copy-first step of the MEMORY diet (Nov 24, 2026): copy line ranges of MEMORY.md, as tagged at
`pre-memory-diet`, VERBATIM into destination files. NEVER deletes anything from MEMORY.md - the cut is a
separate, later, tested swap. Idempotent: a range already present in a destination is skipped.

Usage (repo root):  python3 tools/copy_ranges.py <dest> <start>-<end>[:label] [<start>-<end>[:label] ...]
A destination under reference/ is created with a short header if it does not exist yet.
Exit 1 if any copied range does not read back identically from the destination.
"""
import subprocess
import sys

SRC_REF = "pre-memory-diet"
SRC = subprocess.run(["git", "show", f"{SRC_REF}:MEMORY.md"], capture_output=True, text=True, check=True).stdout.splitlines(keepends=True)
dest = sys.argv[1]
specs = sys.argv[2:]

REF_HEADERS = {
    "reference/access_and_remote.md": "SSH access matrix + remote lab management (laptop / tailnet)",
    "reference/vm_standard.md": "VM configuration standard: qm settings, autostart policy, patching policy, RAM",
    "reference/vm_build.md": "Cloud-init template (VM 9000), cloning, nofail/_netdev, prod-local NAS rule",
    "reference/patching.md": "refresh.sh (Proxmox host) and the parallel VM refresh",
    "reference/git_and_secrets.md": "This repo's dual-remote model, secret hygiene, GitHub/GitLab details",
    "reference/dev_workstation.md": "The dev workstation (.195, a VMware guest on the Z8), OS upgrade, tooling",
}

try:
    cur = open(dest).read()
except FileNotFoundError:
    if not dest.startswith("reference/"):
        sys.exit(f"ABORT: {dest} does not exist and is not under reference/")
    cur = (f"# {REF_HEADERS.get(dest, dest)}\n\n"
           "Topic reference (not tied to one phase). Loaded ON TOUCH via `phases/INDEX.md`. Blocks below are "
           "copied VERBATIM from `MEMORY.md` as of tag `pre-memory-diet` (Nov 24, 2026).\n")

added, bad = 0, 0
for sp in specs:
    rng, _, label = sp.partition(":")
    a, b = (int(x) for x in rng.split("-"))
    block = "".join(SRC[a - 1:b]).rstrip("\n") + "\n"
    marker = f"(lines {a}–{b})"
    head = (f"\n---\n\n## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` {marker} — Nov 24, 2026 "
            f"(memory-diet, copy-first)" + (f" — {label}" if label else "") + "\n\n")
    if marker in cur and "COPIED VERBATIM FROM `MEMORY.md`" in cur and head.split("\n")[3] in cur:
        print(f"skip  {dest} {rng} (already present)")
        continue
    cur = cur.rstrip("\n") + "\n" + head + block
    added += 1
    print(f"copy  {dest} <- MEMORY.md {rng} ({len(block)} bytes) {label}")

import os
os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
open(dest, "w").write(cur)
back = open(dest).read()
for sp in specs:
    a, b = (int(x) for x in sp.partition(":")[0].split("-"))
    block = "".join(SRC[a - 1:b]).rstrip("\n") + "\n"
    if block not in back:
        print(f"FAIL  read-back mismatch {a}-{b}")
        bad += 1
print(f"{dest}: {added} added, {bad} read-back failures")
sys.exit(1 if bad else 0)
