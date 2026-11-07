#!/usr/bin/env bash
# Installs zenwave-sdd into a project, or upgrades it: the skills for each agent, the orchestrator, implementer and
# reviewer agents, the ZDL and board checkers, and the templates the project does not have yet. Run it from the
# project's root:
#
#   bash <zenwave-sdd>/install.sh [--agents claude,codex,grok]
#
# What it owns, and replaces on every run: the zenwave-sdd skills in each agent's skills folder, the three agents in
# .claude/agents, .zenwave/bin, and the section between the zenwave-sdd markers of AGENTS.md.
# What it creates only when missing: docs/zenwave-sdd-overlay.md, .zenwave/routing.md, CLAUDE.md, AGENTS.md.
# Review the result with `git status` and `git diff`, then commit it.
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
agents=claude,codex,grok
while (( $# )); do
  case $1 in
    --agents) agents=$2; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument $1" >&2; exit 1 ;;
  esac
done

git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "run it from the root of the project's git repository" >&2; exit 1; }
[[ -z "$(git rev-parse --show-prefix)" ]] || { echo "run it from the root of the repository: $(git rev-parse --show-toplevel)" >&2; exit 1; }
[[ "$SRC" != "$(pwd)" ]] || { echo "run it from your project, not from zenwave-sdd" >&2; exit 1; }
version=$(git -C "$SRC" describe --tags --always --dirty 2>/dev/null || echo unknown)

done_list=()
note() { done_list+=("$*"); }

# replace_dir <source> <target>: the target becomes an exact copy (only for folders zenwave-sdd owns).
replace_dir() { rm -rf -- "$2"; mkdir -p "$(dirname "$2")"; cp -R "$1" "$2"; }

# Skills, into each agent's folder (copies: symlinks are unreliable on Windows).
for agent in ${agents//,/ }; do
  case $agent in
    claude) dir=.claude/skills ;;
    codex)  dir=.agents/skills ;;
    grok)   dir=.grok/skills ;;
    *) echo "unknown agent $agent (claude, codex, grok)" >&2; exit 1 ;;
  esac
  for skill in "$SRC"/skills/*/; do
    name=$(basename "$skill")
    replace_dir "$skill" "$dir/$name"
  done
  note "skills → $dir"
done

# Retired skills of earlier versions.
for dir in .claude/skills .agents/skills .grok/skills; do
  for old in zenwave-fill-gaps zenwave-gap-report zfl-to-zdl zenwave-tasks-from-generated; do
    [[ -d "$dir/$old" ]] && { rm -rf -- "${dir:?}/$old"; note "removed retired $dir/$old"; }
  done
done

# The orchestrator, implementer and reviewer (Claude Code reads .claude/agents).
if [[ ",$agents," == *",claude,"* ]]; then
  mkdir -p .claude/agents
  cp "$SRC"/agents/*.md .claude/agents/
  note "agents → .claude/agents (orchestrator, implementer, reviewer)"
fi

# The checkers, and the engine of earlier versions (zw-afk), which is gone.
mkdir -p .zenwave/bin
cp "$SRC/bin/lint-zdl.sh" .zenwave/bin/lint-zdl.sh && chmod +x .zenwave/bin/lint-zdl.sh
cp "$SRC/bin/check-board.sh" .zenwave/bin/check-board.sh && chmod +x .zenwave/bin/check-board.sh
note "checkers → .zenwave/bin (lint-zdl.sh, check-board.sh)"
for old in .zenwave/bin/zw-afk .zenwave/lib/zw-afk; do
  [[ -e "$old" ]] && { rm -rf -- "$old"; note "removed the retired $old"; }
done

# Templates, only when missing.
copy_new() { [[ -e "$2" ]] && return; mkdir -p "$(dirname "$2")"; cp "$1" "$2"; note "created $2: fill it in"; }
copy_new "$SRC/templates/project-overlay.md" docs/zenwave-sdd-overlay.md
copy_new "$SRC/templates/routing.md" .zenwave/routing.md
[[ -e .zenwave/afk.conf ]] && note "obsolete: .zenwave/afk.conf is replaced by .zenwave/routing.md; delete it when you have moved your choices over"
[[ -e CLAUDE.md ]] || { printf '@AGENTS.md\n' > CLAUDE.md; note "created CLAUDE.md"; }

# AGENTS.md: the zenwave-sdd section between markers, replaced on upgrade; the rest is the project's.
begin='<!-- zenwave-sdd: managed by install.sh, edit outside these markers -->'
end='<!-- /zenwave-sdd -->'
section=$(printf '%s\n%s\n%s\n' "$begin" "$(cat "$SRC/templates/AGENTS.md")" "$end")
if [[ ! -e AGENTS.md ]]; then
  printf '# Agent instructions\n\n%s\n' "$section" > AGENTS.md; note "created AGENTS.md"
elif grep -qF "$begin" AGENTS.md; then
  SECTION="$section" awk -v b="$begin" -v e="$end" '
    $0 == b { print ENVIRON["SECTION"]; skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }' AGENTS.md > AGENTS.md.tmp && mv AGENTS.md.tmp AGENTS.md
  note "updated the zenwave-sdd section of AGENTS.md"
else
  printf '\n%s\n' "$section" >> AGENTS.md; note "added the zenwave-sdd section to AGENTS.md"
fi

# The orchestrator's clones and handoff files are never committed.
touch .gitignore
[[ -s .gitignore && -n "$(tail -c 1 .gitignore)" ]] && printf '\n' >> .gitignore
for ignored in .zenwave/work/ .zenwave/handoff/; do
  grep -qxF "$ignored" .gitignore || { printf '%s\n' "$ignored" >> .gitignore; note "ignored $ignored"; }
done

echo "$version" > .zenwave/zenwave-sdd.version

# .zenwave/routing.md and .zenwave/bin are meant to be committed; warn when the project's own rules ignore them.
for kept in .zenwave/routing.md .zenwave/bin/lint-zdl.sh; do
  git check-ignore -q "$kept" && note "WARNING: $kept is ignored by .gitignore; un-ignore .zenwave/ (e.g. add !.zenwave) so it is committed"
done

echo "zenwave-sdd $version installed in $(pwd)"
printf '  - %s\n' "${done_list[@]}"
cat <<'EOF'

Next: fill in docs/zenwave-sdd-overlay.md, look at .zenwave/routing.md, review `git diff`, and commit.
Then follow the README of zenwave-sdd from "The HITL loop".
EOF
