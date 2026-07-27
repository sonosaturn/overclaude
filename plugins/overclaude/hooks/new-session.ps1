$dir = Join-Path $HOME 'brain/conversations'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$ts = Get-Date -Format 'dd-MM-yy_HH-mm'
$file = Join-Path $dir "Conv_$ts.md"
if (-not (Test-Path $file)) {
  $header = "# Conversazione $(Get-Date -Format 'dd/MM/yyyy HH:mm')`n`n> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice."
  Set-Content -Path $file -Value $header -Encoding UTF8
}
Set-Content -Path (Join-Path $dir '.current-session') -Value $file -Encoding UTF8
Write-Output "ACTIVE CONVERSATION LOG: $file"
Write-Output 'Update this file on every turn following the "conversation-log" skill: user prompts verbatim, your answers summarised without code blocks, always overwriting this same file.'
