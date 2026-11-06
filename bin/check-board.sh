#!/usr/bin/env bash
# Checks the format and the graph of a task board (docs/tasks.md): the header, slices, task lines and fields, unique
# ids, blockers that exist, no task blocked by a task of a later slice, and no cycles.
#
#   check-board.sh [docs/tasks.md]
#
# Exit code: 0 valid (warnings are printed and do not fail), 1 errors. The format is in templates/board-format.md.
set -u
BOARD=${1:-docs/tasks.md}
[[ -f "$BOARD" ]] || { echo "no board at $BOARD" >&2; exit 2; }

errors=$(awk '
  { sub(/\r$/, "") }
  function err(m) { print "line " NR ": " m; bad = 1 }
  NR == 1 && !/^# .+: tasks$/ { err("the first line must be \"# <Flow>: tasks\"") }
  /^flow:/ { flow = 1 } /^branch:/ { branch = 1 }
  /^## / { if ($0 !~ /^## S[0-9]+ .+/) err("a slice heading is \"## S<n> <name>\""); else { ns++; slice[$2] = ns; cur = $2; hasreview[cur] = 0 } next }
  /^review:/ { if (cur == "") err("review: outside a slice"); else if ($0 !~ /^review: \[[ \/x!]\]/) err("review: [ ] | [/] | [x] | [!]"); hasreview[cur] = 1; next }
  /^- \[/ {
    if ($0 !~ /^- \[[ \/\\x!]\] T-[0-9]+ (mechanical|bounded|advanced) (AFK|HITL) [^ ]/) { err("a task is \"- [ ] T-<nn> <mechanical|bounded|advanced> <AFK|HITL> <title>\""); next }
    if (cur == "") err("a task outside a slice")
    id = substr($0, 7); sub(/ .*/, "", id)
    if (id in sliceof) { err(id " is repeated"); task = ""; next }
    sliceof[id] = cur; order[++nt] = id; split(substr($0, 7), f, " "); type[id] = f[3]; task = id; next
  }
  /^      [a-z ]+:/ {
    if (task == "") { err("a field outside a task"); next }
    line = $0; sub(/^ +/, "", line); key = line; sub(/:.*/, "", key)
    if (key !~ /^(model|test data|tests|adr|blocked by|blocked|fixes|done)$/) err("unknown field \"" key "\"")
    if (key == "model") model[task] = 1
    if (key == "blocked by") { v = line; sub(/^blocked by: */, "", v); deps[task] = v }
    next
  }
  /^[^ <]/ && !/^(path|flow|baseline|branch):/ && !/^#/ && !/^-->/ { task = "" }
  /^$/ { task = "" }
  END {
    if (!flow) err("no flow: line"); if (!branch) err("no branch: line")
    if (ns == 0) err("no slices")
    for (s in hasreview) if (!hasreview[s]) print "slice " s ": no review: line"
    for (i = 1; i <= nt; i++) {
      t = order[i]
      if (type[t] == "AFK" && !model[t] && sliceof[t] != "S0") print t ": an AFK task without model: lines (warning)"
      n = split(deps[t], d, /[ ,]+/)
      for (j = 1; j <= n; j++) {
        if (d[j] !~ /^T-/) continue
        if (!(d[j] in sliceof)) { print t ": blocked by " d[j] ", which does not exist"; bad = 1; continue }
        if (slice[sliceof[d[j]]] > slice[sliceof[t]]) { print t ": blocked by " d[j] " of a later slice"; bad = 1 }
        edge[t, ++ne[t]] = d[j]
      }
    }
    left = nt
    do { changed = 0
      for (i = 1; i <= nt; i++) { t = order[i]; if (gone[t]) continue; ok = 1
        for (j = 1; j <= ne[t]; j++) if (!gone[edge[t, j]]) ok = 0
        if (ok) { gone[t] = 1; left--; changed = 1 } }
    } while (changed)
    if (left > 0) { for (i = 1; i <= nt; i++) if (!gone[order[i]]) c = c " " order[i]; print "a cycle among:" c; bad = 1 }
    exit bad
  }' "$BOARD")
rc=$?
[[ -n "$errors" ]] && echo "$errors"
(( rc == 0 )) && echo "board OK: $(grep -c '^- \[' "$BOARD") tasks in $(grep -c '^## S' "$BOARD") slices"
exit $rc
