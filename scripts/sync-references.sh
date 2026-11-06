#!/usr/bin/env bash
# Copies the shared material in templates/ into the references/ of every skill that links to it.
# Skills are installed one by one (npx skills, plugin), so each carries its own copy.
#   scripts/sync-references.sh          copy
#   scripts/sync-references.sh --check  fail if any copy differs (for CI)
set -euo pipefail
cd "$(dirname "$0")/.."

# Files, copied when SKILL.md links references/<file>.
shared=(board-format.md proposal-format.md grilling.md glossary-format.md adr-format.md generated-code.md)
# Folders, copied whole when SKILL.md links anything under references/<folder>/, or when grilling.md is used
# (it links into both).
folders=(zenwave-languages grilling)
check=false; [[ "${1:-}" == "--check" ]] && check=true
status=0

sync_file() {   # sync_file <source> <target>
  if $check; then cmp -s "$1" "$2" || { echo "out of date: $2"; status=1; }
  else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; fi
}
sync_folder() { # sync_folder <name> <skill>
  local f
  while IFS= read -r f; do sync_file "templates/$1/$f" "$2/references/$1/$f"; done \
    < <(cd "templates/$1" && find . -type f | sed 's#^\./##')
}

for skill in skills/*/; do
  skill=${skill%/}
  used=""
  for f in "${shared[@]}"; do
    grep -q "references/$f" "$skill/SKILL.md" 2>/dev/null || continue
    sync_file "templates/$f" "$skill/references/$f"; used+=" $f"
  done
  for d in "${folders[@]}"; do
    if grep -q "references/$d/" "$skill/SKILL.md" 2>/dev/null || [[ "$used" == *" grilling.md"* ]]; then
      sync_folder "$d" "$skill"; used+=" $d/"
    fi
  done
  if ! $check && [[ -n "$used" ]]; then echo "synced $skill:$used"; fi
done
exit $status
