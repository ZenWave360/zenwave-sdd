# <Flow>: tasks

flow: <path of the .zfl file>
baseline:
branch: afk/<flow-file-name>

<!--
Format: board-format.md of zenwave-sdd. One vertical slice per path of the flow, S1 is the tracer bullet.
- [ ] pending  [/] in progress  [\] in review  [x] done  [!] blocked
- T-<nn> <mechanical|bounded|advanced> <AFK|HITL> <title>
  fields, six spaces in: model, test data, tests, adr, blocked by, blocked, done
Once the baseline is tagged, only the orchestrator edits this file.
-->

## S1 <end outcome> (tracer bullet)
path: <Start> > <command> > <Event> > <command>[<outcome>] > ... > end <outcome>
review: [ ]

- [ ] T-01 <difficulty> AFK <title>
      model: <file>:<lines>
      test data: <fixtures>
      tests: <focused tests>
