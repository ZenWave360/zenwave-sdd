# Runs one Codex task and recovers it after a plan usage limit.
#   Start:   codex-task.ps1 -Name px5-1 -Cwd <repo> -PromptFile <md> [-Model m] [-Effort e] [-AddDir d1,d2] [-Summary <md>]
#   Recover: codex-task.ps1 -Name px5-1 -Recover      (waits for the reset, then resumes or hands off once)
# Pass absolute -Cwd, -PromptFile, -Summary and -AddDir: relative ones fail inside Codex ("os error 3").
# -Summary must be a writable file path: it becomes --output-last-message, and DONE requires the file to exist.
# Run it from the PowerShell tool, not 'powershell -File' from Git Bash, where the execution policy blocks scripts.
# State: <handoff>/codex-tasks/<name>.json. Events: <name>-<attempt>.jsonl beside it.
param(
  [Parameter(Mandatory)][string]$Name,
  [string]$Cwd, [string]$PromptFile, [string]$Summary,
  [string]$Model = 'gpt-5.6-terra', [string]$Effort = 'medium', [string[]]$AddDir = @(),
  [switch]$Recover,
  [int]$ResumeMaxItems = 80
)
# 'powershell -File' passes a list as one comma-separated string.
$AddDir = @($AddDir | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
# Not 'Stop': PowerShell 5.1 turns any native stderr line (Codex logs warnings there) into a terminating error.
# Failures are read from the JSON events instead.
$ErrorActionPreference = 'Continue'
# Task state lives in $env:AGENT_HANDOFF_DIR\codex-tasks, else .handoff\codex-tasks under the current directory.
$root = if ($env:AGENT_HANDOFF_DIR) { Join-Path $env:AGENT_HANDOFF_DIR 'codex-tasks' } else { Join-Path (Get-Location) '.handoff\codex-tasks' }
New-Item -ItemType Directory -Force $root | Out-Null
$statePath = Join-Path $root "$Name.json"
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Save($s) { [IO.File]::WriteAllText($statePath, ($s | ConvertTo-Json -Depth 6), $utf8) }
function Load { Get-Content $statePath -Raw | ConvertFrom-Json }
function Note($s, $text) { $s.history += "$(Get-Date -Format s) $text"; Save $s }

# Reads one attempt's events: thread id, completion, usage, the failure text and the number of items.
function Read-Events($path) {
  $r = [ordered]@{ thread = $null; completed = $false; failed = $null; usage = $null; items = 0; lastMessage = $null }
  foreach ($line in Get-Content $path -ErrorAction SilentlyContinue) {
    try { $e = $line | ConvertFrom-Json } catch { continue }
    switch ($e.type) {
      'thread.started' { $r.thread = $e.thread_id }
      'turn.completed' { $r.completed = $true; $r.usage = $e.usage }
      'turn.failed'    { $r.failed = $e.error.message }
      'error'          { if (-not $r.failed) { $r.failed = $e.message } }
      'item.completed' { $r.items++; if ($e.item.type -eq 'agent_message') { $r.lastMessage = $e.item.text } }
    }
  }
  $r
}

# usage = plan quota; rate = transient; context = context window; other = anything else.
function Classify($message) {
  if (-not $message) { return 'other' }
  if ($message -match 'usage limit') { return 'usage' }
  if ($message -match 'context (window|length)|maximum context') { return 'context' }
  if ($message -match 'rate limit|429|too many requests') { return 'rate' }
  'other'
}

# "try again at 9:39 AM" -> the next such local time; null when absent.
function Reset-Time($message) {
  if ($message -notmatch 'try again at (\d{1,2}):(\d{2})\s*([AP]M)') { return $null }
  $h = [int]$Matches[1] % 12; if ($Matches[3] -eq 'PM') { $h += 12 }
  $t = (Get-Date).Date.AddHours($h).AddMinutes([int]$Matches[2])
  if ($t -le (Get-Date)) { $t = $t.AddDays(1) }
  $t
}

function Invoke-Codex($s, [string[]]$codexArgs, [string]$prompt, [string]$strategy) {
  $s.attempt++
  $events = Join-Path $root "$Name-$($s.attempt).jsonl"
  $s.status = 'RUNNING'; $s.lastEvents = $events; Note $s "attempt $($s.attempt): $strategy"
  Push-Location $s.cwd
  # PowerShell 5.1 turns any native stderr line into a terminating error under 'Stop'; Codex logs warnings there.
  $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $prompt | & codex @codexArgs > $events 2> "$events.stderr" } finally { $ErrorActionPreference = $previous; Pop-Location }
  $r = Read-Events $events
  if ($r.thread -and -not $s.thread) { $s.thread = $r.thread }
  if ($r.usage) { $s.usage += [pscustomobject]@{ attempt = $s.attempt; strategy = $strategy; usage = $r.usage } }
  $s.items += $r.items
  $kind = if ($r.completed) { 'done' } else { Classify $r.failed }
  switch ($kind) {
    'done' {
      # A clean exit is not enough: the turn completed and the summary file was written.
      if ($s.summary -and -not (Test-Path $s.summary)) { $s.status = 'FAILED'; Note $s 'turn completed without a summary file' }
      else { $s.status = 'DONE'; Note $s 'done' }
    }
    'usage' {
      $at = Reset-Time $r.failed
      if (-not $at) { $backoff = @(30, 60, 120)[[Math]::Min($s.quotaWaits, 2)]; $at = (Get-Date).AddMinutes($backoff) }
      $s.quotaWaits++; $s.status = 'WAITING_FOR_QUOTA'; $s.resetAt = $at.ToString('s'); Note $s "usage limit; retry at $($s.resetAt)"
    }
    'rate'    { $s.status = 'WAITING_FOR_QUOTA'; $s.resetAt = (Get-Date).AddMinutes(5).ToString('s'); Note $s 'rate limit; retry in 5 min' }
    'context' { $s.status = 'NEEDS_HANDOFF'; Note $s 'context window exhausted' }
    default   { $s.status = 'FAILED'; Note $s "failed: $($r.failed)" }
  }
}

