$fails = 0
function Ck($name, $test) { if (& $test) { Write-Output "CHECK PASS: $name" } else { Write-Output "CHECK FAIL: $name"; $script:fails++ } }
foreach ($b in 'node', 'uv', 'gitnexus', 'markitdown', 'graphify') { Ck "tool $b" { [bool](Get-Command $b -ErrorAction SilentlyContinue) } }
Ck "settings.json exists" { Test-Path (Join-Path $HOME '.claude/settings.json') }
Ck "~/brain exists" { Test-Path (Join-Path $HOME 'brain') }
if ($fails -eq 0) { Write-Output "ALL CHECKS PASSED" } else { Write-Output "$fails CHECK(S) FAILED" }
exit $fails
