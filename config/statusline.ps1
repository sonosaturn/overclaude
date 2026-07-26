# Badge statusline dei plugin di modalità perenne (caveman, ponytail).
# Il path della cache plugin contiene la versione: risolto a runtime con un glob,
# così un bump del plugin non rompe la statusline. Niente -Recurse: la cache è grossa
# e questo script gira a ogni render. Gli script dei plugin scrivono da soli su console.
$null = $input | Out-Null   # consuma il JSON su stdin di Claude Code
foreach ($p in @("$HOME\.claude\plugins\cache\*\*\*\hooks\*-statusline.ps1",
                 "$HOME\.claude\plugins\cache\*\*\*\src\hooks\*-statusline.ps1")) {
    foreach ($s in (Get-ChildItem -Path $p -ErrorAction SilentlyContinue)) { & $s.FullName; [Console]::Write(' ') }
}
