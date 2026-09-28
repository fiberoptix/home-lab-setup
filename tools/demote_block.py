#!/usr/bin/env python3
"""Demote ONE block from phases/current_phase.md into a phase file (MAKE_MEMORIES step 2).

Stages ONLY the demotion, built from HEAD rather than the working tree, so unrelated uncommitted
edits in the same two files are NOT swept into the demotion commit (the step-2 commits are
pre-approved; other work may not be). The identical change is applied on top of the working tree.
Aborts if the block text differs between HEAD and the working tree, or the heading is ambiguous.

Run from the repo root:
  python3 tools/demote_block.py "<heading prefix>" <dest phase file> "<note for the copy>" \\
      "<demotion-log row(s)>" "<pass label, e.g. pass 13>"
Then VERIFY (every removed non-blank line must be in the staged destination) and commit.

Written for MAKE_MEMORIES pass 11 (Sep 28, 2026); used for passes 11 and 12.
"""
import datetime
import subprocess
import sys

CP = "phases/current_phase.md"
LOG_HEADING = "## 📦 DEMOTION LOG"
prefix, dest, note, logrow = sys.argv[1:5]
PASS = sys.argv[5] if len(sys.argv) > 5 else "pass ?"
TODAY = datetime.date.today().strftime("%b %-d, %Y")


def git(*a, inp=None):
    return subprocess.run(["git", *a], input=inp, capture_output=True, text=True, check=True).stdout


def split_block(lines):
    starts = [i for i, l in enumerate(lines) if l.startswith("## ")]
    hit = [i for i in starts if lines[i].startswith(prefix)]
    if len(hit) != 1:
        sys.exit(f"ABORT: heading prefix matched {len(hit)} blocks, need exactly 1")
    if lines[hit[0]].startswith(LOG_HEADING):
        sys.exit("ABORT: refusing to demote the demotion log itself")
    s = hit[0]
    e = next((i for i in starts if i > s), len(lines))
    return s, e


def insert_logrow(lines):
    """Append after the LAST table row inside the demotion-log block."""
    try:
        start = next(i for i, l in enumerate(lines) if l.startswith(LOG_HEADING))
    except StopIteration:
        sys.exit("ABORT: demotion log block not found")
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    rows = [i for i in range(start, end) if lines[i].startswith("|")]
    if not rows:
        sys.exit("ABORT: demotion log has no table rows")
    j = rows[-1] + 1
    return lines[:j] + [logrow + "\n"] + lines[j:]


def transform(cp_text, dest_text):
    cp = cp_text.splitlines(keepends=True)
    s, e = split_block(cp)
    block = cp[s:e]
    while block and block[-1].strip() in ("", "---"):
        block.pop()
    new_cp = insert_logrow(cp[:s] + cp[e:])
    header = (f"\n---\n\n## DEMOTED VERBATIM FROM `phases/current_phase.md` — {TODAY} "
              f"(`MAKE_MEMORIES` {PASS})\n\n{note}\n\n")
    new_dest = dest_text.rstrip("\n") + "\n" + header + "".join(block) + "\n"
    return "".join(new_cp), new_dest, "".join(block)


head_cp, head_dest = git("show", f"HEAD:{CP}"), git("show", f"HEAD:{dest}")
work_cp, work_dest = open(CP).read(), open(dest).read()

i_cp, i_dest, i_block = transform(head_cp, head_dest)
w_cp, w_dest, w_block = transform(work_cp, work_dest)
if i_block != w_block:
    sys.exit("ABORT: block text differs between HEAD and working tree — demote by hand")

for path, text in ((CP, i_cp), (dest, i_dest)):
    blob = git("hash-object", "-w", "--stdin", inp=text).strip()
    git("update-index", "--cacheinfo", f"100644,{blob},{path}")
for path, text in ((CP, w_cp), (dest, w_dest)):
    open(path, "w").write(text)

n = i_block.count("\n")
print(f"staged: -{n} lines from {CP}, +block to {dest}; log row added. Heading: {i_block.splitlines()[0][:90]}")
