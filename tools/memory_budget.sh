#!/bin/bash
# memory_budget.sh - MAKE_MEMORIES step 0. Measures the NUMBERS the boot spec constrains and exits 1 if any is over.
# (Added with the Nov 24, 2026 memory diet. A spec that states a number is enforced only if something PRINTS that number.)
# Usage (repo root):  bash tools/memory_budget.sh [dir-with-new-files]   # default: the live files
cd "$(dirname "$0")/.." || exit 1
D="${1:-.}"
MEM="$D/MEMORY.md"; IDX="$D/phases/INDEX.md"; CP="$D/phases/current_phase.md"; SEC="$D/MEMORY_SECRET.md"
[ "$D" != "." ] && { MEM="$D/MEMORY.new.md"; IDX="$D/INDEX.new.md"; CP="$D/RESUME.new.md"; SEC="$D/MEMORY_SECRET.new.md"; }
fail=0
chk() { # name value limit unit
  if [ "$2" -gt "$3" ]; then printf '  ✗ %-34s %7s %s  > limit %s\n' "$1" "$2" "$4" "$3"; fail=1
  else printf '  ✓ %-34s %7s %s  (limit %s)\n' "$1" "$2" "$4" "$3"; fi
}
echo "memory budget ($D)"
chk "MEMORY.md (core) bytes"          "$(wc -c < "$MEM")" 30720 B
chk "MEMORY.md single-read < 100000"  "$(wc -c < "$MEM")" 99999 B
[ -f "$IDX" ] && { chk "INDEX bytes" "$(wc -c < "$IDX")" 8192 B
  chk "INDEX largest row" "$(awk '/^\|/{l=length($0); if(l>m)m=l} END{print m+0}' "$IDX")" 400 B; } || { echo "  ✗ INDEX missing"; fail=1; }
if [ "$D" = "." ]; then
  chk "RESUME HERE block bytes" "$(awk '/^## ▶️ RESUME HERE/{f=1;next} /^## /{f=0} f' "$CP" | wc -c)" 6144 B
  chk "current_phase.md blocks (## )"  "$(grep -c '^## ' "$CP")" 3 blocks
else
  chk "RESUME HERE block bytes" "$(wc -c < "$CP")" 6144 B
fi
chk "MEMORY_SECRET.md bytes"          "$(wc -c < "$SEC")" 8192 B
[ $fail -eq 0 ] && echo "  ✅ within budget" || echo "  🚨 OVER BUDGET — demote before finishing this pass (MAKE_MEMORIES step 2)"
exit $fail
