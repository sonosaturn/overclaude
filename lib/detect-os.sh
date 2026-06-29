# shellcheck shell=sh
detect_os() {
  case "$(uname -s)" in
    Linux) echo linux ;;
    Darwin) echo macos ;;
    *) echo unknown ;;
  esac
}
detect_pkg_mgr() {
  for m in pacman apt-get dnf zypper brew; do
    if command -v "$m" >/dev/null 2>&1; then echo "$m"; return 0; fi
  done
  echo unknown
}
