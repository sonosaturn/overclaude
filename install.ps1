[CmdletBinding()]
param([switch]$DryRun, [switch]$Check, [string]$Personal)
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
function Run($cmd) { if ($DryRun) { Write-Output $cmd } else { Invoke-Expression $cmd } }
if ($DryRun) { Write-Output "=== DRY-RUN: no changes ===" }
if ($Check) { & "$Here/verify.ps1"; exit $LASTEXITCODE }

foreach ($line in Get-Content "$Here/lib/components.manifest") {
  if ($line -match '^\s*#' -or $line -notmatch '\|') { continue }
  $t, $name, $arg = $line.Split('|', 3)
  switch ($t) {
    'plugin'     { Run "claude plugin marketplace add $arg"; Run "claude plugin install ${name}@${name}" }
    'mcp'        { Run "claude mcp add $name -- $arg" }
    'cmd'        { Run "$arg" }
    'npm-global' { Run "npm install -g $arg" }
    'uv-tool'    { Run "uv tool install $arg" }
    'skills-cli' { Run "npx skills@latest add $arg" }
  }
}
Run "claude plugin marketplace add `"$Here`""
Run "claude plugin install overclaude@overclaude"

$settings = Join-Path $HOME '.claude/settings.json'
New-Item -ItemType Directory -Force -Path (Split-Path $settings) | Out-Null
if ($DryRun) { Write-Output "WOULD MERGE settings.json" }
else {
  $tmpl = Get-Content "$Here/config/settings.template.json" -Raw | ConvertFrom-Json
  $base = if (Test-Path $settings) { Get-Content $settings -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
  foreach ($p in $tmpl.PSObject.Properties) { $base | Add-Member -Force -NotePropertyName $p.Name -NotePropertyValue $p.Value }
  $base | ConvertTo-Json -Depth 20 | Set-Content $settings -Encoding UTF8
}
if (-not (Test-Path (Join-Path $HOME 'brain'))) {
  if ($DryRun) { Write-Output "WOULD SCAFFOLD ~/brain" } else { Copy-Item "$Here/brain-scaffold" (Join-Path $HOME 'brain') -Recurse }
}
if ($Personal) { if ($DryRun) { Write-Output "WOULD OVERLAY $Personal" } else { Copy-Item "$Personal/*" (Join-Path $HOME 'brain') -Recurse -Force } }
if (-not (Test-Path "$Here/.env")) { if (-not $DryRun) { Copy-Item "$Here/.env.example" "$Here/.env" } }
Write-Output "done. Run '.\install.ps1 -Check' to verify."
