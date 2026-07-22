<#
Compact find/replace tool
- Features: verbatim replacements (handles \ $ #), literal/regex mode, BOM-aware encoding preservation,
  per-find counts, per-file diffs in dry-run, backups, atomic writes with retries, timestamped log.
- Edit only the CONFIG block below (inline comments explain each setting).
- Run elevated if you expect permission issues on network shares.
#>

# --- CONFIG (edit only) ---
$Path = "N:\Replication_Configration_Scriptout"    # root folder to scan
$Include = @('*.sql','*.out')                      # file patterns to include
$DryRun = $true                                    # $true = preview; $false = apply changes
$Finds = @(                                         # each entry is a literal or regex (see $UseRegex)
  "PRPCSQL02",
  "PRICSQL02",
  "@job_login = N'INJURYSCIENCES\SQLService', @job_password = null"
)
$Replaces = @(                                      # verbatim replacements (no special $ or \ handling)
  "DRPCSQL02",
  "DRICSQL02",
  "@job_login = N'INJURYSCIENCES\SQLService', @job_password = '<<<>>>'"
)
$UseRegex = $false                                  # $true = treat $Finds as regex patterns
$CaseSensitive = $false                             # $false = case-insensitive matching
$BackupFolder = "$Path\_backups"                    # where backups are stored
$LogFolder = "$Path\_logs"                          # where logs are stored
$MaxWriteRetries = 3                                # retry attempts for writes
$WriteRetryDelaySec = 2                             # delay between retries
# --- END CONFIG ---

# --- Setup ---
if (-not (Test-Path $Path)) { Write-Host "Path not found: $Path" -ForegroundColor Red; exit }
if ($Finds.Count -ne $Replaces.Count) { Write-Host "Finds and Replaces must be same length" -ForegroundColor Red; exit }
New-Item -Path $BackupFolder -ItemType Directory -Force | Out-Null
New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
$opts = [System.Text.RegularExpressions.RegexOptions]::None
if (-not $CaseSensitive) { $opts = $opts -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
$logFile = Join-Path $LogFolder ("replace_log_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
"Log start: $(Get-Date -Format o)" | Out-File -FilePath $logFile -Encoding UTF8

# --- Helpers (compact) ---
function Log($msg, $color='White') { Write-Host $msg -ForegroundColor $color; "$(Get-Date -Format o) $msg" | Out-File -FilePath $logFile -Append -Encoding UTF8 }
function Detect-EncodingAndPreamble([byte[]]$b) {
  if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { return @{Enc=[System.Text.Encoding]::UTF8;P=3} }
  if ($b.Length -ge 2 -and $b[0] -eq 0xFF -and $b[1] -eq 0xFE) { return @{Enc=[System.Text.Encoding]::Unicode;P=2} }
  if ($b.Length -ge 2 -and $b[0] -eq 0xFE -and $b[1] -eq 0xFF) { return @{Enc=[System.Text.Encoding]::BigEndianUnicode;P=2} }
  if ($b.Length -ge 4 -and $b[0] -eq 0x00 -and $b[1] -eq 0x00 -and $b[2] -eq 0xFE -and $b[3] -eq 0xFF) { $e=[System.Text.Encoding]::GetEncoding("utf-32BE"); return @{Enc=$e;P=4} }
  return @{Enc=[System.Text.Encoding]::UTF8;P=0}
}
function Read-WithEncoding($p) {
  $b = [System.IO.File]::ReadAllBytes($p)
  $info = Detect-EncodingAndPreamble $b
  $enc = $info.Enc; $pLen = $info.P
  if ($pLen -ge $b.Length) { return ,@("","$enc") }
  $txt = $enc.GetString($b[$pLen..($b.Length-1)])
  return ,@($txt,$enc)
}
function Write-WithEncoding($p,$txt,[System.Text.Encoding]$enc) {
  $pre = $enc.GetPreamble(); $body = $enc.GetBytes($txt)
  $out = New-Object byte[] ($pre.Length + $body.Length)
  [Array]::Copy($pre,0,$out,0,$pre.Length); [Array]::Copy($body,0,$out,$pre.Length,$body.Length)
  [System.IO.File]::WriteAllBytes($p,$out)
}
function Test-Write($p) { try { $fs=[System.IO.File]::Open($p,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None); $fs.Close(); $true } catch { $false } }
function Replace-Verbatim($text,$find,$replace,$useRegex,$opts) {
  if ($useRegex) { $e=[System.Text.RegularExpressions.MatchEvaluator]{ param($m) return $replace }; return [regex]::Replace($text,$find,$e,$opts) }
  $pat=[regex]::Escape($find); $e=[System.Text.RegularExpressions.MatchEvaluator]{ param($m) return $replace }; return [regex]::Replace($text,$pat,$e,$opts)
}
function Diff-Compact($old,$new,$max=200) {
  $d = Compare-Object -ReferenceObject $old -DifferenceObject $new -IncludeEqual -SyncWindow 0
  $L = New-Object System.Collections.Generic.List[string]
  foreach ($x in $d) { if ($x.SideIndicator -eq "==") { continue } ; if ($x.SideIndicator -eq "<=") { $L.Add("- "+$x.InputObject) } elseif ($x.SideIndicator -eq "=>") { $L.Add("+ "+$x.InputObject) } ; if ($L.Count -ge $max) { $L.Add("... diff truncated ..."); break } }
  return $L
}

# --- State trackers ---
$totFiles=0; $totMatches=0
$planned=@(); $changed=@(); $skipped=@()
# per-find totals (initialize)
$findTotals = for ($i=0; $i -lt $Finds.Count; $i++) { 0 }
$findReplaced = for ($i=0; $i -lt $Finds.Count; $i++) { 0 }

# --- Main loop (compact) ---
Get-ChildItem -Path $Path -Recurse -File -Include $Include -ErrorAction SilentlyContinue |
ForEach-Object {
  $totFiles++; $file=$_.FullName
  try { $pair = Read-WithEncoding $file; $text=$pair[0]; $enc=$pair[1] } catch { Log "Failed to read: $file — $($_.Exception.Message)" Red; $skipped += [pscustomobject]@{File=$file;Reason="Read failed"}; continue }
  $new=$text; $fileMatches=0
  Log "Scanning: $file" Cyan

  for ($i=0; $i -lt $Finds.Count; $i++) {
    $find=$Finds[$i]; $replace=$Replaces[$i]
    $pat = if ($UseRegex) { $find } else { [regex]::Escape($find) }
    $m = [regex]::Matches($new,$pat,$opts).Count
    if ($m -gt 0) { $fileMatches += $m; $findTotals[$i] += $m; $new = Replace-Verbatim $new $find $replace $UseRegex $opts; $findReplaced[$i] += $m }
    $label = if ($UseRegex) { "Pattern" } else { "Literal" }
    $col = if ($m -gt 0) { 'Yellow' } else { 'DarkGray' }
    Log ("  $label $($i+1): $m match(es)") $col
  }

  if ($fileMatches -gt 0) {
    $totMatches += $fileMatches
    if ($DryRun) {
      $planned += [pscustomobject]@{File=$file;Replacements=$fileMatches}
      Log "  Dry-run: file would be modified." Magenta
      $old = $text -split "`r?`n"; $newLines = $new -split "`r?`n"
      $diff = Diff-Compact $old $newLines 200
      if ($diff.Count -gt 0) { Log "  Diff (compact):" Magenta; foreach ($l in $diff) { Log "    $l" Magenta } } else { Log "  Diff: (no line-level differences detected)" DarkGray }
    } else {
      try { $bak = Join-Path $BackupFolder ("{0}_{1}.bak" -f ([IO.Path]::GetFileName($file)), (Get-Date -Format "yyyyMMdd_HHmmss")); Copy-Item -LiteralPath $file -Destination $bak -Force -ErrorAction Stop; Log "  Backup: $bak" DarkCyan } catch { Log "  Backup failed: $($_.Exception.Message)" Red; $skipped += [pscustomobject]@{File=$file;Reason="Backup failed"}; continue }
      try { $it = Get-Item -LiteralPath $file; if ($it.Attributes -band [IO.FileAttributes]::ReadOnly) { $it.Attributes = $it.Attributes -bxor [IO.FileAttributes]::ReadOnly; Log "  Read-only removed" DarkYellow } } catch { Log "  Attr change failed" Red }
      if (-not (Test-Write $file)) { Log "  No write access / locked" Red; $skipped += [pscustomobject]@{File=$file;Reason="Locked/no write"}; continue }
      $tmp = "$file.tmp.$([guid]::NewGuid().ToString())"; $wrote=$false
      for ($a=1; $a -le $MaxWriteRetries; $a++) {
        try { Write-WithEncoding $tmp $new $enc; Move-Item -LiteralPath $tmp -Destination $file -Force; $wrote=$true; break } catch { Start-Sleep -Seconds $WriteRetryDelaySec }
      }
      if ($wrote) { Log "  File updated." Green; $changed += [pscustomobject]@{File=$file;Replacements=$fileMatches;Backup=$bak} } else { Log "  Write failed" Red; try { Copy-Item -LiteralPath $bak -Destination $file -Force; Log "  Backup restored." DarkCyan } catch { Log "  Restore failed" Red }; $skipped += [pscustomobject]@{File=$file;Reason="Write failed"} }
    }
  } else {
    Log "  No matches." DarkGray
  }
  Log "" White
}

# --- Summary (compact + per-find totals) ---
Log "Summary:" Cyan
Log ("  Files scanned:       $totFiles") White
Log ("  Total matches found: $totMatches") Green

if ($DryRun) {
  Log ("  Files to be changed: {0}" -f $planned.Count) Magenta
  foreach ($p in $planned) { Log ("    {0}  —  {1} replacement(s)" -f $p.File, $p.Replacements) Magenta }
  Log "  Per-find planned totals:" Magenta
  for ($i=0; $i -lt $Finds.Count; $i++) { Log ("    [{0}] {1}  —  {2} match(es) to replace" -f ($i+1), $Finds[$i], $findTotals[$i]) Magenta }
  Log "  Mode: Dry-run (no files written). Set `$DryRun = $false to apply changes." Magenta
} else {
  Log ("  Files changed:       {0}" -f $changed.Count) Green
  foreach ($c in $changed) { Log ("    {0}  —  {1} replacement(s)  (backup: {2})" -f $c.File, $c.Replacements, $c.Backup) Green }
  Log ("  Files skipped:       {0}" -f $skipped.Count) Yellow
  foreach ($s in $skipped) { Log ("    {0}  —  {1}" -f $s.File, $s.Reason) Yellow }
  Log "  Per-find totals (matched -> replaced):" Green
  for ($i=0; $i -lt $Finds.Count; $i++) { Log ("    [{0}] {1}  —  matched: {2}  replaced: {3}" -f ($i+1), $Finds[$i], $findTotals[$i], $findReplaced[$i]) Green }
  Log "  Mode: Changes applied where possible." Green
}
Log "Log end: $(Get-Date -Format o)" White
