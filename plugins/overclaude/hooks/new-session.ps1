$dir = Join-Path $HOME 'brain/conversations'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$ts = Get-Date -Format 'dd-MM-yy_HH-mm'
$file = Join-Path $dir "Conv_$ts.md"
if (-not (Test-Path $file)) {
  $header = "# Conversazione $(Get-Date -Format 'dd/MM/yyyy HH:mm')`n`n> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice."
  Set-Content -Path $file -Value $header -Encoding UTF8
}
Set-Content -Path (Join-Path $dir '.current-session') -Value $file -Encoding UTF8
Write-Output "CONVERSATION LOG ATTIVO: $file"
Write-Output 'Aggiorna questo file a ogni turno seguendo la skill "conversation-log": prompt utente verbatim, tue risposte riassunte senza blocchi di codice, sovrascrivendo sempre questo stesso file.'
