#!/usr/bin/env bash
# Lint ZDL files with the ZenWave `Lint` plugin, one `jbang zw` run per file.
#
# Usage:
#   lint-zdl.sh [--strict] [--out <dir>] <file.zdl|dir>... [-- <extra Lint options>]
#     --strict   warnings (data lineage, mixed event binding) also fail the run
#     --out      report directory (default: target/zdl-lint)
#     <dir>      expands to its *.zdl files, skipping target/
#     --         everything after is passed to the Lint plugin, e.g. linters=... (it REPLACES the default set)
#   Set ZW_DEPS (e.g. com.acme:zw-linters) to add custom linter jars: jbang zw -d $ZW_DEPS.
#
# Per file: <out>/<name>.json (report) and <out>/<name>.stderr.log (deleted when the run exits 0).
# Stdout: one line per file: OK | FINDINGS -> report | FAILED (exit n) -> stderr log
# Exit code: 2 if any run returned >= 2 (tooling failure), else 1 if any returned 1, else 0.
set -uo pipefail

STRICT=false
OUT="target/zdl-lint"
INPUTS=()
EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=true; shift ;;
    --out) OUT="${2:?--out needs a directory}"; shift 2 ;;
    --) shift; EXTRA=("$@"); break ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) INPUTS+=("$1"); shift ;;
  esac
done
[[ ${#INPUTS[@]} -gt 0 ]] || { echo "usage: lint-zdl.sh [--strict] [--out <dir>] <file.zdl|dir>... [-- <extra Lint options>]" >&2; exit 2; }

FILES=()
for in in "${INPUTS[@]}"; do
  if [[ -d "$in" ]]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(find "$in" -name target -prune -o -name '*.zdl' -type f -print | sort)
  else
    FILES+=("$in")   # a missing path is passed through on purpose: Lint reports it as exit 2
  fi
done
[[ ${#FILES[@]} -gt 0 ]] || { echo "no .zdl files found" >&2; exit 2; }

mkdir -p "$OUT"
DEPS=()
[[ -n "${ZW_DEPS:-}" ]] && DEPS=(-d "$ZW_DEPS")

WORST=0
for f in "${FILES[@]}"; do
  name="$(basename "${f%.zdl}")"
  report="$OUT/$name.json"
  errlog="$OUT/$name.stderr.log"
  jbang zw "${DEPS[@]}" -p Lint "zdlFile=$f" format=json "strict=$STRICT" "${EXTRA[@]}" >"$report" 2>"$errlog"
  code=$?
  case $code in
    0) echo "$f: OK"; rm -f "$errlog" ;;
    1) echo "$f: FINDINGS -> $report" ;;
    *) echo "$f: FAILED (exit $code) -> $errlog" ;;
  esac
  if (( code >= 2 )); then WORST=2; elif (( code == 1 && WORST < 2 )); then WORST=1; fi
done
exit $WORST
