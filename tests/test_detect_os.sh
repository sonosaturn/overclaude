#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
. "$root/lib/detect-os.sh"
# detect_pkg_mgr must return a known token (whatever this machine has, or unknown)
m="$(detect_pkg_mgr)"
case "$m" in pacman|apt-get|dnf|zypper|brew|unknown) : ;; *) fail "bad pkg mgr: $m" ;; esac
o="$(detect_os)"
case "$o" in linux|macos|unknown) : ;; *) fail "bad os: $o" ;; esac
echo "PASS test_detect_os"
