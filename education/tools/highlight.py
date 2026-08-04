#!/usr/bin/env python3
"""Wrap chosen passages in the review-highlight span.

The marks live in the Markdown, not in the .docx, so they survive a rebuild.
Each anchor below must match exactly once or this refuses to write the file --
a silently-missed anchor would mean a highlight quietly disappearing from the
printed chapter, which is the one failure mode you would not notice.

Anchors are matched with apostrophes and quotes treated as wildcards, so the
list can be written with plain ASCII regardless of the typography in the file.

Usage:
    python3 highlight.py <chapter.md> <anchors.py>            # apply
    python3 highlight.py <chapter.md> <anchors.py> --check     # validate only
"""

import pathlib
import re
import sys

OPEN, CLOSE = "[", ']{custom-style="Key"}'


def anchor_re(s):
    out = []
    for ch in s:
        if ch in "'\u2018\u2019":
            out.append("['\u2018\u2019]")
        elif ch in '"\u201c\u201d':
            out.append('["\u201c\u201d]')
        elif ch in "-\u2010\u2011":
            out.append("[-\u2010\u2011]")
        else:
            out.append(re.escape(ch))
    return "".join(out)


def apply(text, anchors):
    problems = []
    for a in anchors:
        hits = list(re.finditer(anchor_re(a), text))
        if len(hits) != 1:
            problems.append(f"  {len(hits)} matches: {a[:70]!r}")
            continue
        m = hits[0]
        if CLOSE in text[m.end():m.end() + len(CLOSE)]:
            problems.append(f"  already highlighted: {a[:70]!r}")
            continue
        text = text[:m.start()] + OPEN + m.group(0) + CLOSE + text[m.end():]
    return text, problems


def prose_stats(text):
    """Rough share of prose that is highlighted. Code blocks, tables, headings
    and the self-test questions are excluded -- none of them get marked, so
    counting them would flatter the number."""
    body, in_code = [], False
    for line in text.splitlines():
        if line.startswith("```"):
            in_code = not in_code
            continue
        if in_code or line.startswith(("|", "#", "!", "---")):
            continue
        body.append(line)
    joined = "\n".join(body)
    marked = sum(len(m.group(1).split())
                 for m in re.finditer(r"\[([^\[\]]*)\]\{custom-style=\"Key\"\}",
                                      joined))
    clean = re.sub(r"\[([^\[\]]*)\]\{custom-style=\"Key\"\}", r"\1", joined)
    total = len(clean.split())
    return marked, total, (100.0 * marked / total if total else 0.0)


def main():
    md = pathlib.Path(sys.argv[1])
    check = "--check" in sys.argv
    ns = {}
    exec(pathlib.Path(sys.argv[2]).read_text(), ns)
    text, problems = apply(md.read_text(), ns["ANCHORS"])
    if problems:
        verb = "would refuse to write" if check else "refusing to write"
        print(f"{md.name}: {verb}\n" + "\n".join(problems))
        return 1
    if not check:
        md.write_text(text)
    marked, total, pct = prose_stats(text)
    print(f"{md.name}: {'OK ' if check else ''}{len(ns['ANCHORS'])} highlights, "
          f"{marked}/{total} prose words = {pct:.1f}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