function Base-Args($s) {
  $a = @('exec', '-C', $s.cwd)
  foreach ($d in $s.addDir) { $a += @('--add-dir', $d) }
  $a += @('--model', $s.model, '--config', "model_reasoning_effort=`"$($s.effort)`"", '--approve-for-me', '--json')
  if ($s.summary) { $a += @('--output-last-message', $s.summary) }
  $a + @('-')
}

# Built locally, without model tokens: objective from the original prompt, the tree's state, the last agent message.
function Handoff($s) {
  $last = (Read-Events $s.lastEvents).lastMessage
  $status = (git -C $s.cwd status --short) -join "`n"
  $stat = (git -C $s.cwd diff --stat) -join "`n"
  @"
You are continuing a task another Codex session started and could not finish (it stopped at a plan usage limit).
Do not redo completed work: inspect the working tree first and build on the uncommitted changes.

## Original task
$(Get-Content $s.promptFile -Raw)

## State of the working tree when it stopped
git status --short:
$status

git diff --stat:
$stat

## Last message of the previous session
$(if ($last) { $last } else { '(none)' })

Finish the task and its verification, and end with the final summary the original task asks for.
"@
}

if (-not $Recover) {
  if ((Test-Path $statePath) -and (Load).status -ne 'FAILED') { throw "Task $Name already exists with status $((Load).status)." }
  $s = [pscustomobject]@{ name = $Name; cwd = $Cwd; promptFile = $PromptFile; summary = $Summary; model = $Model; effort = $Effort
    addDir = @($AddDir); status = 'NEW'; thread = $null; attempt = 0; items = 0; quotaWaits = 0; resetAt = $null
    strategy = $null; recovered = $false; lastEvents = $null; usage = @(); history = @() }
  Save $s
  Invoke-Codex $s (Base-Args $s) (Get-Content $PromptFile -Raw) 'run'
}

$s = Load
while ($s.status -eq 'WAITING_FOR_QUOTA') {
  $wait = ([datetime]$s.resetAt - (Get-Date)).TotalSeconds
  if ($wait -gt 0) { Note $s "sleeping $([int]$wait) s until $($s.resetAt)"; Start-Sleep -Seconds ([int]$wait + 60) }
  # Cheap probe before the expensive recovery.
  $probe = 'Reply with OK only.' | & codex exec --skip-git-repo-check --ephemeral --json - 2>$null
  $probeFailure = ($probe | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} } | Where-Object { $_.type -eq 'turn.failed' } | Select-Object -First 1)
  if ($probeFailure -and (Classify $probeFailure.error.message) -eq 'usage') {
    $at = Reset-Time $probeFailure.error.message; if (-not $at) { $at = (Get-Date).AddMinutes(30) }
    $s.resetAt = $at.ToString('s'); Note $s "probe still limited; retry at $($s.resetAt)"; continue
  }
  # One strategy per task, chosen once and recorded: resume a short session, hand off a long one.
  if (-not $s.strategy) { $s.strategy = if ($s.thread -and $s.items -le $ResumeMaxItems) { 'resume' } else { 'handoff' }; Note $s "strategy: $($s.strategy) ($($s.items) items)" }
  if ($s.strategy -eq 'resume') {
    # $a = @('exec', 'resume', $s.thread, '--json', '-c', 'approval_policy="never"', '-c', 'sandbox_mode="workspace-write"', '-m', $s.model)
    $a = @('exec', 'resume', $s.thread, '--json', '-c', 'approval_policy="never"', '-c', 'sandbox_mode="workspace-write"', '-c', 'sandbox_permissions=["disk-full-read-access"]', '-m', $s.model)
    if ($s.summary) { $a += @('-o', $s.summary) }
    $a += '-'
    Invoke-Codex $s $a 'The session stopped at a usage limit. Continue the task from where you stopped. Check the working tree first, do not redo completed work, finish the verification, and end with the final summary the task asks for.' 'resume'
  } else {
    Invoke-Codex $s (Base-Args $s) (Handoff $s) 'handoff'
  }
  $s = Load
}
if ($s.status -eq 'NEEDS_HANDOFF' -and -not $s.recovered) {
  $s.recovered = $true; $s.strategy = 'handoff'; Save $s
  Invoke-Codex $s (Base-Args $s) (Handoff $s) 'handoff after context exhaustion'
  $s = Load
}
"$Name $($s.status) after $($s.attempt) attempt(s), strategy $($s.strategy)"
