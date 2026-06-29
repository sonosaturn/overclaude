#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
if ! command -v pwsh >/dev/null 2>&1; then echo "SKIP (no pwsh)"; exit 0; fi
for f in install.ps1 verify.ps1; do
  pwsh -NoProfile -Command "\$null = [System.Management.Automation.Language.Parser]::ParseFile('$root/$f',[ref]\$null,[ref]\$null); if (\$?) {exit 0} else {exit 1}" || { echo "FAIL: $f parse"; exit 1; }
done
echo "PASS test_ps_syntax"
