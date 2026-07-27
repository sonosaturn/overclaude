# Statusline badges for the always-on mode plugins (caveman, ponytail).
# The plugin cache path contains the version: resolved at runtime with a glob, so a plugin
# version bump does not break the statusline. No -Recurse: the cache is big and this script
# runs on every render. The plugin scripts write to the console themselves.
$null = $input | Out-Null   # consume the JSON on Claude Code's stdin
foreach ($p in @("$HOME\.claude\plugins\cache\*\*\*\hooks\*-statusline.ps1",
                 "$HOME\.claude\plugins\cache\*\*\*\src\hooks\*-statusline.ps1")) {
    foreach ($s in (Get-ChildItem -Path $p -ErrorAction SilentlyContinue)) { & $s.FullName; [Console]::Write(' ') }
}
