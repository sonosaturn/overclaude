#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# pwsh (Core) ovunque; su Windows va bene anche il powershell.exe di sistema (5.1),
# altrimenti su questa piattaforma i .ps1 non verrebbero mai validati.
PS=""
for c in pwsh powershell; do command -v "$c" >/dev/null 2>&1 && { PS="$c"; break; }; done
[ -n "$PS" ] || { echo "SKIP (no pwsh/powershell)"; exit 0; }
for f in install.ps1 verify.ps1; do
  "$PS" -NoProfile -Command "\$null = [System.Management.Automation.Language.Parser]::ParseFile('$root/$f',[ref]\$null,[ref]\$null); if (\$?) {exit 0} else {exit 1}" || { echo "FAIL: $f parse"; exit 1; }
done
echo "PASS test_ps_syntax"
