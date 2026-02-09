$ErrorActionPreference = 'Stop'

$schemaPaths = @()
if (Test-Path 'sql_archive\DATABASE_SCHEMA_LIVE_2026-02-09.sql') {
  $schemaPaths += 'sql_archive\DATABASE_SCHEMA_LIVE_2026-02-09.sql'
}
$schemaPaths += Get-ChildItem -File supabase\migrations -Filter *.sql | Sort-Object Name | Select-Object -ExpandProperty FullName

$schemaText = ($schemaPaths | ForEach-Object { Get-Content -Raw -Encoding UTF8 $_ }) -join "`n"

$objectSet = New-Object 'System.Collections.Generic.HashSet[string]'
$patterns = @(
  '(?im)^create\s+table\s+(?:if\s+not\s+exists\s+)?(?:"public"\.)?"?([a-zA-Z_][a-zA-Z0-9_]*)"?',
  '(?im)^create\s+(?:or\s+replace\s+)?view\s+(?:if\s+not\s+exists\s+)?(?:"public"\.)?"?([a-zA-Z_][a-zA-Z0-9_]*)"?',
  '(?im)^create\s+materialized\s+view\s+(?:if\s+not\s+exists\s+)?(?:"public"\.)?"?([a-zA-Z_][a-zA-Z0-9_]*)"?'
)

foreach ($pat in $patterns) {
  [regex]::Matches($schemaText, $pat) | ForEach-Object {
    [void]$objectSet.Add($_.Groups[1].Value.ToLowerInvariant())
  }
}

$runtimeFiles = @()
$runtimeFiles += Get-ChildItem -Recurse -File lib -Filter *.dart | Select-Object -ExpandProperty FullName
$excludeFunctionDirs = @(
  'backfill-achievement-icons',
  'backfill-game-covers',
  'bulk-update-platforms',
  'bulk-update-rarity',
  'force-stop-syncs',
  'generate-achievement-guide',
  'get-users',
  'moderate-content',
  'test-psn-auth',
  'youtube-search'
)
$runtimeFiles += Get-ChildItem -Directory supabase\functions | Where-Object {
  $excludeFunctionDirs -notcontains $_.Name
} | ForEach-Object {
  $p = Join-Path $_.FullName 'index.ts'
  if (Test-Path $p) { $p }
}
if (Test-Path 'sync-service\index.js') { $runtimeFiles += (Resolve-Path 'sync-service\index.js').Path }

$refs = New-Object System.Collections.ArrayList
$refRegex = [regex]'\.from\(\s*[''\"]([^''\"]+)[''\"]\s*\)'

foreach ($file in $runtimeFiles) {
  $lines = Get-Content -Encoding UTF8 $file
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '\.storage\.from\(') { continue }
    $matches = $refRegex.Matches($line)
    foreach ($m in $matches) {
      $relativePath = (Resolve-Path -Relative $file).ToString().TrimStart('.','\').Replace('\','/')
      $item = [PSCustomObject]@{
        object = $m.Groups[1].Value.ToLowerInvariant()
        file = $relativePath
        line = $i + 1
        text = $line.Trim()
      }
      [void]$refs.Add($item)
    }
  }
}

$refObjects = $refs | Select-Object -ExpandProperty object -Unique | Sort-Object
$missing = $refObjects | Where-Object { -not $objectSet.Contains($_) } | Sort-Object

$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine('# Active-Only Mismatch Report')
$null = $sb.AppendLine()
$null = $sb.AppendLine('Generated: 2026-02-09')
$null = $sb.AppendLine('Source schema: `sql_archive/DATABASE_SCHEMA_LIVE_2026-02-09.sql`')
$null = $sb.AppendLine('Compat delta included: all files in `supabase/migrations/*.sql`')
$null = $sb.AppendLine()
$null = $sb.AppendLine('## Runtime Scope Included')
$null = $sb.AppendLine('- Flutter runtime files under `lib/`')
$null = $sb.AppendLine('- Active edge function entrypoints `supabase/functions/*/index.ts`')
$null = $sb.AppendLine('- `sync-service/index.js` API surface')
$null = $sb.AppendLine()
$null = $sb.AppendLine('## Runtime Scope Excluded')
$null = $sb.AppendLine('- `legacy/` archive files')
$null = $sb.AppendLine('- `index-old/index-clean/index-backup` files')
$null = $sb.AppendLine('- one-off backfill/admin helper scripts')
$null = $sb.AppendLine()
$null = $sb.AppendLine('## Active Runtime Objects Missing From Schema')
if ($missing.Count -eq 0) {
  $null = $sb.AppendLine('- None')
} else {
  foreach ($m in $missing) { $null = $sb.AppendLine("- $m") }
}
$null = $sb.AppendLine()
$null = $sb.AppendLine('## Active Runtime Reference Lines (Missing Objects Only)')
if ($missing.Count -eq 0) {
  $null = $sb.AppendLine('- None')
} else {
  foreach ($m in $missing) {
    $null = $sb.AppendLine("### $m")
    $rows = $refs | Where-Object { $_.object -eq $m } | Sort-Object file,line
    foreach ($r in $rows) {
      $null = $sb.AppendLine(("- {0}:{1}: {2}" -f $r.file, $r.line, $r.text))
    }
    $null = $sb.AppendLine()
  }
}

$null = $sb.AppendLine('## Notes')
$null = $sb.AppendLine('- Missing objects here are code references not found in the schema dump plus compat migration text.')
$null = $sb.AppendLine('- This report does not assert runtime failure by itself; some references may be behind guarded code paths.')

Set-Content -Encoding UTF8 docs\ACTIVE_ONLY_MISMATCHES_2026-02-09.md $sb.ToString()

Write-Output 'WROTE docs/ACTIVE_ONLY_MISMATCHES_2026-02-09.md'
Write-Output ('MISSING_COUNT=' + $missing.Count)
if ($missing.Count -gt 0) { $missing }
